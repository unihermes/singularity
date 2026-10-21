#!/usr/bin/env python3
# Singularity - Hyprland
# ~/.config/hypr/tray-watcher.py
#
# The tray's StatusNotifierWatcher, run apart from the shell so it outlives
# a shell restart: apps keep their registration, and none sees the tray go
# away (Spotify opens its window when it does). The shell's tray registers
# with it as a host. Started before the shell (autostart.lua); if the shell
# got the name first, this one waits for it and takes over when it's free.

from gi.repository import Gio, GLib

NAME = "org.kde.StatusNotifierWatcher"
PATH = "/StatusNotifierWatcher"
XML = """
<node>
  <interface name="org.kde.StatusNotifierWatcher">
    <method name="RegisterStatusNotifierItem"><arg name="service" type="s" direction="in"/></method>
    <method name="RegisterStatusNotifierHost"><arg name="service" type="s" direction="in"/></method>
    <property name="RegisteredStatusNotifierItems" type="as" access="read"/>
    <property name="IsStatusNotifierHostRegistered" type="b" access="read"/>
    <property name="ProtocolVersion" type="i" access="read"/>
    <signal name="StatusNotifierItemRegistered"><arg type="s"/></signal>
    <signal name="StatusNotifierItemUnregistered"><arg type="s"/></signal>
    <signal name="StatusNotifierHostRegistered"/>
    <signal name="StatusNotifierHostUnregistered"/>
  </interface>
</node>
"""

bus = Gio.bus_get_sync(Gio.BusType.SESSION)
iface = Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0]

# "<bus name><object path>", in registration order, as the items are listed
items = []
# host bus names
hosts = set()


def emit(signal, args=None):
    bus.emit_signal(None, PATH, NAME, signal, args)


def items_changed():
    bus.emit_signal(None, PATH, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                    GLib.Variant("(sa{sv}as)", (NAME, {
                        "RegisteredStatusNotifierItems": GLib.Variant("as", items),
                    }, [])))


def on_call(_conn, sender, _path, _iface, method, params, invocation):
    service = params.unpack()[0]
    if method == "RegisterStatusNotifierItem":
        # a path (libappindicator) belongs to the sender; a bus name is the
        # item's own, at the standard path
        owner, path = (sender, service) if service.startswith("/") else (service, "/StatusNotifierItem")
        item = owner + path
        if item not in items:
            items.append(item)
            emit("StatusNotifierItemRegistered", GLib.Variant("(s)", (item,)))
            items_changed()
    elif method == "RegisterStatusNotifierHost":
        if service not in hosts:
            hosts.add(service)
            emit("StatusNotifierHostRegistered")
    invocation.return_value(None)


def on_get(_conn, _sender, _path, _iface, prop):
    if prop == "RegisteredStatusNotifierItems":
        return GLib.Variant("as", items)
    if prop == "IsStatusNotifierHostRegistered":
        return GLib.Variant("b", bool(hosts))
    return GLib.Variant("i", 0)


# a name gone from the bus takes its items, or its host, with it
def on_owner_changed(_conn, _sender, _path, _iface, _signal, params):
    name, _old, new = params.unpack()
    if new:
        return
    gone = [i for i in items if i.split("/", 1)[0] == name]
    for item in gone:
        items.remove(item)
        emit("StatusNotifierItemUnregistered", GLib.Variant("(s)", (item,)))
    if gone:
        items_changed()
    if name in hosts:
        hosts.discard(name)
        emit("StatusNotifierHostUnregistered")


bus.register_object(PATH, iface, on_call, on_get, None)
bus.signal_subscribe("org.freedesktop.DBus", "org.freedesktop.DBus", "NameOwnerChanged",
                     "/org/freedesktop/DBus", None, Gio.DBusSignalFlags.NONE, on_owner_changed)
# queued (no DO_NOT_QUEUE): gets the name once a shell holding it lets go
Gio.bus_own_name_on_connection(bus, NAME, Gio.BusNameOwnerFlags.NONE, None, None)
GLib.MainLoop().run()
