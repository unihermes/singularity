#!/usr/bin/env python3
"""The bar's application menus: com.canonical.AppMenu.Registrar plus a
com.canonical.dbusmenu reader, for services/AppMenus.qml.

Apps that export their menu bar (Qt apps, Electron and appmenu-gtk-module
under XWayland) register it here. Each registration is kept with the
sender's pid, which is how the shell matches it to a Hyprland window. When
another registrar already owns the name, this one reads that registrar's
list instead. The registrations are also kept in $XDG_RUNTIME_DIR, so a
shell reload, which restarts this helper, doesn't lose the menus of apps
that registered before it.

Commands, one JSON object per line on stdin:
  {"cmd": "watch", "service": s, "path": p}  read this menu and follow it
  {"cmd": "unwatch"}
  {"cmd": "open", "id": n}   a submenu is about to show
  {"cmd": "close", "id": n}
  {"cmd": "click", "id": n}
Events, one JSON object per line on stdout:
  {"event": "menus", "menus": [{win, service, path, pid}]}
  {"event": "layout", "service": s, "path": p, "items": [item]}
     item: {id, label, enabled, separator, toggle ("" | "check" | "radio"),
            checked, shortcut, children: [item] | null}
"""

import json
import os
import sys
import time

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

REG_NAME = "com.canonical.AppMenu.Registrar"
REG_PATH = "/com/canonical/AppMenu/Registrar"
MENU_IFACE = "com.canonical.dbusmenu"
STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "singularity-appmenu.json")

# dbusmenu's key names, as the shell shows them
KEY_NAMES = {"Control": "Ctrl", "Super": "Super", "Alt": "Alt", "Shift": "Shift",
             "plus": "+", "minus": "-", "equal": "=", "comma": ",", "period": ".",
             "slash": "/", "backslash": "\\", "grave": "`", "Return": "Enter",
             "Delete": "Del", "Escape": "Esc", "space": "Space"}


def emit(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def plain_label(text):
    # "_File" -> "File"; "__" is a literal underscore
    return text.replace("__", "\0").replace("_", "").replace("\0", "_")


def shortcut_text(value):
    try:
        combos = [[str(k) for k in combo] for combo in value]
    except TypeError:
        return ""
    return " ".join("+".join(KEY_NAMES.get(k, k.upper() if len(k) == 1 else k) for k in c) for c in combos)


def convert(node):
    """A GetLayout node (id, props, children) as the shell's item, None when hidden."""
    nid, props, children = node
    props = {str(k): v for k, v in props.items()}
    if not bool(props.get("visible", True)):
        return None
    toggle = str(props.get("toggle-type", ""))
    kids = []
    for child in children:
        item = convert(child)
        if item is not None:
            kids.append(item)
    submenu = str(props.get("children-display", "")) == "submenu" or len(kids) > 0
    return {
        "id": int(nid),
        "label": plain_label(str(props.get("label", ""))),
        "enabled": bool(props.get("enabled", True)),
        "separator": str(props.get("type", "standard")) == "separator",
        "toggle": "check" if toggle == "checkmark" else "radio" if toggle == "radio" else "",
        "checked": int(props.get("toggle-state", 0)) == 1,
        "shortcut": shortcut_text(props.get("shortcut", [])),
        "children": kids if submenu else None,
    }


class Registry:
    def __init__(self, bus):
        self.bus = bus
        self.menus = {}  # win -> {service, path, pid}
        bus.add_signal_receiver(self.owner_changed, "NameOwnerChanged",
                                "org.freedesktop.DBus", "org.freedesktop.DBus", "/org/freedesktop/DBus")

    def pid_of(self, service):
        try:
            return int(self.bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus")
                       .GetConnectionUnixProcessID(service, dbus_interface="org.freedesktop.DBus"))
        except dbus.DBusException:
            return 0

    def alive(self, service):
        try:
            return bool(self.bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus")
                        .NameHasOwner(service, dbus_interface="org.freedesktop.DBus"))
        except dbus.DBusException:
            return False

    def add(self, win, service, path, pid=0):
        self.menus[int(win)] = {"service": str(service), "path": str(path),
                                "pid": pid or self.pid_of(service), "at": time.time()}
        self.changed()

    def remove(self, win):
        if self.menus.pop(int(win), None) is not None:
            self.changed()

    def owner_changed(self, name, old, new):
        if new or not name.startswith(":"):
            return
        gone = [w for w, m in self.menus.items() if m["service"] == name]
        for w in gone:
            del self.menus[w]
        if gone:
            self.changed()

    def changed(self):
        out = [{"win": w, "service": m["service"], "path": m["path"], "pid": m["pid"], "at": m["at"]}
               for w, m in self.menus.items()]
        try:
            tmp = STATE + ".tmp"
            with open(tmp, "w") as f:
                json.dump(out, f)
            os.replace(tmp, STATE)
        except OSError:
            pass
        emit({"event": "menus", "menus": out})

    def restore(self):
        try:
            with open(STATE) as f:
                saved = json.load(f)
        except (OSError, ValueError):
            return
        for m in saved:
            if self.alive(m["service"]):
                self.menus[int(m["win"])] = {"service": m["service"], "path": m["path"],
                                             "pid": m.get("pid", 0), "at": m.get("at", 0)}


class Registrar(dbus.service.Object):
    def __init__(self, bus, registry):
        super().__init__(bus, REG_PATH)
        self.registry = registry

    @dbus.service.method(REG_NAME, in_signature="uo", sender_keyword="sender")
    def RegisterWindow(self, win, path, sender=None):
        self.registry.add(win, sender, path)
        self.WindowRegistered(win, sender, path)

    @dbus.service.method(REG_NAME, in_signature="u")
    def UnregisterWindow(self, win):
        self.registry.remove(win)
        self.WindowUnregistered(win)

    @dbus.service.method(REG_NAME, in_signature="u", out_signature="so")
    def GetMenuForWindow(self, win):
        m = self.registry.menus.get(int(win))
        if not m:
            raise dbus.DBusException("no menu for window %d" % win, name=REG_NAME + ".Error")
        return m["service"], dbus.ObjectPath(m["path"])

    @dbus.service.method(REG_NAME, out_signature="a(uso)")
    def GetMenus(self):
        return [(dbus.UInt32(w), m["service"], dbus.ObjectPath(m["path"]))
                for w, m in self.registry.menus.items()]

    @dbus.service.signal(REG_NAME, signature="uso")
    def WindowRegistered(self, win, service, path):
        pass

    @dbus.service.signal(REG_NAME, signature="u")
    def WindowUnregistered(self, win):
        pass


def follow_other(bus, registry):
    """Another registrar owns the name: mirror its list."""
    def load():
        try:
            reg = bus.get_object(REG_NAME, REG_PATH)
            for win, service, path in reg.GetMenus(dbus_interface=REG_NAME):
                registry.menus[int(win)] = {"service": str(service), "path": str(path),
                                            "pid": registry.pid_of(service), "at": time.time()}
        except dbus.DBusException:
            pass
        registry.changed()
    bus.add_signal_receiver(lambda w, s, p: registry.add(w, s, p), "WindowRegistered", REG_NAME)
    bus.add_signal_receiver(lambda w: registry.remove(w), "WindowUnregistered", REG_NAME)
    load()


class Watcher:
    """The one menu the shell is showing: its layout, kept up to date."""

    def __init__(self, bus):
        self.bus = bus
        self.target = None
        self.matches = []
        self.pending = 0

    def proxy(self):
        service, path = self.target
        return dbus.Interface(self.bus.get_object(service, path, introspect=False), MENU_IFACE)

    def watch(self, service, path):
        self.unwatch()
        self.target = (service, path)
        for sig in ("LayoutUpdated", "ItemsPropertiesUpdated", "ItemActivationRequested"):
            self.matches.append(self.bus.add_signal_receiver(
                self.updated, sig, MENU_IFACE, service, path))
        try:
            self.proxy().AboutToShow(0)
        except dbus.DBusException:
            pass
        self.fetch()

    def unwatch(self):
        for m in self.matches:
            m.remove()
        self.matches = []
        self.target = None

    def updated(self, *args):
        # a burst of updates comes as one read
        if self.pending:
            GLib.source_remove(self.pending)
        self.pending = GLib.timeout_add(40, self.fetch)

    def fetch(self):
        self.pending = 0
        if not self.target:
            return False
        target = self.target

        def done(revision, layout):
            if self.target != target:
                return
            root = convert(layout)
            emit({"event": "layout", "service": target[0], "path": target[1],
                  "items": (root or {}).get("children") or []})

        def failed(err):
            if self.target == target:
                emit({"event": "layout", "service": target[0], "path": target[1], "items": []})

        self.proxy().GetLayout(0, -1, dbus.Array([], signature="s"),
                               reply_handler=done, error_handler=failed, timeout=3)
        return False

    def event(self, nid, kind):
        if not self.target:
            return
        proxy = self.proxy()
        ignore = lambda *a: None
        if kind == "opened":
            # an app that fills a submenu as it opens says so, and is read again
            proxy.AboutToShow(nid, reply_handler=lambda need: need and self.updated(), error_handler=ignore)
        proxy.Event(nid, kind, dbus.Int32(0, variant_level=1), dbus.UInt32(int(time.time()) & 0xffffffff),
                    reply_handler=ignore, error_handler=ignore)


def main():
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    registry = Registry(bus)
    watcher = Watcher(bus)

    got = bus.request_name(REG_NAME, dbus.bus.NAME_FLAG_DO_NOT_QUEUE)
    if got in (dbus.bus.REQUEST_NAME_REPLY_PRIMARY_OWNER, dbus.bus.REQUEST_NAME_REPLY_ALREADY_OWNER):
        registry.restore()
        Registrar(bus, registry)
        registry.changed()
    else:
        follow_other(bus, registry)

    def on_stdin(fd, cond):
        line = sys.stdin.readline()
        if not line:
            loop.quit()
            return False
        try:
            msg = json.loads(line)
        except ValueError:
            return True
        cmd = msg.get("cmd")
        try:
            if cmd == "watch":
                watcher.watch(msg["service"], msg["path"])
            elif cmd == "unwatch":
                watcher.unwatch()
            elif cmd in ("open", "close", "click"):
                watcher.event(int(msg["id"]), {"open": "opened", "close": "closed", "click": "clicked"}[cmd])
        except (dbus.DBusException, KeyError, ValueError) as e:
            emit({"event": "error", "text": str(e)})
        return True

    loop = GLib.MainLoop()
    GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP, on_stdin)
    loop.run()


if __name__ == "__main__":
    main()
