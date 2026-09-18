// Singularity - Quickshell
// ~/.config/quickshell/services/LookStore.qml
//
// Every look the shell can wear: the built-in fallback from Looks.js, plus
// whatever looks.json (beside this file) defines. Kept as data rather than
// code so a look can be removed from the Appearance page -- which deletes its
// entry from looks.json itself, not just hides it. The fallback can't be
// removed: it's what everything falls back to when a look goes missing.
//
// looks.json is in the repo, so a removed look comes back with
// `git checkout -- services/looks.json`.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "Looks.js" as Looks

Singleton {
    id: root

    readonly property string path: Quickshell.shellPath("services/looks.json")

    // looks.json as parsed, before completion from Looks.base
    property var fileLooks: ({})

    // name -> complete look; the fallback first, then the file's own order
    readonly property var looks: {
        var out = {}
        out[Looks.fallback] = Looks.looks[Looks.fallback]
        for (var k in fileLooks)
            if (k !== Looks.fallback) out[k] = Looks.complete(fileLooks[k])
        return out
    }
    readonly property var order: Object.keys(looks)

    function removable(name) { return name !== Looks.fallback && !!fileLooks[name] }

    // done(ok, message)
    function remove(name, done) {
        if (!removable(name)) return
        var label = looks[name].name
        AtomicFileWrite.write({
            path: root.path,
            transform: text => {
                var j
                try { j = JSON.parse(text) } catch (e) { return null }
                if (!j[name]) return null
                delete j[name]
                return JSON.stringify(j, null, 4) + "\n"
            },
            refusal: "looks.json no longer has " + label + ", or isn't valid JSON",
            // done() before the reload: the caller is usually the removed
            // look's own carousel card, which the reload destroys, taking
            // the callback's scope with it
            done: (status, detail) => {
                if (done) done(status === "ok", status === "ok" ? label + " removed"
                    : "Couldn't remove " + label + (detail ? ": " + detail : ""))
                file.reload()
            }
        })
    }

    function parse(text) {
        try {
            var j = JSON.parse(text)
            root.fileLooks = (j && typeof j === "object") ? j : {}
        } catch (e) {
            console.warn("looks.json isn't valid JSON, only " + Looks.fallback + " is available: " + e)
            root.fileLooks = {}
        }
    }

    FileView {
        id: file
        path: root.path
        preload: true
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parse(text())
        onLoadFailed: root.fileLooks = {}
    }
}
