// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageDisplay.qml
//
// Connected displays, and the hl.monitor() rule each one falls under.
//
// What's listed comes from Hyprland (`hyprctl monitors -j`, as System does);
// what's changed is the rule in monitors.lua in the state directory, followed
// by a reload, which is what applies it. Until the first change there is no
// monitors.lua, and displays.lua's own catch-all rule is the one in force. A
// display with a rule of its own has that rule edited. A display that only
// matches the catch-all `output = ""` rule gets a rule of its own, copied
// from the catch-all, so a change to one display never reaches the others.
//
// Each display is a row that opens its settings in place; the arrangement
// picture above opens one too.
//
// With more than one display connected the page also picks between
// extending and duplicating, which is the same rules and the same reload:
// duplicate is hl.monitor()'s `mirror` pointing every other output at the
// first one.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services/HyprTables.js" as HyprTables
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Display"
    description: "Where your displays sit, and how each one draws."

    // [{ name, description, width, height, hz, scale, modes: ["WxH@R"] }]
    property var monitors: []
    // hl.monitor() calls, as HyprTables.readMonitors gives them
    property var rules: []

    readonly property var scales: [1, 1.25, 1.5, 1.75, 2]
    readonly property var rotations: [{ value: 0, text: "Normal" }, { value: 1, text: "90°" },
        { value: 2, text: "180°" }, { value: 3, text: "270°" }]

    // the display open under its row, by name
    property string openName: ""

    // The primary display: workspace 1 and the cursor start there, and
    // duplicate mode copies it. The saved choice while that display is on,
    // otherwise the first one on that Hyprland lists -- the built-in panel
    // on a laptop, which is also what Hyprland falls back to with no choice.
    // A saved primary that is off (the panel with the lid shut) stays saved,
    // and the first one on stands in for it.
    readonly property string stateDir: Settings.stateDir
    property string savedPrimary: ""
    readonly property var active: monitors.filter(m => !m.disabled)
    readonly property string primary: active.some(m => m.name === savedPrimary) ? savedPrimary
        : active.length > 0 ? active[0].name : monitors.length > 0 ? monitors[0].name : ""
    readonly property var standIn: savedPrimary !== "" && savedPrimary !== primary
        ? monitors.find(m => m.name === savedPrimary) || null : null

    // The panel lid.sh has switched off while the lid is shut, if any.
    property string lidOff: ""

    function byName(name) { return monitors.find(m => m.name === name) || null }
    function shortName(name) { var m = byName(name); return m ? m.short : name }
    // Read from Hyprland rather than the rules, so a mirror set anywhere
    // else (another config, hyprctl by hand) still shows up here.
    readonly property bool duplicating: monitors.some(m => m.mirrorOf !== "none")

    function reread() {
        luaFile.reload()
        luaFile.waitForJob()
        rules = HyprTables.readMonitors(luaFile.text() || seed())
        monitorsProc.running = true
    }

    // What monitors.lua starts from: displays.lua's default rule, which is
    // what applies while the file doesn't exist.
    function seed() {
        confFile.reload()
        confFile.waitForJob()
        return HyprTables.copyMonitors(confFile.text())
    }

    Component.onCompleted: reread()

    function fieldValue(rule, key, fallback) {
        var f = rule && rule.fields[key]
        return f && f.editable ? f.value : fallback
    }

    // A change to how a display draws (mode, scale, rotation) waits to be
    // kept: one the display can't show leaves nothing to click, so unless
    // Keep is pressed, or the page closed, it goes back after `revertSecs`.
    // { name, key, value (the old one), label }, or null
    property var trial: null
    property int trialLeft: 0
    readonly property int revertSecs: 15
    readonly property var drawKeys: ["mode", "scale", "transform"]
    readonly property var drawDefaults: ({ mode: "preferred", scale: 1, transform: 0 })

    function keepTrial() {
        trial = null
        trialTimer.stop()
        say("Kept", false)
    }

    function revertTrial() {
        var t = trial
        trial = null
        trialTimer.stop()
        var mon = byName(t.name)
        if (!mon) return
        writeField(mon, HyprTables.ruleFor(rules, t.name), t.key, t.value, t.label + " put back")
    }

    Timer {
        id: trialTimer
        interval: 1000
        repeat: true
        onTriggered: if (--page.trialLeft <= 0) page.revertTrial()
    }

    // mode, scale and rotation go on trial; anything else is written as is
    function setField(mon, rule, key, value, message) {
        if (drawKeys.indexOf(key) < 0) { writeField(mon, rule, key, value, message); return }
        if (trial && trial.name !== mon.name) keepTrial()
        // a second change during one trial still goes back to before the first
        var before = trial ? trial.value : fieldValue(rule, key, drawDefaults[key])
        var label = trial ? trial.label : mon.short + "'s " + (key === "mode" ? "mode" : key === "scale" ? "scale" : "rotation")
        writeField(mon, rule, key, value, message, ok => {
            if (!ok) return
            trial = { name: mon.name, key: key, value: before, label: label }
            trialLeft = revertSecs
            trialTimer.restart()
        })
    }

    function writeField(mon, rule, key, value, message, then) {
        patchLua(fieldPatch(mon, rule, key, value), message,
            key + " in that hl.monitor() rule isn't a plain value, edit it by hand", then)
    }

    function fieldPatch(mon, rule, key, value) {
        if (!rule || rule.output === "") {
            // no rule of its own: write one for this output, starting from
            // the catch-all's fields, so the change reaches no other display
            var fields = { output: mon.name }
            ;["mode", "position", "scale"].forEach(k => fields[k] = fieldValue(rule, k, k === "scale" ? 1 : k === "mode" ? "preferred" : "auto"))
            fields[key] = value
            return src => HyprTables.addMonitor(src, fields)
        }
        var index = rule.index
        return src => HyprTables.setMonitor(src, index, key, value)
    }

    // Closing the window or leaving the page mid-trial keeps the change:
    // whoever did that could see the display well enough to do it. Only the
    // timer running out (or Revert) puts it back.

    // Extend gives every display its own area; duplicate points all the
    // others at `primary` through hl.monitor()'s `mirror`. One patch for
    // the whole change rather than one per display, so the file is written
    // and Hyprland reloaded once instead of flickering through the
    // half-applied arrangements in between.
    //
    // Going back is the same write with an empty string: `mirror = ""`
    // releases an output, which is why nothing here has to delete a field.
    function setArrangement(duplicate) {
        if (primary === "" || monitors.length < 2) return
        var names = monitors.map(m => m.name)
        patchLua(function(src) {
            names.forEach(function(name) {
                if (src === null) return
                // re-read each time: an addMonitor() in an earlier pass
                // has already moved the indexes readMonitors() hands out
                var rule = HyprTables.ruleFor(HyprTables.readMonitors(src), name)
                // The primary itself is walked too: after a change of
                // primary it may be the one still carrying a mirror.
                var want = duplicate && name !== page.primary ? page.primary : ""
                if (rule !== null && rule.output !== "") {
                    src = HyprTables.setMonitor(src, rule.index, "mirror", want)
                    return
                }
                // Nothing to release on a display with no rule of its own.
                if (want === "" && !page.fieldValue(rule, "mirror", "")) return
                // Only the catch-all covers this output. Writing `mirror`
                // into that would point every display at the primary --
                // the primary included, which is a display mirroring
                // itself -- so split a rule off for this output instead,
                // the same copy "Own rule" makes.
                var fields = { output: name }
                ;["mode", "position", "scale"].forEach(function(k) {
                    fields[k] = page.fieldValue(rule, k, k === "scale" ? 1 : k === "mode" ? "preferred" : "auto")
                })
                fields.mirror = want
                src = HyprTables.addMonitor(src, fields)
            })
            return src
        }, duplicate ? "Displays duplicated onto " + primary : "Displays extended",
           "mirror in an hl.monitor() rule isn't a plain value, edit it by hand")
    }

    // Saved as a state file Hyprland's config reads, then a config-only
    // reload, as the animation time is -- one shell command, so the reload can't
    // run before the write lands. The reload applies the workspace rule and
    // the cursor's default display, but a rule only places a workspace when
    // it is created, so workspace 1 is also moved over explicitly.
    //
    // Success is only reported once the write and reload have actually
    // happened; any output from the after-command is a failure message.
    function setPrimary(name) {
        var previous = savedPrimary
        savedPrimary = name
        var move = ""
        if (duplicating) {
            // re-point the copies at the new primary; the displays all show
            // the same thing, so there is no workspace to move
            setArrangement(true)
        } else {
            move = "hl.dispatch(hl.dsp.workspace.move({ workspace = \"1\", monitor = "
                + JSON.stringify(name) + " }))"
        }
        AtomicFileWrite.write({
            path: stateDir + "/primary-display",
            transform: () => name + "\n",
            after: "hyprctl reload config-only >/dev/null || echo \"Hyprland didn't reload\""
                + (move === "" ? "" : "; hyprctl eval '" + move.replace(/'/g, "'\\''")
                    + "' >/dev/null || echo \"couldn't move workspace 1\""),
            done: (status, detail) => {
                if ((status === "ok" || status === "unchanged") && detail === "") {
                    page.say(name + " is the primary display", false)
                } else if (status === "ok" || status === "unchanged") {
                    page.say(name + " saved as primary, but " + detail.split("\n")[0], true)
                } else {
                    page.savedPrimary = previous
                    page.say("Couldn't save the primary display", true)
                }
            }
        })
    }

    // Displays that take part in the arrangement: not switched off (the
    // panel with the lid shut) and not copying another.
    readonly property var arranged: monitors.filter(m => !m.disabled && m.mirrorOf === "none")

    // A display dragged to (x, y) on the arrangement picture, written as
    // hl.monitor() positions with the primary pinned at 0x0. Two displays
    // centred on a shared edge are the common case, and get the primary's
    // 0x0 and an auto-center-* on the other: Hyprland lays out explicit
    // positions before auto ones, so that is measured from the primary and
    // still holds after a change of mode or scale. Anything else is an
    // explicit position for every display, which is what the picture shows.
    function arrange(name, x, y) {
        var p = arranged.find(m => m.name === primary)
        if (!p) return
        var at = {}
        arranged.forEach(m => at[m.name] = { x: m.x, y: m.y, w: m.lw, h: m.lh })
        at[name].x = x
        at[name].y = y
        var px = at[primary].x, py = at[primary].y
        Object.keys(at).forEach(n => { at[n].x = Math.round(at[n].x - px); at[n].y = Math.round(at[n].y - py) })

        var want = {}
        var others = Object.keys(at).filter(n => n !== primary)
        if (others.length === 1) {
            var o = at[others[0]], q = at[primary]
            var midX = Math.abs(o.x + o.w / 2 - q.w / 2) <= 1
            var midY = Math.abs(o.y + o.h / 2 - q.h / 2) <= 1
            var side = midY && o.x + o.w === 0 ? "left" : midY && o.x === q.w ? "right"
                : midX && o.y + o.h === 0 ? "up" : midX && o.y === q.h ? "down" : ""
            if (side !== "") {
                want[primary] = "0x0"
                want[others[0]] = "auto-center-" + side
            }
        }
        if (Object.keys(want).length === 0)
            Object.keys(at).forEach(n => want[n] = at[n].x + "x" + at[n].y)
        setPositions(want, name + " moved")
    }

    // { output: position } in one write and one reload
    function setPositions(want, message) {
        patchLua(function(src) {
            Object.keys(want).forEach(function(output) {
                if (src === null) return
                // re-read each time, as setArrangement does
                var rule = HyprTables.ruleFor(HyprTables.readMonitors(src), output)
                if (rule !== null && rule.output !== "") {
                    src = HyprTables.setMonitor(src, rule.index, "position", want[output])
                    return
                }
                // under the catch-all: a position there would move every
                // display, so split a rule off for this one
                var fields = { output: output }
                ;["mode", "scale"].forEach(function(k) {
                    fields[k] = page.fieldValue(rule, k, k === "scale" ? 1 : "preferred")
                })
                fields.position = want[output]
                src = HyprTables.addMonitor(src, fields)
            })
            return src
        }, message,
           "position in an hl.monitor() rule isn't a plain value, edit it by hand")
    }

    // "59.95" -> "59.95 Hz", "60.00" -> "60 Hz"
    function hzText(hz) {
        var v = Number(hz)
        return (Math.abs(v - Math.round(v)) < 0.005 ? String(Math.round(v)) : v.toFixed(2)) + " Hz"
    }
    function resText(res) { return res.replace("x", " × ") }

    // The rates Hyprland offers at one resolution, fastest first.
    function ratesAt(mon, res) { return mon.modes.filter(m => m.split("@")[0] === res).map(m => m.split("@")[1]) }

    // the offered rate nearest the one it's running at
    function currentRate(mon) {
        var rates = ratesAt(mon, mon.res)
        var best = rates.length > 0 ? rates[0] : mon.hz.toFixed(2)
        rates.forEach(r => { if (Math.abs(r - mon.hz) < Math.abs(best - mon.hz)) best = r })
        return best
    }

    // Writes "WxH@R", or "preferred" for the mode Hyprland lists first --
    // what the display asks for -- so the rule keeps following it.
    function setMode(mon, rule, res, hz) {
        var mode = res + "@" + hz
        setField(mon, rule, "mode", mode === mon.modes[0] ? "preferred" : mode,
            mon.short + " set to " + resText(res) + " at " + hzText(hz))
    }

    // A new resolution keeps the rate it's on where it can, else takes the
    // fastest there is.
    function setResolution(mon, rule, res) {
        var rates = ratesAt(mon, res)
        var keep = rates.find(r => Math.abs(r - mon.hz) < 0.05)
        setMode(mon, rule, res, keep !== undefined ? keep : rates[0])
    }

    Process {
        id: monitorsProc
        // `all`, not the plain list: a mirrored output drops out of
        // `hyprctl monitors` entirely, so without it a display would
        // vanish from this page the moment it was set to duplicate --
        // taking the control to undo that with it.
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var data
                try { data = JSON.parse(text) } catch (e) { page.say("hyprctl monitors didn't answer", true); return }
                page.monitors = data.map(m => {
                    // every mode once, in Hyprland's order (best first)
                    var all = []
                    ;(m.availableModes || []).forEach(s => {
                        s = s.replace(/Hz$/, "")
                        if (all.indexOf(s) < 0) all.push(s)
                    })
                    var panel = /^(eDP|LVDS|DSI)-/.test(m.name)
                    // the model when it's a name, not a panel's hex code
                    var nice = panel ? "Built-in display"
                        : m.model && !/^0x/i.test(m.model) ? m.model : m.description || m.name
                    // lw/lh: its size in layout coordinates, which is
                    // what x and y are measured in
                    var turned = m.transform % 2 === 1
                    return { name: m.name, description: m.description, width: m.width, height: m.height,
                        nice: nice, short: panel ? "Built-in" : nice,
                        icon: panel ? "󰌢" : "󰍹", modes: all, res: m.width + "x" + m.height,
                        transform: m.transform,
                        x: m.x, y: m.y, disabled: m.disabled === true,
                        lw: (turned ? m.height : m.width) / m.scale,
                        lh: (turned ? m.width : m.height) / m.scale,
                        hz: m.refreshRate, scale: m.scale,
                        // "none" when the output stands on its own, else the
                        // id of the monitor it copies
                        mirrorOf: m.mirrorOf || "none" }
                })
            }
        }
    }

    FileView {
        path: page.stateDir + "/primary-display"
        printErrors: false
        blockLoading: true
        onLoaded: page.savedPrimary = text().trim()
    }

    FileView {
        id: luaFile
        path: HyprLuaWrite.monitorsPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: if (!HyprLuaWrite.busy) page.reread()
    }

    FileView {
        id: confFile
        path: HyprLuaWrite.displaysPath
        blockLoading: true
        printErrors: false
    }

    // HyprLuaWrite is shared with the Keybinds editor and the other pages;
    // each result comes back to the page that asked for it
    function patchLua(transform, message, refusal, then) {
        HyprLuaWrite.patchMonitors(transform, seed, message, refusal, (ok, msg) => {
            page.say(msg, !ok)
            page.reread()
            if (then) then(ok)
        })
    }

    // the change on trial, pinned over the rows so it's in reach wherever
    // the page is scrolled
    pinned: Item {
        width: parent ? parent.width : 0
        height: trialRow.height + Theme.spaceL

        SettingsField {
            id: trialRow
            label: "Keep this?"
            hint: page.trial ? page.trial.label + " goes back in " + page.trialLeft + " s" : ""
            searchable: false

            Row {
                anchors.right: parent.right
                spacing: Theme.spaceS
                FlyoutChip { text: "Revert"; onClicked: page.revertTrial() }
                FlyoutChip { text: "Keep"; selected: true; onClicked: page.keepTrial() }
            }
        }
    }
    pinnedVisible: trial !== null

    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/singularity-lid-docked"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: page.lidOff = text().trim()
        onLoadFailed: page.lidOff = ""
    }

    // what a display that's off says about it
    function offText(mon) { return mon.name === lidOff ? "Off · lid shut" : "Off" }

    // The picture: the displays taking part where Hyprland has them, and
    // each one that's off to their left, where it can't overlap them.
    readonly property var pictured: {
        var out = arranged.map(m => Object.assign({ off: false }, m))
        var b = { x0: 0, y0: 0, y1: 0 }
        if (arranged.length > 0) {
            b.x0 = Math.min(...arranged.map(m => m.x))
            b.y0 = Math.min(...arranged.map(m => m.y))
            b.y1 = Math.max(...arranged.map(m => m.y + m.lh))
        }
        monitors.filter(m => m.disabled).forEach(m => {
            b.x0 -= m.lw
            out.push(Object.assign({}, m, { off: true, offText: page.offText(m), icon: "󰛧",
                x: b.x0, y: arranged.length > 0 ? Math.round((b.y0 + b.y1 - m.lh) / 2) : 0 }))
        })
        return out
    }

    FlyoutHeading { text: "ARRANGEMENT" }

    DisplayLayout {
        visible: page.monitors.length > 0
        width: parent.width
        monitors: page.pictured
        primary: page.primary
        selected: page.openName
        onMoved: (name, x, y) => page.arrange(name, x, y)
        onPicked: name => page.openName = page.openName === name ? "" : name
    }

    SettingsNote {
        visible: page.standIn !== null
        text: page.standIn ? page.standIn.short + " is primary, but off; " + page.shortName(page.primary) + " stands in" : ""
    }

    // Only worth showing with somewhere to send the picture.
    SettingsField {
        visible: page.active.length > 1
        label: "Arrangement"
        hint: page.duplicating
            ? "Every display shows " + page.shortName(page.primary)
            : "Each display has its own workspaces"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: [{ value: false, text: "Extend" }, { value: true, text: "Duplicate" }]
            current: page.duplicating
            onPicked: v => page.setArrangement(v)
        }
    }

    SettingsField {
        visible: page.active.length > 1
        label: "Primary"
        hint: "Workspace 1 and the cursor start here"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: page.active.map(m => ({ value: m.name, text: m.short }))
            current: page.primary
            onPicked: v => page.setPrimary(v)
        }
    }

    // singularityResetWorkspaces() lives in displays.lua; anything it
    // prints means the eval failed.
    Process {
        id: resetProc
        command: ["hyprctl", "eval", "singularityResetWorkspaces()"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = text.trim()
                if (out === "ok") page.say("Workspace 1 is on " + page.shortName(page.primary) + ", 2 onward on the others", false)
                else page.say("Couldn't reset workspaces: " + out.split("\n")[0], true)
            }
        }
    }

    SettingsField {
        visible: page.active.length > 1 && !page.duplicating
        label: "Workspaces"
        hint: "1 on " + page.shortName(page.primary) + ", 2 onward on the others"

        FlyoutChip {
            anchors.right: parent.right
            text: "Reset"
            onClicked: resetProc.running = true
        }
    }

    // Digital vibrance, 0 (greyscale) to 100 with 50 leaving colours be:
    // a state file displays.lua turns into a screen shader (vibrance.frag),
    // then a config-only reload, as the primary display is. The slider moves
    // live, so the writes wait for it to settle for a moment rather than
    // reloading Hyprland on every step.
    property int vibrance: 50
    readonly property var vibranceMarks: [
        { at: 0, label: "Greyscale" }, { at: 50, label: "Normal" }, { at: 100, label: "Vivid" },
    ]

    Timer {
        id: vibranceWrite
        interval: 150
        onTriggered: {
            var v = page.vibrance
            AtomicFileWrite.write({
                path: page.stateDir + "/vibrance",
                transform: () => v + "\n",
                after: "hyprctl reload config-only >/dev/null || echo \"Hyprland didn't reload\"",
                done: (status, detail) => {
                    if ((status === "ok" || status === "unchanged") && detail === "") return
                    page.say(status === "ok" || status === "unchanged"
                        ? "Vibrance saved, but " + detail.split("\n")[0] : "Couldn't save vibrance", true)
                }
            })
        }
    }

    FileView {
        path: page.stateDir + "/vibrance"
        printErrors: false
        blockLoading: true
        onLoaded: {
            var v = parseInt(text().trim())
            page.vibrance = isNaN(v) ? 50 : Math.max(0, Math.min(100, v))
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "COLOUR" }

    SettingsField {
        label: "Vibrance"
        hint: page.vibrance === 50 ? "How strongly colours show, on every display"
            : "On every display; screenshots show it too"

        FlyoutSliderRow {
            anchors.right: parent.right
            width: Theme.fit(260)
            label: ""
            suffix: "%"
            value: page.vibrance
            marks: page.vibranceMarks
            onMoved: v => { page.vibrance = v; vibranceWrite.restart() }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "DISPLAYS" + "  " + page.monitors.length }

    // A display's row, and the settings it opens under itself.
    component DisplayBlock: Column {
        id: mon
        required property var modelData
        readonly property var m: modelData
        readonly property var rule: HyprTables.ruleFor(page.rules, m.name)
        readonly property real ruleScale: Number(page.fieldValue(rule, "scale", 1))
        readonly property bool mirrored: m.mirrorOf !== "none"
        readonly property bool isOpen: page.openName === m.name
        readonly property string rate: page.currentRate(m)
        readonly property var rates: page.ratesAt(m, m.res)
        // the resolutions on offer, in Hyprland's order; the first is native
        readonly property var resolutions: m.modes.map(s => s.split("@")[0]).filter((r, i, a) => a.indexOf(r) === i)
        readonly property string nativeRes: resolutions.length > 0 ? resolutions[0] : m.res

        width: parent ? parent.width : 0

        FlyoutRow {
            leadingIcon: mon.m.disabled ? "󰛧" : mon.m.icon
            label: mon.m.nice
            note: mon.m.name
            badge: !mon.m.disabled && mon.m.name === page.primary ? "Primary" : ""
            highlighted: mon.isOpen
            trailing: (mon.m.disabled ? page.offText(mon.m)
                : mon.mirrored ? "Copying " + page.shortName(page.primary)
                : page.resText(mon.m.res) + " · " + page.hzText(mon.rate)
                    + (mon.ruleScale !== 1 ? " · " + Math.round(mon.ruleScale * 100) + "%" : ""))
                + "  " + (mon.isOpen ? "󰅀" : "󰅂")
            onActivated: page.openName = mon.isOpen ? "" : mon.m.name
        }

        SettingsIndent {
            visible: mon.isOpen

            // switched off: none of the rest would apply
            SettingsValue {
                visible: mon.m.disabled
                label: "Status"
                hint: mon.m.name === page.lidOff ? "It comes back on when the lid opens" : "Hyprland has it switched off"
                value: page.offText(mon.m)
            }

            SettingsValue {
                visible: !mon.m.disabled && mon.mirrored
                label: "Showing"
                hint: "Duplicate: the same picture everywhere"
                value: "A copy of " + page.shortName(page.primary)
            }

            SettingsField {
                visible: !mon.m.disabled
                label: "Resolution"
                hint: mon.m.res === mon.nativeRes ? "The display's own; sharpest" : "Below native, so it's scaled up"

                SettingsDropdown {
                    anchors.right: parent.right
                    width: Theme.fit(200)
                    model: mon.resolutions
                    labelFor: r => page.resText(r) + (r === mon.nativeRes ? "  native" : "")
                    current: mon.m.res
                    onPicked: r => page.setResolution(mon.m, mon.rule, r)
                }
            }

            SettingsField {
                visible: !mon.m.disabled
                label: "Refresh rate"
                hint: mon.rates.length > 1 ? "How often it redraws" : "The only rate at this resolution"

                FlyoutSegmented {
                    visible: mon.rates.length > 1
                    anchors.right: parent.right
                    fill: false
                    model: mon.rates.map(r => ({ value: r, text: page.hzText(r) }))
                    current: mon.rate
                    onPicked: r => page.setMode(mon.m, mon.rule, mon.m.res, r)
                }
                Text {
                    visible: mon.rates.length <= 1
                    anchors.right: parent.right
                    text: page.hzText(mon.rate)
                    color: Theme.textStrong
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }
            }

            SettingsField {
                visible: !mon.m.disabled
                label: "Scale"
                hint: (mon.ruleScale === 1 ? "Native: " : "Looks like ")
                    + Math.round(mon.m.lw) + " × " + Math.round(mon.m.lh)

                FlyoutSegmented {
                    anchors.right: parent.right
                    fill: false
                    // the rule's own value too, if it's none of these
                    model: (page.scales.some(v => Math.abs(v - mon.ruleScale) < 0.001)
                        ? page.scales : page.scales.concat([mon.ruleScale]).sort((a, b) => a - b))
                        .map(v => ({ value: v, text: Math.round(v * 100) + "%" }))
                    current: model.map(o => o.value).find(v => Math.abs(v - mon.ruleScale) < 0.001)
                    onPicked: v => page.setField(mon.m, mon.rule, "scale", v, mon.m.short + " scaled to " + Math.round(v * 100) + "%")
                }
            }

            SettingsField {
                visible: !mon.m.disabled
                label: "Rotation"
                hint: "Turns the picture, for a display on its side"

                FlyoutSegmented {
                    anchors.right: parent.right
                    fill: false
                    model: page.rotations
                    current: mon.m.transform
                    onPicked: v => page.setField(mon.m, mon.rule, "transform", v,
                        mon.m.short + (v === 0 ? " turned back to normal" : " turned " + page.rotations[v].text))
                }
            }
        }
    }

    Repeater {
        model: page.monitors
        DisplayBlock {}
    }

    FlyoutRow {
        visible: page.monitors.length === 0
        enabled: false
        label: "Hyprland reports no displays"
    }
}
