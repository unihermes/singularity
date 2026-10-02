// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPagePower.qml
//
// Power profile, how the battery charges, and the idle ladder in
// hypridle.conf.
//
// The profile goes through PpdProfile.qml, as the battery flyout's does,
// and needs no saving -- PPD remembers it.
//
// Charging is the BIOS's charge mode and, in Custom, where charging stops
// and resumes. They're read from the battery's sysfs files and written by
// install.sh's singularity-charge helper through pkexec (no password for
// the active session). The firmware keeps them, so nothing else saves
// them. The stop and resume steppers write once they've been still for a
// moment, since every write is a firmware write. The Battery row draws the
// charge now on a pill, with Custom's stop-to-resume band over it.
//
// The ladder is hypridle.conf's listener blocks, each shown by what it does
// (dim, lock, screens off, suspend) and edited in place: only the number on
// its `timeout = N` line changes, the rest of the file is left byte for byte.
// hypridle reads its config once at start, so every write restarts it --
// debounced, so stepping through ten values restarts it once.

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    title: "Power & Idle"
    description: "Power profile, how the battery charges, and how long the machine sits idle before each step of hypridle.conf. hypridle restarts to pick up a change."

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

    // --- charging ------------------------------------------------------------

    readonly property string chargeHelper: "/usr/local/bin/singularity-charge"
    // the kernel's charge_types name, "" until read or on a battery without one
    property string chargeMode: ""
    property int chargeStart: 0
    property int chargeStop: 0
    property bool chargeHelperFound: false
    property bool chargeBusy: false

    // Express is the kernel's Fast. Trickle is the BIOS's "Primarily AC
    // use": it can be set there, but has no segment here, so it lights none.
    readonly property var chargeModes: [
        { value: "Standard", text: "Standard" },
        { value: "Adaptive", text: "Adaptive" },
        { value: "Fast", text: "Express" },
        { value: "Custom", text: "Custom" },
    ]
    readonly property var chargeHints: ({
        "Standard": "Charges to full at a normal rate",
        "Adaptive": "The BIOS picks limits from how you use the laptop",
        "Fast": "Charges faster, wears the battery more",
        "Custom": "Your own stop and resume points",
        "Trickle": "Primarily AC use, set in the BIOS",
    })

    function chargeHint() {
        if (chargeMode === "") return "This battery has no charge modes"
        if (!chargeHelperFound) return "Run install.sh to change this from here"
        return chargeHints[chargeMode] || chargeMode
    }

    function chargeRead() { chargeReader.running = true }

    function chargeWrite(mode) {
        chargeBusy = true
        chargeWriter.command = mode === "Custom"
            ? ["pkexec", chargeHelper, mode, String(chargeStart), String(chargeStop)]
            : ["pkexec", chargeHelper, mode]
        chargeWriter.running = true
    }

    // Steps of 5, kept 5 apart. Dell takes a stop of 55-100 and a start of
    // 50-95; pushing one into the other moves both.
    function chargeStep(which, delta) {
        if (which === "stop") {
            chargeStop = Math.max(55, Math.min(100, chargeStop + delta * 5))
            chargeStart = Math.min(chargeStart, chargeStop - 5)
        } else {
            chargeStart = Math.max(50, Math.min(95, chargeStart + delta * 5))
            chargeStop = Math.max(chargeStop, chargeStart + 5)
        }
        chargeDebounce.restart()
    }

    function batteryState() {
        if (!Battery.present) return ""
        var s = Battery.device.state
        var what = s === UPowerDeviceState.Charging ? "Charging"
            : s === UPowerDeviceState.Discharging ? "On battery"
            : s === UPowerDeviceState.FullyCharged ? "Full"
            : "Not charging"
        return Battery.percent + "% · " + what
    }

    Process {
        id: chargeReader
        command: ["sh", "-c",
            "[ -x " + page.chargeHelper + " ] && echo helper; "
            + "for b in /sys/class/power_supply/BAT*; do [ -e \"$b/charge_types\" ] || continue; "
            + "cat \"$b/charge_types\" \"$b/charge_control_start_threshold\" \"$b/charge_control_end_threshold\"; break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n").filter(l => l !== "")
                page.chargeHelperFound = lines[0] === "helper"
                if (page.chargeHelperFound) lines.shift()
                var m = lines.length >= 3 ? /\[(\w+)\]/.exec(lines[0]) : null
                page.chargeMode = m ? m[1] : ""
                if (m) {
                    page.chargeStart = Number(lines[1])
                    page.chargeStop = Number(lines[2])
                }
            }
        }
    }

    Process {
        id: chargeWriter
        stderr: StdioCollector { id: chargeErr }
        onExited: code => {
            page.chargeBusy = false
            var e = chargeErr.text.trim()
            if (code === 0) page.say(page.chargeMode === "Custom"
                ? "Charging stops at " + page.chargeStop + "%, resumes below " + page.chargeStart + "%"
                : "Charge mode saved", false)
            // 126/127: pkexec was dismissed or refused
            else page.say("The BIOS refused the change" + (e ? ": " + e : ""), true)
            page.chargeRead()
        }
    }

    Timer {
        id: chargeDebounce
        interval: 700
        onTriggered: page.chargeWrite("Custom")
    }

    // --- idle ladder ---------------------------------------------------------

    // [{ timeout, action, label, line }] -- line is the index of the
    // `timeout = N` line in the file
    property var listeners: []
    property bool idleRunning: false
    // the listeners' indices, soonest first: taken once when the page opens,
    // so a row doesn't jump past its neighbour while its time is stepped
    property var ladder: []

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
                // lid.sh's input detector, not a step
                if (cur.line >= 0 && cur.action !== "" && !cur.action.includes("singularity-idle")) { cur.label = describe(cur.action); out.push(cur) }
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
        ladder = listeners.map((l, i) => i).sort((a, b) => listeners[a].timeout - listeners[b].timeout)
        idleCheck.running = true
        PpdProfile.refresh()
        chargeRead()
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
            model: PpdProfile.choices
            current: PpdProfile.profile
            enabled: PpdProfile.profile !== "" && !PpdProfile.busy
            onPicked: v => {
                page.profilePending = true
                PpdProfile.set(v)
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "BATTERY" }

    SettingsField {
        label: "Charging"
        hint: page.chargeHint()

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: page.chargeModes
            current: page.chargeMode
            enabled: page.chargeMode !== "" && page.chargeHelperFound && !page.chargeBusy
            onPicked: v => {
                page.chargeMode = v
                page.chargeWrite(v)
            }
        }
    }

    SettingsField {
        visible: page.chargeMode === "Custom"
        label: "Stop at"
        hint: "55–100%"

        FlyoutStepper {
            anchors.right: parent.right
            width: Theme.fit(170)
            value: page.chargeStop / 5
            minimum: 11
            maximum: 20
            valueWidth: 64
            displayValue: page.chargeStop + "%"
            enabled: page.chargeHelperFound
            onStepped: delta => page.chargeStep("stop", delta)
        }
    }

    SettingsField {
        visible: page.chargeMode === "Custom"
        label: "Resume below"
        hint: "50–95%, at least 5 under Stop at"

        FlyoutStepper {
            anchors.right: parent.right
            width: Theme.fit(170)
            value: page.chargeStart / 5
            minimum: 10
            maximum: 19
            valueWidth: 64
            displayValue: page.chargeStart + "%"
            enabled: page.chargeHelperFound
            onStepped: delta => page.chargeStep("start", delta)
        }
    }

    // the charge now on a pill, and in Custom the band charging keeps it in
    SettingsField {
        visible: Battery.present
        label: "Battery"
        hint: page.batteryState() + (page.chargeMode === "Custom"
            ? " · kept " + page.chargeStart + "–" + page.chargeStop + "%" : "")

        Meter {
            id: chargeBar
            anchors.right: parent.right
            width: Theme.fit(220)
            height: Theme.fit(14)
            fraction: Battery.percent / 100
            fillColor: Theme.muted

            Rectangle {
                visible: page.chargeMode === "Custom"
                x: chargeBar.width * page.chargeStart / 100
                width: chargeBar.width * (page.chargeStop - page.chargeStart) / 100
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                color: Qt.alpha(Theme.accent, 0.3)
                Rectangle { width: Theme.borderWidth; height: parent.height; color: Theme.accent }
                Rectangle { width: Theme.borderWidth; height: parent.height; anchors.right: parent.right; color: Theme.accent }
            }

            Rectangle {
                x: Math.round(chargeBar.width * Battery.percent / 100 - width / 2)
                y: -Theme.fit(2)
                width: 2
                height: parent.height + Theme.fit(4)
                color: Theme.bright
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
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontSmall
    }

    Repeater {
        // a file whose listeners changed under the page shows in file order
        model: page.ladder.length === page.listeners.length ? page.ladder : page.listeners.map((l, i) => i)

        SettingsField {
            required property int modelData
            readonly property int index: modelData
            readonly property var step: page.listeners[index]
            label: step.label
            hint: page.stepHints[step.label] || ""

            FlyoutStepper {
                anchors.right: parent.right
                width: Theme.fit(170)
                // in 30-second steps
                value: Math.round(step.timeout / 30)
                minimum: 1
                maximum: 240
                valueWidth: 64
                displayValue: page.minutes(step.timeout)
                onStepped: delta => page.setTimeout_(index, Math.max(30, (value + delta) * 30))
            }
        }
    }
}
