// Neutrino - Quickshell
// ~/.config/quickshell/SettingsPageDisplay.qml
//
// Connected displays, and the hl.monitor() rule each one falls under.
//
// What's listed comes from Hyprland (`hyprctl monitors -j`, as System does);
// what's changed is the rule in hyprland.lua, followed by a reload, which is
// what applies it. A display with a rule of its own has that rule edited. A
// display that only matches the catch-all `output = ""` rule edits the
// catch-all -- which on a laptop is the rule that matters -- and says so,
// with "Own rule" to split it off into one for that output alone.
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

    title: "Display"
    description: "Arrangement, primary display, resolution and scale, saved as hl.monitor() rules in hyprland.lua. Hyprland reloads on each change."

    // [{ name, description, width, height, hz, scale, modes: ["WxH@R"] }]
    property var monitors: []
    // hl.monitor() calls, as HyprTables.readMonitors gives them
    property var rules: []

    readonly property var scales: [1, 1.25, 1.5, 1.6, 1.75, 2]

    // The primary display: workspace 1 and the cursor start there, and
    // duplicate mode copies it. The saved choice while that display is
    // connected, otherwise the first Hyprland lists -- the built-in panel on
    // a laptop, which is also what Hyprland falls back to with no choice.
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/neutrino"
    property string savedPrimary: ""
    readonly property string primary: monitors.some(m => m.name === savedPrimary) ? savedPrimary
        : monitors.length > 0 ? monitors[0].name : ""
    // Read from Hyprland rather than the rules, so a mirror set anywhere
    // else (another config, hyprctl by hand) still shows up here.
    readonly property bool duplicating: monitors.some(m => m.mirrorOf !== "none")

    function reread() {
        luaFile.reload()
        luaFile.waitForJob()
        rules = HyprTables.readMonitors(luaFile.text())
        monitorsProc.running = true
    }

    Component.onCompleted: reread()

    function fieldValue(rule, key, fallback) {
        var f = rule && rule.fields[key]
        return f && f.editable ? f.value : fallback
    }

    function setField(mon, rule, key, value, message) {
        if (!rule) {
            // no rule matches at all: write one for this output
            writer.patch(src => HyprTables.addMonitor(src,
                { output: mon.name, mode: "preferred", position: "auto", scale: 1, [key]: value }), message)
            return
        }
        var index = rule.index
        writer.patch(src => HyprTables.setMonitor(src, index, key, value), message,
            key + " in that hl.monitor() rule isn't a plain value, edit it by hand")
    }

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
        writer.patch(function(src) {
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
    // reload, as Animation Speed is -- one shell command, so the reload can't
    // run before the write lands. The reload applies the workspace rule and
    // the cursor's default display, but a rule only places a workspace when
    // it is created, so workspace 1 is also moved over explicitly.
    function setPrimary(name) {
        savedPrimary = name
        if (duplicating) {
            // re-point the copies at the new primary; the displays all show
            // the same thing, so there is no workspace to move
            setArrangement(true)
            primaryProc.move = ""
        } else {
            primaryProc.move = "hl.dispatch(hl.dsp.workspace.move({ workspace = \"1\", monitor = "
                + JSON.stringify(name) + " }))"
        }
        primaryProc.command = ["sh", "-c",
            'mkdir -p "$1" && printf "%s\\n" "$2" > "$1/primary-display" && hyprctl reload config-only >/dev/null'
                + ' && { [ -z "$3" ] || hyprctl eval "$3" >/dev/null; }',
            "sh", stateDir, name, primaryProc.move]
        primaryProc.running = true
        say(name + " is the primary display")
    }

    // copy the catch-all's fields into a rule naming this output
    function ownRule(mon, rule) {
        var fields = { output: mon.name }
        ;["mode", "position", "scale"].forEach(k => fields[k] = fieldValue(rule, k, k === "scale" ? 1 : k === "mode" ? "preferred" : "auto"))
        writer.patch(src => HyprTables.addMonitor(src, fields), mon.name + " has its own rule now")
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
                    var seen = {}
                    // Hyprland lists modes best-first: keep every rate at the
                    // current resolution, and only the first (fastest) of
                    // the others, so a TV's fifteen modes don't bury the page
                    var modes = (m.availableModes || []).map(s => s.replace(/Hz$/, ""))
                        .filter(s => {
                            var res = s.split("@")[0]
                            var k = res === m.width + "x" + m.height ? s : res
                            if (seen[k]) return false
                            seen[k] = true
                            return true
                        })
                    return { name: m.name, description: m.description, width: m.width, height: m.height,
                        hz: m.refreshRate, scale: m.scale, modes: modes,
                        // "none" when the output stands on its own, else the
                        // id of the monitor it copies
                        mirrorOf: m.mirrorOf || "none" }
                })
            }
        }
    }

    Process {
        id: primaryProc
        property string move: ""
    }

    FileView {
        path: page.stateDir + "/primary-display"
        printErrors: false
        blockLoading: true
        onLoaded: page.savedPrimary = text().trim()
    }

    FileView {
        id: luaFile
        path: writer.confPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: if (!writer.busy) page.reread()
    }

    HyprLuaWrite {
        id: writer
        visible: false
        onPatched: (ok, message) => {
            page.say(message, !ok)
            page.reread()
        }
    }

    // Only worth showing with somewhere to send the picture.
    SettingsField {
        visible: page.monitors.length > 1
        label: "Arrangement"
        hint: page.duplicating
            ? "Every display is showing " + page.primary
            : "Each display has its own space; duplicate shows " + page.primary + " on all of them"

        Row {
            anchors.right: parent.right
            spacing: 4

            FlyoutChip {
                text: "Extend"
                selected: !page.duplicating
                onClicked: if (!selected) page.setArrangement(false)
            }
            FlyoutChip {
                text: "Duplicate"
                selected: page.duplicating
                onClicked: if (!selected) page.setArrangement(true)
            }
        }
    }

    SettingsField {
        visible: page.monitors.length > 1
        label: "Primary"
        hint: "Workspace 1 and the cursor start here, and duplicate copies it"

        Row {
            anchors.right: parent.right
            spacing: 4

            Repeater {
                model: page.monitors
                FlyoutChip {
                    required property var modelData
                    text: modelData.name
                    selected: page.primary === modelData.name
                    onClicked: if (!selected) page.setPrimary(modelData.name)
                }
            }
        }
    }

    Repeater {
        model: page.monitors

        Column {
            id: mon
            required property var modelData
            readonly property var rule: HyprTables.ruleFor(page.rules, modelData.name)
            readonly property bool catchAll: rule !== null && rule.output === ""
            readonly property var mode: page.fieldValue(rule, "mode", "preferred")
            readonly property real ruleScale: Number(page.fieldValue(rule, "scale", 1))
            readonly property bool mirrored: modelData.mirrorOf !== "none"

            width: parent.width
            spacing: 6

            FlyoutHeading { text: mon.modelData.name + " · " + mon.modelData.description.toUpperCase() }

            SettingsField {
                label: "Now"
                hint: mon.rule === null ? "No hl.monitor() rule matches this display"
                    : mon.catchAll ? "Set by the rule for every display (output = \"\")"
                    : "Set by its own rule"

                Row {
                    anchors.right: parent.right
                    spacing: 8

                    Text {
                        height: Theme.fs(20)
                        verticalAlignment: Text.AlignVCenter
                        // a mirrored output reports the geometry it is
                        // copying, so its own numbers would just be the
                        // primary's repeated back
                        text: mon.mirrored ? "Copying " + page.primary
                            : mon.modelData.width + "×" + mon.modelData.height + " @ "
                            + mon.modelData.hz.toFixed(2) + " Hz · scale " + mon.modelData.scale
                        color: Theme.bright
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontBody
                    }
                    FlyoutChip {
                        visible: mon.catchAll
                        text: "Own rule"
                        onClicked: page.ownRule(mon.modelData, mon.rule)
                    }
                }
            }

            SettingsField {
                label: "Scale"
                hint: mon.mirrored ? "Saved to its rule, and applies once this display is extended again"
                    : "1 is native; fractions that don't divide the resolution cleanly get rounded"

                Row {
                    anchors.right: parent.right
                    spacing: 4
                    Repeater {
                        model: page.scales
                        FlyoutChip {
                            required property var modelData
                            text: String(modelData)
                            selected: Math.abs(mon.ruleScale - modelData) < 0.001
                            onClicked: if (!selected)
                                page.setField(mon.modelData, mon.rule, "scale", modelData, mon.modelData.name + " scale set to " + modelData)
                        }
                    }
                }
            }

            SettingsField {
                label: "Mode"
                hint: mon.mirrored ? "Saved to its rule, and applies once this display is extended again"
                    : "preferred is what the display asks for"

                Flow {
                    anchors.right: parent.right
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: ["preferred", "highres", "highrr"].concat(mon.modelData.modes)
                        FlyoutChip {
                            required property var modelData
                            text: modelData
                            selected: mon.mode === modelData
                            onClicked: if (!selected)
                                page.setField(mon.modelData, mon.rule, "mode", modelData, mon.modelData.name + " mode set to " + modelData)
                        }
                    }
                }
            }

            Item { width: 1; height: 8 }
        }
    }
}
