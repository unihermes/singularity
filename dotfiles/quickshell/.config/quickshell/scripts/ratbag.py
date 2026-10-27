#!/usr/bin/env python3
# Singularity - Quickshell
# ~/.config/quickshell/scripts/ratbag.py
#
# Mouse settings kept on the mouse itself, through ratbagd (libratbag) on
# the system bus, for services/Mice.qml. Every setting is on the profile the
# mouse has active, and is written to it at once.
#
#   ratbag.py read                  JSON: [{ path, name, profile, rate,
#                                   rates, resolution, dpi, dpis,
#                                   buttons: [{ path, type, value }] }]
#   ratbag.py dpi RESOLUTION N      that resolution's DPI
#   ratbag.py rate PROFILE N        the profile's report rate (Hz)
#   ratbag.py button BUTTON N|off   the button acts as mouse button N, or nothing
#
# A write exits 1 with ratbagd's message on stderr when it fails.

import json
import sys

from gi.repository import Gio, GLib

NAME = "org.freedesktop.ratbag1"
ROOT = "/org/freedesktop/ratbag1"
BUTTON, NONE = 1, 0

bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)


def get(path, iface, prop):
    res = bus.call_sync(NAME, path, "org.freedesktop.DBus.Properties", "Get",
                        GLib.Variant("(ss)", (NAME + "." + iface, prop)),
                        GLib.VariantType("(v)"), Gio.DBusCallFlags.NONE, 3000, None)
    return res.unpack()[0]


def put(path, iface, prop, value):
    bus.call_sync(NAME, path, "org.freedesktop.DBus.Properties", "Set",
                  GLib.Variant("(ssv)", (NAME + "." + iface, prop, value)),
                  None, Gio.DBusCallFlags.NONE, 3000, None)


# /org/freedesktop/ratbag1/resolution/hidraw6/p1/r1 -> .../device/hidraw6
def device_of(path):
    return ROOT + "/device/" + path.split("/")[5]


def commit(path):
    bus.call_sync(NAME, device_of(path), NAME + ".Device", "Commit", None,
                  GLib.VariantType("(u)"), Gio.DBusCallFlags.NONE, 5000, None)


def read():
    out = []
    for dev in get(ROOT, "Manager", "Devices"):
        profiles = get(dev, "Device", "Profiles")
        active = next((p for p in profiles if get(p, "Profile", "IsActive")), None)
        if active is None:
            continue
        res = get(active, "Profile", "Resolutions")
        res = next((r for r in res if get(r, "Resolution", "IsActive")), res[0] if res else None)
        dpi = get(res, "Resolution", "Resolution") if res else 0
        out.append({
            "path": dev,
            "name": get(dev, "Device", "Name"),
            "profile": active,
            "rate": get(active, "Profile", "ReportRate"),
            "rates": list(get(active, "Profile", "ReportRates")),
            "resolution": res or "",
            # (x, y) when the axes are separate; they're set together here
            "dpi": dpi[0] if isinstance(dpi, tuple) else dpi,
            "dpis": list(get(res, "Resolution", "Resolutions")) if res else [],
            "buttons": [{"path": b, "type": m[0], "value": m[1]}
                        for b in get(active, "Profile", "Buttons")
                        for m in [get(b, "Button", "Mapping")]],
        })
    print(json.dumps(out))


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "read"
    if cmd == "read":
        return read()
    path, value = sys.argv[2], sys.argv[3]
    if cmd == "dpi":
        n = int(value)
        old = get(path, "Resolution", "Resolution")
        v = GLib.Variant("(uu)", (n, n)) if isinstance(old, tuple) else GLib.Variant("u", n)
        put(path, "Resolution", "Resolution", GLib.Variant("v", v))
    elif cmd == "rate":
        put(path, "Profile", "ReportRate", GLib.Variant("u", int(value)))
    elif cmd == "button":
        mapping = (NONE, GLib.Variant("u", 0)) if value == "off" else (BUTTON, GLib.Variant("u", int(value)))
        put(path, "Button", "Mapping", GLib.Variant("(uv)", mapping))
    else:
        sys.exit("ratbag.py: no command " + cmd)
    commit(path)


if __name__ == "__main__":
    try:
        main()
    except GLib.Error as e:
        print(GLib.dbus_error_strip_remote_error(e) or e.message, file=sys.stderr)
        sys.exit(1)
