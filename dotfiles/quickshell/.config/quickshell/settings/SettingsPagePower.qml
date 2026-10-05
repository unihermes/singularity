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
// moment, since every write is a firmware write. The battery card sits
// over a level chip of the charge now; in Custom it carries the resume-to-
// stop band, whose ends are dragged to set them.
//
// The ladder is hypridle.conf's listener blocks, each shown by what it does
// (dim, lock, screens off, suspend) and edited in place: the number on its
// `timeout = N` line changes, and a step turned off has its block's lines
// commented out with a `#~ ` mark (taken off again when it's turned back
// on). The rest of the file is left byte for byte. hypridle reads its
// config once at start, so every write restarts it -- debounced, so
// stepping through ten values restarts it once.

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "../services"
import "../services/Format.js" as Format
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Power & Idle"
    description: "Power profile, charging, and the idle steps in hypridle.conf."


    readonly property string idlePath: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"

    readonly property var glyphs: ({
        "power-saver": String.fromCodePoint(0xF032A),
        "balanced": String.fromCodePoint(0xF05D1),
        "performance": String.fromCodePoint(0xF0463),
        charging: String.fromCodePoint(0xF0084),
        plug: String.fromCodePoint(0xF06A5),
        battery: String.fromCodePoint(0xF0079),
        "Dim the screen": String.fromCodePoint(0xF00DF),
        "Lock": String.fromCodePoint(0xF033E),
        "Turn screens off": String.fromCodePoint(0xF0D90),
        "Suspend on battery": String.fromCodePoint(0xF0079),
        "Suspend": String.fromCodePoint(0xF04B2),
        "Hibernate": String.fromCodePoint(0xF0904),
    })
    function batteryGlyph(pct) {
        return String.fromCodePoint(pct >= 90 ? 0xF0079 : pct >= 70 ? 0xF0080
            : pct >= 50 ? 0xF007E : pct >= 30 ? 0xF007C : 0xF007A)
    }

    // --- power profile -------------------------------------------------------

    readonly property var profileHints: ({
        "power-saver": "Slower and cooler, battery lasts longer",
        "balanced": "Speeds up only when it's needed",
        "performance": "Full speed, more heat and fan",
    })

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
        "Adaptive": "The BIOS sets limits from your use",
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
    // 50-95; pushing one into the other moves both. Written once the drag
    // lets go.
    function chargeSet(which, pct) {
        pct = Math.round(pct / 5) * 5
        if (which === "stop") {
            chargeStop = Math.max(55, Math.min(100, pct))
            chargeStart = Math.min(chargeStart, chargeStop - 5)
        } else {
            chargeStart = Math.max(50, Math.min(95, pct))
            chargeStop = Math.max(chargeStop, chargeStart + 5)
        }
    }

    // the card's second line: what it's doing, how long, the band, health
    function batteryLine() {
        if (!Battery.present) return ""
        var d = Battery.device, st = d.state
        var parts = [st === UPowerDeviceState.Charging ? "Charging"
            : st === UPowerDeviceState.Discharging ? "On battery"
            : st === UPowerDeviceState.FullyCharged ? "Full"
            : "Not charging"]
        if (st === UPowerDeviceState.Discharging && d.timeToEmpty > 0) parts.push(Format.duration(d.timeToEmpty) + " left")
        if (st === UPowerDeviceState.Charging && d.timeToFull > 0) parts.push(Format.duration(d.timeToFull) + " to full")
        if (chargeMode === "Custom") parts.push("kept " + chargeStart + "–" + chargeStop + "%")
        if (d.healthSupported) parts.push("Health " + Math.round(d.healthPercentage) + "%")
        return parts.join("  ·  ")
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

    // [{ timeout, action, label, line, open, close, on }] -- line is the
    // index of the `timeout = N` line, open and close the block's braces,
    // and on false for a block commented out with `#~ `
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
            var off = /^\s*#~/.test(lines[i])
            var l = lines[i].replace(/^\s*#~ ?/, "").replace(/#.*/, "").trim()
            if (/^listener\s*\{$/.test(l)) { cur = { timeout: -1, action: "", line: -1, open: i, on: !off }; continue }
            if (!cur) continue
            var m
            if ((m = /^timeout\s*=\s*(\d+)$/.exec(l))) { cur.timeout = Number(m[1]); cur.line = i }
            else if ((m = /^on-timeout\s*=\s*(.*)$/.exec(l))) cur.action = m[1]
            else if (l === "}") {
                cur.close = i
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

    function setStep(index, change) {
        var copy = listeners.slice()
        copy[index] = Object.assign({}, copy[index], change)
        listeners = copy
        idleDebounce.restart()
    }

    // Applied to the file as it is when the write runs. Only the timeout
    // values and the `#~ ` marks change, by listener position, so a file
    // whose listeners were added or removed since the page read it is left
    // alone.
    function writeIdle() {
        var want = listeners.map(l => ({ timeout: l.timeout, on: l.on }))
        AtomicFileWrite.write({
            path: idlePath,
            transform: text => {
                var fresh = parseIdle(text)
                if (text === "" || fresh.length !== want.length) return null
                var lines = text.split("\n")
                fresh.forEach((l, i) => {
                    lines[l.line] = lines[l.line].replace(/(timeout\s*=\s*)\d+/, "$1" + want[i].timeout)
                    if (l.on === want[i].on) return
                    for (var j = l.open; j <= l.close; j++)
                        lines[j] = want[i].on ? lines[j].replace(/^(\s*)#~ ?/, "$1")
                            : lines[j].replace(/^(\s*)/, "$1#~ ")
                })
                return lines.join("\n")
            },
            refusal: "hypridle.conf changed on disk; nothing written",
            // whichever way it was started -- the unit, or the bare fallback
            // autostart.lua uses when the unit won't start
            after: "pkill -x hypridle; "
                + "systemctl --user reset-failed hypridle.service 2>/dev/null; "
                + "systemctl --user restart hypridle.service 2>/dev/null || setsid -f hypridle >/dev/null 2>&1",
            done: (status, detail) => {
                if (status === "ok" || status === "unchanged") page.say("Saved, hypridle restarted", false)
                else page.say(status === "refused" ? detail : "Couldn't write hypridle.conf" + (detail ? ": " + detail : ""), true)
                page.reread()
                idleRecheck.restart()
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

    // after a restart, once hypridle has had a moment to come back
    Timer {
        id: idleRecheck
        interval: 1500
        onTriggered: idleCheck.running = true
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
        hint: PpdProfile.profile === "" ? "power-profiles-daemon isn't answering"
            : page.profileHints[PpdProfile.profile] || ""

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: PpdProfile.choices.map(c => ({ value: c.value, text: page.glyphs[c.value] + " " + c.text }))
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

    // the charge now, what it's doing, and its health
    HeadCard {
        visible: Battery.present
        glyph: Battery.present && Battery.device.state === UPowerDeviceState.Charging
            ? page.glyphs.charging : page.batteryGlyph(Battery.percent)
        title: Battery.percent + "%"
        lines: [page.batteryLine()]
    }

    // The charge as a level chip. In Custom the resume-to-stop band
    // sits over it, and its two ends drag in steps of 5.
    Item {
        id: band
        visible: Battery.present
        readonly property bool custom: page.chargeMode === "Custom"
        readonly property bool draggable: custom && page.chargeHelperFound && !page.chargeBusy
        width: parent.width
        implicitHeight: level.height + Theme.spaceM * 2 + (custom ? bandScale.height : 0)

        function pctAt(px) { return Math.max(0, Math.min(100, px / level.width * 100)) }

        Slider {
            id: level
            y: Theme.spaceM
            width: parent.width
            value: Battery.percent
            interactive: false
            fillColor: Theme.good
        }

        Rectangle {
            visible: band.custom
            x: level.width * page.chargeStart / 100
            width: level.width * (page.chargeStop - page.chargeStart) / 100
            y: level.y - Theme.spaceS
            height: level.height + Theme.spaceS * 2
            color: Qt.alpha(Theme.accent, 0.18)

            Rectangle { width: Theme.indicatorWidth; height: parent.height; color: Theme.accent }
            Rectangle { width: Theme.indicatorWidth; height: parent.height; anchors.right: parent.right; color: Theme.accent }
        }

        Repeater {
            model: band.draggable ? ["start", "stop"] : []

            MouseArea {
                required property string modelData
                readonly property int at: modelData === "stop" ? page.chargeStop : page.chargeStart
                x: level.width * at / 100 - width / 2
                y: level.y - Theme.spaceS
                width: Theme.spaceL * 2
                height: level.height + Theme.spaceS * 2
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                preventStealing: true

                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.indicatorWidth * 3
                    height: parent.height
                    radius: width / 2
                    color: Theme.accent
                    opacity: parent.pressed || parent.containsMouse ? 1 : 0
                }

                onPositionChanged: mouse => {
                    if (pressed) page.chargeSet(modelData, band.pctAt(mapToItem(level, mouse.x, 0).x))
                }
                onReleased: chargeDebounce.restart()
            }
        }

        // the band's two numbers, under its ends
        Item {
            id: bandScale
            visible: band.custom
            anchors.top: level.bottom
            anchors.topMargin: Theme.spaceS
            width: parent.width
            height: Theme.fontCaption + Theme.spaceS

            Repeater {
                model: [page.chargeStart, page.chargeStop]
                Text {
                    required property int modelData
                    required property int index
                    x: Math.max(0, Math.min(bandScale.width - width, level.width * modelData / 100 - width / 2))
                    text: modelData + "%"
                    color: Theme.textStrong
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontCaption
                }
            }
        }

        // keeps the card and chip apart from the mode under them
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Theme.borderWidth
            color: Theme.stroke
        }
    }

    SettingsField {
        label: "Charging"
        hint: page.chargeMode === "Custom" && page.chargeHelperFound
            ? "Drag the band's ends to set it" : page.chargeHint()

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

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WHEN IDLE" }

    SettingsNote {
        visible: !page.idleRunning
        text: "hypridle isn't running; a change starts it"
        alert: true
    }

    // each step at its time, from idle to the last one
    Item {
        id: timeline
        visible: page.listeners.length > 0
        readonly property real span: Math.max(60, ...page.listeners.map(l => l.timeout)) * 1.04
        width: parent.width
        implicitHeight: Theme.fontTitle + Theme.fontCaption + Theme.spaceL * 2 + Theme.spaceM

        Rectangle {
            id: track
            x: Theme.spaceL
            width: parent.width - Theme.spaceL * 2
            y: Theme.spaceM + Theme.fontTitle + Theme.spaceS
            height: Theme.borderWidth
            color: Theme.stroke
        }

        Text {
            x: track.x
            anchors.top: track.bottom
            anchors.topMargin: Theme.spaceS
            text: "idle"
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontCaption
        }

        Repeater {
            model: page.listeners

            Item {
                required property var modelData
                x: track.x + track.width * modelData.timeout / timeline.span
                y: Theme.spaceM

                Text {
                    anchors.horizontalCenter: parent.left
                    anchors.bottom: dot.top
                    anchors.bottomMargin: Theme.spaceS / 2
                    text: page.glyphs[modelData.label] || "•"
                    color: modelData.on ? Theme.textStrong : Theme.muted
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontBody
                }
                Rectangle {
                    id: dot
                    x: -width / 2
                    y: track.y - Theme.spaceM - height / 2
                    width: Theme.spaceS * 2
                    height: width
                    radius: width / 2
                    color: modelData.on ? Theme.accent : Theme.muted
                }
                Text {
                    anchors.horizontalCenter: parent.left
                    anchors.top: dot.bottom
                    anchors.topMargin: Theme.spaceS / 2
                    text: page.minutes(modelData.timeout).replace(" min", "")
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontCaption
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Theme.borderWidth
            color: Theme.stroke
        }
    }

    Repeater {
        // a file whose listeners changed under the page shows in file order
        model: page.ladder.length === page.listeners.length ? page.ladder : page.listeners.map((l, i) => i)

        SettingsField {
            required property int modelData
            readonly property int index: modelData
            readonly property var step: page.listeners[index]
            readonly property bool unplugged: step.label === "Suspend on battery"
            // the plain suspend, beside one that only runs on battery
            readonly property bool plugged: step.label === "Suspend"
                && page.listeners.some(l => l.label === "Suspend on battery")
            label: plugged ? "Suspend plugged in" : step.label
            mark: unplugged ? page.glyphs.battery : plugged ? page.glyphs.plug : ""
            hint: !step.on ? "Skipped" : page.stepHints[step.label] || ""
            dimmed: !step.on

            Row {
                anchors.right: parent.right
                spacing: Theme.spaceM

                FlyoutStepper {
                    visible: step.on
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fit(170)
                    // in 30-second steps
                    value: Math.round(step.timeout / 30)
                    minimum: 1
                    maximum: 240
                    valueWidth: 64
                    displayValue: page.minutes(step.timeout)
                    onStepped: delta => page.setStep(index, { timeout: Math.max(30, (value + delta) * 30) })
                }
                Text {
                    visible: !step.on
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fit(170)
                    horizontalAlignment: Text.AlignHCenter
                    text: "Off"
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }
                Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: step.on
                    onToggled: page.setStep(index, { on: !step.on })
                }
            }
        }
    }
}
