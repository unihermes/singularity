// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageLockScreen.qml
//
// The lock screen, and what the lid does. Three files, each edited in place:
//
//   hyprlock.conf   the background block (path, blur_passes, brightness) and
//                   the clock label's text. Colours and font come from the
//                   look through AppearanceSync, not from here.
//   hypridle.conf   the grace period, as --grace on the idle lock's command.
//                   Only that listener gets it: a lock before sleep or by
//                   hand always asks for the password.
//   lid.sh          close_action, close_delay and lock_on_close.
//
// hyprlock reads its config at each lock and lid.sh at each lid event, so
// only hypridle needs a restart.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Lock Screen"
    description: "Look, password grace and the lid. Colours follow Appearance."


    readonly property string hyprDir: Quickshell.env("HOME") + "/.config/hypr"
    readonly property string lockPath: hyprDir + "/hyprlock.conf"
    readonly property string idlePath: hyprDir + "/hypridle.conf"
    readonly property string lidPath: hyprDir + "/lid.sh"
    readonly property string wallpaperLink: "~/.local/state/singularity/current-wallpaper"

    // --- hyprlock.conf -------------------------------------------------------

    // [first, last] line of the first `name {` block, or null
    function blockRange(lines, name) {
        var start = -1
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].replace(/#.*/, "").trim()
            if (start < 0 && l === name + " {") start = i
            else if (start >= 0 && l === "}") return [start, i]
        }
        return null
    }

    function blockValues(text, name) {
        var lines = text.split("\n"), r = blockRange(lines, name), out = {}
        if (!r) return out
        for (var i = r[0] + 1; i < r[1]; i++) {
            var m = /^\s*([\w-]+)\s*=\s*(.*?)\s*$/.exec(lines[i])
            if (m) out[m[1]] = m[2]
        }
        return out
    }

    // Sets each key in the block, adding a line before its `}` when missing;
    // a null value removes the key. null when there is no such block.
    function setInBlock(text, name, values) {
        var lines = text.split("\n"), r = blockRange(lines, name)
        if (!r) return null
        for (var key in values) {
            var at = -1
            for (var i = r[0] + 1; i < r[1]; i++)
                if (new RegExp("^\\s*" + key + "\\s*=").test(lines[i])) { at = i; break }
            if (values[key] === null) {
                if (at >= 0) { lines.splice(at, 1); r[1]-- }
            } else if (at >= 0) {
                lines[at] = lines[at].replace(/=.*$/, "= " + values[key])
            } else {
                lines.splice(r[1], 0, "    " + key + " = " + values[key])
                r[1]++
            }
        }
        return lines.join("\n")
    }

    property var background: ({})
    property string clockText: ""

    readonly property string backgroundKind: {
        var p = background.path || ""
        return p === "" ? "plain" : p === "screenshot" ? "screenshot" : "wallpaper"
    }
    readonly property int blurPasses: Number(background.blur_passes || 0)
    readonly property int dim: Math.round((1 - Number(background.brightness !== undefined ? background.brightness : 1)) * 100)

    // the clock label's text for each choice. `#` would start a hyprlang
    // comment, so the formats keep clear of it.
    readonly property var clocks: ({
        "24": "$TIME",
        "12": "$TIME12",
        "seconds": 'cmd[update:1000] date +"%H:%M:%S"',
        "date": 'cmd[update:1000] date +"%a %-d %b  %H:%M"',
    })
    readonly property string clockKind: {
        for (var k in clocks) if (clocks[k] === clockText) return k
        return ""
    }

    function rereadLock() {
        lockFile.reload()
        lockFile.waitForJob()
        var text = lockFile.text()
        if (text === "") { say("Couldn't read " + lockPath, true); return }
        background = blockValues(text, "background")
        clockText = blockValues(text, "label").text || ""
    }

    function writeLock(block, values, message) {
        AtomicFileWrite.write({
            path: lockPath,
            transform: text => text === "" ? null : setInBlock(text, block, values),
            refusal: "hyprlock.conf has no " + block + " block; nothing written",
            done: (status, detail) => {
                if (status === "ok" || status === "unchanged") page.say(message, false)
                else page.say(status === "refused" ? detail : "Couldn't write hyprlock.conf", true)
                page.rereadLock()
            }
        })
    }

    // --- grace, in hypridle.conf ---------------------------------------------

    property int grace: 0
    property bool graceFound: false
    readonly property var graces: [0, 5, 10, 30, 60]

    // the idle lock: the listener whose on-timeout locks
    function lockListenerLine(lines) {
        var inBlock = false
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].replace(/#.*/, "").trim()
            if (/^listener\s*\{$/.test(l)) inBlock = true
            else if (l === "}") inBlock = false
            else if (inBlock && /^on-timeout\s*=.*(lock-session|hyprlock)/.test(l)) return i
        }
        return -1
    }

    function rereadIdle() {
        idleFile.reload()
        idleFile.waitForJob()
        var lines = idleFile.text().split("\n")
        var at = lockListenerLine(lines)
        graceFound = at >= 0
        var m = at >= 0 ? /--grace\s+(\d+)/.exec(lines[at]) : null
        grace = m ? Number(m[1]) : 0
    }

    // With a grace period the step runs hyprlock itself rather than through
    // lock_cmd, so it carries lock_cmd's refocus after the unlock too (see
    // hypridle.conf): without it the active window takes no keys.
    readonly property string refocus: "hyprctl eval 'local w = hl.get_active_window(); "
        + "if w then hl.dispatch(hl.dsp.focus({ window = \"address:\" .. w.address })) end'"

    function setGrace(seconds) {
        var cmd = seconds > 0 ? "pidof hyprlock || (hyprlock --grace " + seconds + "; " + refocus + ")"
            : "loginctl lock-session"
        AtomicFileWrite.write({
            path: idlePath,
            transform: text => {
                var lines = text.split("\n"), at = lockListenerLine(lines)
                if (at < 0) return null
                lines[at] = lines[at].replace(/=.*$/, "= " + cmd)
                return lines.join("\n")
            },
            refusal: "hypridle.conf has no idle lock step; nothing written",
            after: "pkill -x hypridle; "
                + "systemctl --user reset-failed hypridle.service 2>/dev/null; "
                + "systemctl --user restart hypridle.service 2>/dev/null || setsid -f hypridle >/dev/null 2>&1",
            done: (status, detail) => {
                if (status === "ok" || status === "unchanged")
                    page.say(seconds > 0 ? "Grace period: " + page.graceLabel(seconds) : "Grace period off", false)
                else page.say(status === "refused" ? detail : "Couldn't write hypridle.conf", true)
                page.rereadIdle()
            }
        })
    }

    function graceLabel(s) {
        return s === 0 ? "Off" : s < 60 ? s + " s" : (s / 60) + " min"
    }

    // --- lid, in lid.sh ------------------------------------------------------

    property string closeAction: "suspend"
    property int closeDelay: 300
    property bool lockOnClose: false

    function rereadLid() {
        lidFile.reload()
        lidFile.waitForJob()
        var text = lidFile.text()
        if (text === "") { say("Couldn't read " + lidPath, true); return }
        var m
        closeAction = (m = /^close_action=([\w-]+)/m.exec(text)) ? m[1] : "suspend"
        closeDelay = (m = /^close_delay=(\d+)/m.exec(text)) ? Number(m[1]) : 300
        lockOnClose = (m = /^lock_on_close=(\d)/m.exec(text)) ? m[1] === "1" : false
    }

    function setLid(name, value, message) {
        var re = new RegExp("^(" + name + "=)[\\w-]+", "m")
        AtomicFileWrite.write({
            path: lidPath,
            transform: text => re.test(text) ? text.replace(re, "$1" + value) : null,
            refusal: "lid.sh has no " + name + "; nothing written",
            check: "bash",
            done: (status, detail) => {
                if (status === "ok" || status === "unchanged") page.say(message, false)
                else page.say(status === "refused" ? detail : "Couldn't write lid.sh", true)
                page.rereadLid()
            }
        })
    }

    // stepping minutes writes once, after the last step
    property int pendingDelay: -1
    Timer {
        id: delayDebounce
        interval: 500
        onTriggered: page.setLid("close_delay", page.pendingDelay,
            "Suspends " + (page.pendingDelay / 60) + " min after the lid closes")
    }

    Component.onCompleted: {
        rereadLock()
        rereadIdle()
        rereadLid()
    }

    FileView { id: lockFile; path: page.lockPath; blockLoading: true; printErrors: false }
    FileView { id: idleFile; path: page.idlePath; blockLoading: true; printErrors: false }
    FileView { id: lidFile;  path: page.lidPath;  blockLoading: true; printErrors: false }

    // --- layout --------------------------------------------------------------

    // The lock screen as set now, pinned over the rows, with Lock now on
    // its corner to try it.
    pinned: Item {
        width: parent ? parent.width : 0
        height: preview.height + Theme.spaceL

        LockPreview {
            id: preview
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.spaceXs
            width: Math.min(parent.width, Theme.fit(380))
            kind: page.backgroundKind
            blur: page.blurPasses
            dim: page.dim
            clock: page.clockKind

            FlyoutChip {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spaceS
                icon: "󰌾"
                text: "Lock now"
                onClicked: Quickshell.execDetached(["sh", "-c", "pidof hyprlock || hyprlock"])
            }
        }
    }

    // the line under the clock as it will read: the date, the track
    // playing and the unread count, each when it's chosen
    readonly property string underSample: {
        var out = []
        if (Settings.lockDate) out.push(Qt.formatDate(new Date(), "dddd, MMMM d"))
        if (Settings.lockMedia) {
            var p = Media.player
            out.push(p && p.isPlaying ? (p.trackTitle || p.identity) : "the track playing")
        }
        if (Settings.lockNotifs) out.push(Notifications.unread > 0 ? Notifications.unread + " unread" : "unread count")
        return out.join("  ·  ")
    }

    FlyoutHeading { text: "BACKGROUND" }

    SettingsField {
        label: "Background"
        hint: "Wallpaper follows the desktop's"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: [{ value: "wallpaper", text: "Wallpaper" }, { value: "screenshot", text: "Screenshot" },
                { value: "plain", text: "Plain" }]
            current: page.backgroundKind
            onPicked: v => page.writeLock("background",
                { path: v === "plain" ? null : v === "screenshot" ? "screenshot" : page.wallpaperLink },
                "Lock background: " + v)
        }
    }

    SettingsField {
        label: "Blur"
        hint: page.backgroundKind === "plain" ? "Only for a wallpaper or screenshot" : "Passes over the background"

        FlyoutStepper {
            anchors.right: parent.right
            width: Theme.fit(170)
            enabled: page.backgroundKind !== "plain"
            value: page.blurPasses
            minimum: 0
            maximum: 4
            valueWidth: 64
            displayValue: value === 0 ? "off" : String(value)
            onStepped: delta => {
                var n = Math.max(0, Math.min(4, page.blurPasses + delta))
                page.writeLock("background", { blur_passes: n }, n === 0 ? "Blur off" : "Blur: " + n)
            }
        }
    }

    SettingsField {
        label: "Dim"
        hint: page.backgroundKind === "plain" ? "Only for a wallpaper or screenshot" : "Darkens the background"

        FlyoutStepper {
            anchors.right: parent.right
            width: Theme.fit(170)
            enabled: page.backgroundKind !== "plain"
            value: Math.round(page.dim / 10)
            minimum: 0
            maximum: 8
            valueWidth: 64
            displayValue: page.dim + "%"
            onStepped: delta => {
                var d = Math.max(0, Math.min(80, Math.round(page.dim / 10) * 10 + delta * 10))
                page.writeLock("background", { brightness: ((100 - d) / 100).toFixed(2) }, "Dim: " + d + "%")
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "CLOCK" }

    SettingsField {
        label: "Clock"
        hint: page.clockKind === "" ? "Set by hand in hyprlock.conf" : ""

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: [{ value: "24", text: "24-hour" }, { value: "12", text: "12-hour" },
                { value: "seconds", text: "Seconds" }, { value: "date", text: "Day + time" }]
            current: page.clockKind
            onPicked: v => page.writeLock("label", { text: page.clocks[v] }, "Lock clock updated")
        }
    }

    SettingsField {
        label: "Clock size"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: Settings.choices.lockClockSize
            labelFor: v => Settings.choiceLabel(v, "lockClockSize")
            current: Settings.lockClockSize
            onPicked: v => Settings.set("lockClockSize", v)
        }
    }

    SettingsField {
        label: "Clock place"
        hint: "Where the clock sits"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: Settings.choices.lockClockPlace
            labelFor: v => Settings.choiceLabel(v, "lockClockPlace")
            current: Settings.lockClockPlace
            onPicked: v => Settings.set("lockClockPlace", v)
        }
    }

    // the info line under the clock (hypr/lock-info.sh): any of the three
    SettingsField {
        label: "Under the clock"
        hint: page.underSample !== "" ? page.underSample : "Nothing under the clock"

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceS

            FlyoutChip { text: "Date"; selected: Settings.lockDate; onClicked: Settings.set("lockDate", !Settings.lockDate) }
            FlyoutChip { text: "Media"; selected: Settings.lockMedia; onClicked: Settings.set("lockMedia", !Settings.lockMedia) }
            FlyoutChip { text: "Notifications"; selected: Settings.lockNotifs; onClicked: Settings.set("lockNotifs", !Settings.lockNotifs) }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "PASSWORD" }

    SettingsField {
        label: "Grace period"
        hint: !page.graceFound ? "hypridle.conf has no idle lock step"
            : page.grace === 0 ? "Always asks for the password"
            : "No password for " + page.graceLabel(page.grace) + " after an idle lock"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            enabled: page.graceFound
            model: page.graces
            labelFor: v => page.graceLabel(v)
            current: page.grace
            onPicked: v => page.setGrace(v)
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "LID" }

    // what closing it does, and for Suspend how long after
    SettingsField {
        label: "When the lid closes"
        hint: page.closeAction === "suspend" ? "Not with a monitor plugged in"
            : "Screen off; Power & Idle's steps still apply"

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceM

            FlyoutSegmented {
                anchors.verticalCenter: parent.verticalCenter
                fill: false
                model: [{ value: "suspend", text: "Suspend" }, { value: "screen-off", text: "Screen off" }]
                current: page.closeAction
                onPicked: v => page.setLid("close_action", v,
                    v === "suspend" ? "Closing the lid suspends" : "Closing the lid only turns the screen off")
            }
            Text {
                visible: page.closeAction === "suspend"
                anchors.verticalCenter: parent.verticalCenter
                text: "after"
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
            FlyoutStepper {
                visible: page.closeAction === "suspend"
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(170)
                value: Math.round(page.closeDelay / 60)
                minimum: 1
                maximum: 60
                valueWidth: 64
                displayValue: Math.round(page.closeDelay / 60) + " min"
                onStepped: delta => {
                    var m = Math.max(1, Math.min(60, Math.round(page.closeDelay / 60) + delta))
                    page.closeDelay = m * 60
                    page.pendingDelay = m * 60
                    delayDebounce.restart()
                }
            }
        }
    }

    SettingsField {
        label: "Lock right away"
        hint: page.lockOnClose ? "Locks the moment the lid shuts" : "Locks only when it goes to sleep"

        Switch {
            anchors.right: parent.right
            checked: page.lockOnClose
            onToggled: page.setLid("lock_on_close", page.lockOnClose ? 0 : 1,
                page.lockOnClose ? "Locks when it goes to sleep" : "Locks as soon as the lid closes")
        }
    }
}
