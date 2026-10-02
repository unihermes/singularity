// Singularity - Quickshell
// ~/.config/quickshell/services/DiskCache.qml
//
// A service's last results, kept as JSON in ~/.cache/singularity/<name>.json,
// so a restart or reload of the shell shows them at once instead of nothing
// until the next fetch comes back. The service saves after each good fetch
// and takes `restored` once at start; how old is too old is its call.

import Quickshell
import Quickshell.Io
import QtQuick

FileView {
    id: root

    required property string name
    signal restored(var data)

    readonly property string dir: Quickshell.env("HOME") + "/.cache/singularity"

    function save(data) {
        dirMade.running = true
        pendingText = JSON.stringify(data)
    }
    property string pendingText: ""

    path: dir + "/" + name + ".json"
    printErrors: false
    onLoaded: {
        try { root.restored(JSON.parse(text())) } catch (e) {}
    }

    // the cache folder may not be there on a fresh install
    property Process dirMade: Process {
        command: ["mkdir", "-p", root.dir]
        onExited: root.setText(root.pendingText)
    }
}
