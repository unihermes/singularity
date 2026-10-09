// Singularity - Quickshell
// ~/.config/quickshell/services/LookStore.qml
//
// Every look the shell can wear: the built-in fallback from Looks.js, plus
// whatever looks.json (beside this file) defines, less the ones removed on
// this machine. The fallback can't be removed: it's what everything falls
// back to when a look goes missing.
//
// looks.json is the repo's and is only read. Removing a look from the
// Appearance page adds its name to looks-removed.json in the state
// directory instead, so the repo is left alone; taking the name out of that
// file brings the look back.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "Looks.js" as Looks

Singleton {
    id: root

    readonly property string path: Quickshell.shellPath("services/looks.json")
    readonly property string removedPath: Quickshell.env("HOME") + "/.local/state/singularity/looks-removed.json"

    // looks.json as parsed, before completion from Looks.base
    property var fileLooks: ({})
    // names removed on this machine, from looks-removed.json
    property var removed: []

    // name -> complete look; the fallback first, then the file's own order
    readonly property var looks: {
        var out = {}
        out[Looks.fallback] = Looks.looks[Looks.fallback]
        for (var k in fileLooks)
            if (k !== Looks.fallback && removed.indexOf(k) < 0) out[k] = Looks.complete(fileLooks[k])
        return out
    }
    readonly property var order: Object.keys(looks)

    function removable(name) { return name !== Looks.fallback && !!fileLooks[name] && removed.indexOf(name) < 0 }

    // done(ok, message)
    function remove(name, done) {
        if (!removable(name)) return
        var label = looks[name].name
        AtomicFileWrite.write({
            path: root.removedPath,
            transform: text => {
                var j = []
                try { j = text.trim() === "" ? [] : JSON.parse(text) } catch (e) { return null }
                if (!Array.isArray(j)) return null
                if (j.indexOf(name) >= 0) return null
                j.push(name)
                return JSON.stringify(j, null, 4) + "\n"
            },
            refusal: "looks-removed.json already has " + label + ", or isn't valid JSON",
            // done() before the reload: the caller is usually the removed
            // look's own carousel card, which the reload destroys, taking
            // the callback's scope with it
            done: (status, detail) => {
                if (done) done(status === "ok", status === "ok" ? label + " removed"
                    : "Couldn't remove " + label + (detail ? ": " + detail : ""))
                removedFile.reload()
            }
        })
    }

    // A file caught mid-write (git checkout, an editor's save) reads as
    // invalid JSON for a moment, and the change that completes it may not
    // come through the watch. So a bad parse keeps the looks already loaded
    // and reads the file again shortly; only a file that's still bad then
    // is reported.
    function parse(text) {
        try {
            var j = JSON.parse(text)
            root.fileLooks = (j && typeof j === "object") ? j : {}
            retry.tries = 0
        } catch (e) {
            if (retry.tries < 3) { retry.tries++; retry.restart(); return }
            retry.tries = 0
            console.warn("looks.json isn't valid JSON, only " + Looks.fallback + " is available: " + e)
            root.fileLooks = {}
        }
    }

    Timer {
        id: retry
        property int tries: 0
        interval: 300
        onTriggered: file.reload()
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

    FileView {
        id: removedFile
        path: root.removedPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var j = JSON.parse(text())
                root.removed = Array.isArray(j) ? j : []
            } catch (e) { root.removed = [] }
        }
        onLoadFailed: root.removed = []
    }
}
