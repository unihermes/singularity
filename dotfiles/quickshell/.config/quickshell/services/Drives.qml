// Singularity - Quickshell
// ~/.config/quickshell/services/Drives.qml
//
// Removable drives (USB sticks and disks, SD cards: lsblk's hotplug ones)
// and their filesystems, for the Drives module. Read again whenever udev
// reports a block device coming or going. Mount, unmount and eject go
// through udisksctl, which polkit allows for the active session.
// Mounting a filesystem opens it in the file manager once it's mounted.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // each drive: path, name, size and parts; each part: path, label,
    // fstype, size, mountpoint ("" when not mounted) and used (bytes)
    property var drives: []
    readonly property int count: drives.length
    // the device path an action is running on, "" for none
    property string busyPath: ""
    property string error: ""
    // the filesystem to open once its mount lands
    property string openAfter: ""

    function refresh() { if (!list.running) list.running = true }

    // mounts it, then opens it in the file manager
    function mount(part) {
        openAfter = part.path
        run(part.path, ["udisksctl", "mount", "-b", part.path])
    }
    function unmount(part) { run(part.path, ["udisksctl", "unmount", "-b", part.path]) }
    // every mounted filesystem on it unmounted, then the drive powered off
    function eject(drive) {
        const steps = drive.parts.filter(p => p.mountpoint !== "")
            .map(p => "udisksctl unmount -b " + p.path)
        steps.push("udisksctl power-off -b " + drive.path)
        run(drive.path, ["sh", "-c", steps.join(" && ")])
    }
    function open(part) { if (part.mountpoint !== "") Quickshell.execDetached(["xdg-open", part.mountpoint]) }

    function run(path, cmd) {
        if (action.running) return
        error = ""
        busyPath = path
        action.command = cmd
        action.running = true
    }

    Process {
        id: action
        stderr: StdioCollector { id: actionErr }
        onExited: code => {
            if (code !== 0) {
                const t = actionErr.text.trim().split("\n").pop() || "It didn't work"
                // udisksctl's errors lead with the D-Bus error's name
                root.error = t.replace(/^Error [a-z]+ [^:]*: /i, "").replace(/^GDBus\.Error:[^ ]+ /, "")
                root.openAfter = ""
            }
            root.busyPath = ""
            root.refresh()
        }
    }

    Process {
        id: list
        command: ["lsblk", "-J", "-b", "-o",
                  "NAME,PATH,LABEL,SIZE,FSTYPE,MOUNTPOINT,HOTPLUG,TYPE,MODEL,VENDOR,FSUSED"]
        stdout: StdioCollector {
            onStreamFinished: {
                let devs
                try { devs = JSON.parse(text).blockdevices || [] } catch (e) { return }
                const out = []
                for (const d of devs) {
                    if (!d.hotplug || d.type !== "disk" || !(d.size > 0)) continue
                    // a filesystem straight on the disk counts as its one part
                    const parts = (d.children && d.children.length > 0 ? d.children : [d])
                        .filter(p => !!p.fstype)
                        .map(p => ({ path: p.path, label: p.label || "", fstype: p.fstype,
                                     size: Number(p.size) || 0, mountpoint: p.mountpoint || "",
                                     used: Number(p.fsused) || 0 }))
                    const name = [d.vendor, d.model].map(s => (s || "").trim()).filter(s => s !== "").join(" ")
                    out.push({ path: d.path, name: name || d.name, size: Number(d.size), parts: parts })
                }
                root.drives = out
                if (root.openAfter !== "") {
                    for (const dr of out) for (const p of dr.parts)
                        if (p.path === root.openAfter && p.mountpoint !== "") root.open(p)
                    root.openAfter = ""
                }
            }
        }
    }

    // udev's block events; a burst (a stick and its partitions) refreshes once
    Process {
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=block"]
        stdout: SplitParser {
            onRead: line => { if (/ (add|remove|change) /.test(line)) settle.restart() }
        }
    }
    Timer {
        id: settle
        interval: 600
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
