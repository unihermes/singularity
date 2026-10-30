// Singularity - Quickshell
// ~/.config/quickshell/settings/LidConfig.qml
//
// The lid's settings in lid.conf (lid.sh reads it): what closing it does
// and for Suspend how long after, locking right away, and hibernating after
// an hour shut. Battery & Idle draws them (its LID section, hidden without
// a lid switch).

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"

Item {
    id: lid

    // the page, for its toasts
    required property Item page
    readonly property string lidPath: Settings.stateDir + "/lid.conf"

    // a lid switch to act on; the LID rows hide without one
    property bool hasLid: false
    Process {
        running: true
        command: ["sh", "-c", "ls /proc/acpi/button/lid/*/state"]
        onExited: code => lid.hasLid = (code === 0)
    }

    property string closeAction: "suspend"
    property int closeDelay: 300
    property bool lockOnClose: false
    property bool hibernate: true

    // lid.sh's defaults until the file says otherwise; a missing file is
    // every default
    function rereadLid() {
        lidFile.reload()
        lidFile.waitForJob()
        var text = lidFile.text()
        var m
        closeAction = (m = /^close_action=([\w-]+)/m.exec(text)) ? m[1] : "suspend"
        closeDelay = (m = /^close_delay=(\d+)/m.exec(text)) ? Number(m[1]) : 300
        lockOnClose = (m = /^lock_on_close=(\d)/m.exec(text)) ? m[1] === "1" : false
        hibernate = (m = /^hibernate=(\d)/m.exec(text)) ? m[1] === "1" : true
    }

    function setLid(name, value, message) {
        var re = new RegExp("^" + name + "=.*$", "m")
        AtomicFileWrite.write({
            path: lidPath,
            transform: text => re.test(text) ? text.replace(re, name + "=" + value)
                : text + (text === "" || text.endsWith("\n") ? "" : "\n") + name + "=" + value + "\n",
            done: (status, detail) => {
                if (status === "ok" || status === "unchanged") lid.page.say(message, false)
                else lid.page.say("Couldn't write lid.conf", true)
                lid.rereadLid()
            }
        })
    }

    // stepping minutes writes once, after the last step
    property int pendingDelay: -1
    function stepDelay(minutes) {
        closeDelay = minutes * 60
        pendingDelay = minutes * 60
        delayDebounce.restart()
    }
    Timer {
        id: delayDebounce
        interval: 500
        onTriggered: lid.setLid("close_delay", lid.pendingDelay,
            "Suspends " + (lid.pendingDelay / 60) + " min after the lid closes")
    }

    Component.onCompleted: rereadLid()
    FileView { id: lidFile; path: lid.lidPath; blockLoading: true; printErrors: false }
}
