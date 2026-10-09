// Singularity - Quickshell
// ~/.config/quickshell/services/VirtualMachines.qml
//
// The libvirt VMs running in the user's own session (qemu:///session), for
// the bar's Virtual Machines module: which are up, and opening, shutting
// down or forcing off each.
//
// Nothing is polled and no virsh runs while idle. libvirt keeps a
// <name>.xml for every running domain in its session run directory and
// removes it when the domain stops, so a watched folder listing is the
// list of running VMs. The directory only exists once the session daemon
// has started, so while it's empty the listing is re-read every 30s, a
// directory read in-process, to catch it appearing.
//
// System VMs (qemu:///system) aren't shown: their run directory is root's.

pragma Singleton

import Quickshell
import QtQuick
import Qt.labs.folderlistmodel

Singleton {
    id: root

    readonly property string uri: "qemu:///session"
    readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") + "/libvirt/qemu/run"

    // names of the running VMs, sorted
    readonly property var running: {
        var out = []
        for (var i = 0; i < listing.count; i++)
            out.push(String(listing.get(i, "fileName")).replace(/\.xml$/, ""))
        return out.sort()
    }
    readonly property bool active: running.length > 0

    // name -> true while a shutdown asked for is still under way
    property var stopping: ({})

    function open(name) {
        Quickshell.execDetached(["virt-viewer", "--connect", uri, "--reconnect",
                                 "--auto-resize=always", name])
    }
    // asks the guest to shut down (ACPI), as its power button would
    function shutdown(name) {
        var s = Object.assign({}, stopping)
        s[name] = true
        stopping = s
        Quickshell.execDetached(["virsh", "-c", uri, "shutdown", name])
    }
    // pulls the plug; the VM itself is kept
    function forceOff(name) {
        Quickshell.execDetached(["virsh", "-c", uri, "destroy", name])
    }

    onRunningChanged: {
        var s = {}
        for (var k in stopping) if (running.indexOf(k) !== -1) s[k] = true
        stopping = s
    }

    FolderListModel {
        id: listing
        folder: "file:" + root.runDir
        nameFilters: ["*.xml"]
        showDirs: false
        showHidden: false
    }

    Timer {
        interval: 30000
        running: listing.count === 0
        repeat: true
        onTriggered: {
            listing.folder = ""
            listing.folder = "file:" + root.runDir
        }
    }
}
