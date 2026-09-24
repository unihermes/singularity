// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPagePower.qml
//
// Power profile, and the idle ladder in hypridle.conf.
//
// The profile goes through PpdProfile.qml, as the battery flyout's does,
// and needs no saving -- PPD remembers it.
//
// The ladder is hypridle.conf's listener blocks, each shown by what it does
// (dim, lock, screens off, suspend) and edited in place: only the number on
// its `timeout = N` line changes, the rest of the file is left byte for byte.
// hypridle reads its config once at start, so every write restarts it --
// debounced, so stepping through ten values restarts it once.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    title: "Power & Idle"
    description: "Power profile, and how long the machine sits idle before each step of hypridle.conf. hypridle restarts to pick up a change."

    readonly property string idlePath: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"

    // --- power profile -------------------------------------------------------

    // true between this page's own set() and its result, so a change made
    // from the battery flyout meanwhile doesn't report here
    property bool profilePending: false

    Connections {
        target: PpdProfile
        function onSetFinished(ok, error) {
            if (!page.profilePending) return
            page.profilePending = false
            if (!ok) page.say("power-profiles-daemon refused: " + error, true)
            else page.say("Power profile: " + PpdProfile.profile, false)
        }
    }

    // --- idle ladder ---------------------------------------------------------

    // [{ timeout, action, label, line }] -- line is the index of the
    // `timeout = N` line in the file
    property var listeners: []
    property bool idleRunning: false

    function describe(cmd) {
        if (/brightnessctl/.test(cmd)) return "Dim the screen"
        if (/lock-session|hyprlock/.test(cmd)) return "Lock"
        if (/dpms/.test(cmd)) return "Turn screens off"
        // hypridle.conf's battery-only step: suspends unless a charger is online
        if (/power_supply/.test(cmd) && /suspend/.test(cmd)) return "Suspend on battery"
        if (/suspend|hibernate/.test(cmd)) return /hibernate/.test(cmd) ? "Hibernate" : "Suspend"
        return cmd
    }

    // Blocks are found line by line: `listener {` opens one, `}` closes it,
    // and `#` comments are skipped -- hyprlang has no strings to hide a brace
    // in, so nothing more is needed.
    // what a step does, in words; a command it doesn't recognise shows as is
    readonly property var stepHints: ({
        "Dim the screen": "Lowers the backlight",
        "Lock": "Locks the session",
        "Turn screens off": "Wakes on any input",
        "Suspend on battery": "Only while unplugged",
        "Suspend": "Sleeps the whole machine",
        "Hibernate": "Saves to disk and powers off",
    })

    function parseIdle(text) {
        var lines = text.split("\n")
        var out = [], cur = null
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].replace(/#.*/, "").trim()
            if (/^listener\s*\{$/.test(l)) { cur = { timeout: -1, action: "", line: -1 }; continue }
            if (!cur) continue
            var m
            if ((m = /^timeout\s*=\s*(\d+)$/.exec(l))) { cur.timeout = Number(m[1]); cur.line = i }
            else if ((m = /^on-timeout\s*=\s*(.*)$/.exec(l))) cur.action = m[1]
            else if (l === "}") {
                if (cur.line >= 0) { cur.label = describe(cur.action); out.push(cur) }
                cur = null
            }
        }
        return out
    }

    function reread() {
        idleFile.reload()
        idleFile.waitForJob()
        var text = idleFile.text()
        if (text === "") { say("Couldn't read " + idlePath, true); listeners = []; return }
        listeners = parseIdle(text)
    }

    function setTimeout_(index, seconds) {
        var copy = listeners.slice()
        copy[index] = Object.assign({}, copy[index], { timeout: seconds })
        listeners = copy
        idleDebounce.restart()
    }

    // Applied to the file as it is when the write runs. Only the timeout
    // values change, by listener position, so a file whose listeners were
    // added or removed since the page read it is left alone.
    function writeIdle() {
        var want = listeners.map(l => l.timeout)
        AtomicFileWrite.write({
            path: idlePath,
            transform: text => {
                var fresh = parseIdle(text)
                if (text === "" || fresh.length !== want.length) return null
                var lines = text.split("\n")
                fresh.forEach((l, i) => {
                    lines[l.line] = lines[l.line].replace(/(timeout\s*=\s*)\d+/, "$1" + want[i])
                })
                return lines.join("\n")
            },
            refusal: "hypridle.conf changed on disk; nothing written",
            // whichever way it was started -- the unit, or the bare fallback
            // hyprland.lua uses when the unit won't start
            after: "pkill -x hypridle; "
                + "systemctl --user reset-failed hypridle.service 2>/dev/null; "
                + "systemctl --user restart hypridle.service 2>/dev/null || setsid -f hypridle >/dev/null 2>&1",
            done: (status, detail) => {
                if (status === "ok" || status === "unchanged") page.say("Saved, hypridle restarted", false)
                else page.say(status === "refused" ? detail : "Couldn't write hypridle.conf" + (detail ? ": " + detail : ""), true)
                page.reread()
                idleCheck.running = true
            }
        })
    }

    function minutes(s) {
        return s % 60 === 0 ? (s / 60) + " min" : (s / 60).toFixed(1) + " min"
    }

    Component.onCompleted: {
        reread()
        idleCheck.running = true
        PpdProfile.refresh()
    }

    FileView {
        id: idleFile
        path: page.idlePath
        blockLoading: true
        printErrors: false
    }

    Timer {
        id: idleDebounce
        interval: 700
        onTriggered: page.writeIdle()
    }

    Process {
        id: idleCheck
        command: ["pgrep", "-x", "hypridle"]
        onExited: code => page.idleRunning = code === 0
    }

    // --- layout --------------------------------------------------------------

    FlyoutHeading { text: "POWER PROFILE" }

    SettingsField {
        label: "Profile"
        hint: PpdProfile.profile === "" ? "power-profiles-daemon isn't answering" : "Performance may not exist on every machine"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: [{ value: "power-saver", text: "Power saver" }, { value: "balanced", text: "Balanced" },
                { value: "performance", text: "Performance" }]
            current: PpdProfile.profile
            enabled: PpdProfile.profile !== "" && !PpdProfile.busy
            onPicked: v => {
                page.profilePending = true
                PpdProfile.set(v)
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WHEN IDLE" }

    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: page.idleRunning
            ? "Keep Awake in Quick Actions, or a playing video, pauses all of these."
            : "hypridle isn't running, so none of these fire. Changing one starts it."
        color: page.idleRunning ? Theme.subtext : Theme.alert
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }

    Repeater {
        model: page.listeners

        SettingsField {
            required property var modelData
            required property int index
            label: modelData.label
            hint: page.stepHints[modelData.label] || ""

            FlyoutStepper {
                anchors.right: parent.right
                width: Theme.fit(170)
                // in 30-second steps
                value: Math.round(modelData.timeout / 30)
                minimum: 1
                maximum: 240
                valueWidth: 64
                displayValue: page.minutes(modelData.timeout)
                onStepped: delta => page.setTimeout_(index, Math.max(30, (value + delta) * 30))
            }
        }
    }
}
