// Singularity - Quickshell
// ~/.config/quickshell/settings/KeybindsBody.qml
//
// The Keybinds editor, one list:
//
//   every hl.bind() in hyprland.lua, grouped by the config's
//   `-- --- Section ---` markers, one line each; a bind opens in place to
//   edit it (or, for the few too tangled to rewrite, to what it runs and
//   why), and each group ends with Add a bind…
//
//   then SUGGESTED: a catalogue of binds worth having (HyprPresets.js),
//   each shown against what the config already has; tick the ones you want
//   and they're written in one go, or open one first to change its combo
//
// One search covers both, and Press keys looks a combo up by pressing it.
//
// Parsing and rewriting live in HyprBinds.js, the safe write in
// HyprLuaWrite.qml, the catalogue in HyprPresets.js. Nothing here builds Lua
// by hand. Hosted by SettingsPageKeybinds.qml, whose toast carries the
// results.
//
// The file is re-read right before writing: if it changed on disk since it
// was parsed (an nvim session, git), nothing is written, since the edit's
// offsets point into text that no longer exists.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services/HyprBinds.js" as HyprBinds
import "../services/HyprPresets.js" as HyprPresets
import "../services"
import "../flyouts"

Column {
    id: root

    // hl.bind options, as a person would say them
    readonly property var flagLabels: ({
        locked: "works when locked", repeating: "repeats when held", mouse: "mouse",
        release: "on release", long_press: "hold", non_consuming: "passes key on",
    })
    // the ones the editor offers as toggles, in the order they're written
    readonly property var flagOrder: ["locked", "repeating", "mouse", "release", "long_press", "non_consuming"]

    width: parent ? parent.width : 0
    spacing: Theme.spaceM

    // the SettingsPage this sits on, for its toast
    required property var page

    readonly property string confPath: HyprLuaWrite.confPath
    readonly property string home: Quickshell.env("HOME")
    // "~/.config/hypr/hyprland.lua" reads better than the absolute path
    readonly property string shortConfPath: confPath.indexOf(home) === 0
        ? "~" + confPath.slice(home.length) : confPath

    // the line the path link opens at: the bind open in the list, if any
    readonly property int linkLine: editRow ? editRow.line : openRow ? openRow.line : 0

    // The config itself, straight from here. With a line it goes to the
    // editor at that line; without one it goes through open-file.sh, which
    // honours whatever this machine actually opens .lua with (LinkRow.qml
    // and the launcher's file search use the same script).
    function openConf(line) {
        if (line > 0) Quickshell.execDetached(["alacritty", "-e", "nvim", "+" + line, confPath])
        else Quickshell.execDetached([home + "/.config/quickshell/scripts/open-file.sh", confPath])
    }

    // total height of the list, editor and preset bar together, so opening
    // either of the others shrinks the list
    property int bodyHeight: Theme.fit(520)

    property var model: null
    property string query: ""
    readonly property bool busy: HyprLuaWrite.busy
    // what the last write put on disk; undo only runs while the file still says it
    property string lastWritten: ""
    property string pendingMessage: ""

    // editor: one open at a time, under whatever opened it. editSlot names
    // that place -- "row:<callStart>", "add:<group>", "find", "preset:<id>" --
    // and the slot there loads the editor while it matches.
    property string editMode: ""     // "" | "add" | "edit"
    property string editSlot: ""
    property var editRow: null
    // a bind that can't be edited, opened to what it runs and why
    property var openRow: null
    property string editKeys: ""
    property string editCmd: ""
    property string editDesc: ""
    // a Lua action over several lines: kept as written, not shown in a field
    readonly property bool editCmdKept: editRow !== null && !editRow.isExec && editRow.cmdSrc.indexOf("\n") >= 0
    // the field the editor focuses when it opens: "keys", "cmd" or ""
    property string editFocus: ""
    property string editCategory: ""
    property string editKind: "exec" // "exec" | "lua"
    // the bind options being edited, as { locked: true, ... }
    property var editFlags: ({})
    // false when the call's options table holds more than plain `x = true`:
    // it's then kept exactly as written rather than rewritten from chips
    property bool editFlagsSimple: true
    property string editOptsSrc: ""
    property bool capturing: false
    property string captureMods: ""
    // Press keys: looking a combo up instead of typing it
    property bool finding: false
    property string findKeys: ""
    // the combo a conflict warning was shown for; saving it again goes ahead
    property string conflictAck: ""
    property string editError: ""

    // presets
    property string packFilter: ""
    property bool hideBound: true
    // id -> preset, for the ones ticked
    property var selection: ({})
    property int selectionCount: 0
    // set once the "some of these combos are taken" warning has been shown
    property bool presetAck: false
    // binaries a preset asked for that are actually installed
    property var present: ({})

    function say(msg, isError) { page.say(msg, isError) }

    function reparse(fromDisk) {
        var text = luaFile.text()
        if (model && text === model.src) return
        model = HyprBinds.parse(text)
        if (fromDisk && (editMode !== "" || openRow)) {
            closeEditor()
            say("hyprland.lua changed on disk, editor closed", true)
        }
    }

    FileView {
        id: luaFile
        path: root.confPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload()
            if (!root.busy) root.reparse(true)
        }
    }

    // Which of the tools the presets call for exist. One sweep, not one
    // process per preset, and the answer only greys rows out -- a preset is
    // never hidden for it.
    Process {
        id: haveProc
        running: false
        command: ["sh", "-c", "for b in " + HyprPresets.neededBinaries().join(" ")
            + "; do command -v \"$b\" >/dev/null 2>&1 && echo \"$b\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var found = {}
                text.split("\n").forEach(n => { if (n !== "") found[n] = true })
                root.present = found
            }
        }
    }

    // the page is built each time it's shown, so this is a fresh load
    Component.onCompleted: {
        reparse(false)
        if (luaFile.text() === "") say("Couldn't read " + confPath, true)
        haveProc.running = true
        search.forceFocus()
    }

    // --- grouping: the config's own binds --------------------------------

    // The file's `-- --- Name ---` sections, gathered into the groups the
    // list shows, in the order you'd look for them: opening things, the
    // shell's own tools, handling windows, getting around, the session, and
    // the hardware keys last. A section not named here (one added by hand)
    // keeps its own heading, after these, in file order. The editor's
    // Category still means the file's section; this only changes the list.
    readonly property var displayGroups: [
        { name: "Apps",       sections: ["Launchers"] },
        { name: "Shell",      sections: ["Shell windows", "Clipboard", "Calculator and file search",
                                         "Notes", "Claude"] },
        { name: "Windows",    sections: ["Window Management", "Mouse", "Scratchpad"] },
        { name: "Focus",      sections: ["Focus"] },
        { name: "Workspaces", sections: ["Workspaces"] },
        { name: "Session",    sections: ["Session", "Screenshot"] },
        { name: "Hardware keys", sections: ["Function Keys", "Media Keys", "Lock Keys", "Lid"] },
    ]

    // Within a section, a bind that does the same as an earlier one (two
    // keys for maximize) is listed right under it rather than lines later.
    function clusterSame(rows) {
        var out = []
        rows.forEach(r => {
            var at = -1
            for (var i = out.length - 1; i >= 0; i--)
                if (r.desc !== "" && out[i].desc === r.desc) { at = i; break }
            if (at < 0) out.push(r)
            else out.splice(at + 1, 0, r)
        })
        return out
    }

    readonly property var groups: {
        if (!model) return []
        var q = query.trim().toLowerCase()
        var f = findKeys !== "" ? HyprBinds.normalizeKeys(findKeys) : ""
        var groupOf = {}
        displayGroups.forEach(g => g.sections.forEach(sec => groupOf[sec] = g.name))
        var bySection = {}
        for (var i = 0; i < model.rows.length; i++) {
            var r = model.rows[i]
            var sec = r.category !== "" ? r.category : "Other"
            var shown = groupOf[sec] || sec
            if (q !== "" && (r.keys + "\n" + r.desc + "\n" + r.command + "\n" + sec + "\n" + shown)
                    .toLowerCase().indexOf(q) < 0)
                continue
            if (f !== "" && r.norm !== f) continue
            if (!bySection[sec]) bySection[sec] = []
            bySection[sec].push(r)
        }
        var out = []
        // `section` is where Add a bind… writes: the group's last section
        // that has binds
        var take = (name, sections) => {
            var rows = [], last = ""
            sections.forEach(sec => {
                if (bySection[sec]) { rows = rows.concat(clusterSame(bySection[sec])); last = sec }
            })
            if (rows.length > 0) out.push({ name: name, rows: rows, section: last })
        }
        displayGroups.forEach(g => take(g.name, g.sections))
        model.categories.map(c => c.name).concat(["Other"])
            .filter(sec => !groupOf[sec])
            .forEach(sec => take(sec, [sec]))
        return out
    }

    readonly property int editableCount: model ? model.rows.filter(r => r.editable).length : 0

    // --- grouping: the catalogue -----------------------------------------

    readonly property var packNames: HyprPresets.PACKS.map(p => p.name)

    // Every preset, wrapped with what the config says about it and whether
    // the tools it needs are installed.
    readonly property var presetGroups: {
        if (!model) return []
        var q = query.trim().toLowerCase()
        var f = findKeys !== "" ? HyprBinds.normalizeKeys(findKeys) : ""
        var out = []
        var packs = HyprPresets.PACKS
        for (var i = 0; i < packs.length; i++) {
            var pack = packs[i]
            if (packFilter !== "" && pack.name !== packFilter) continue
            var items = []
            for (var j = 0; j < pack.binds.length; j++) {
                var b = pack.binds[j]
                var st = HyprPresets.status(model, b)
                if (hideBound && st.state === "bound") continue
                if (f !== "" && HyprBinds.normalizeKeys(b.keys) !== f) continue
                var action = b.lua ? b.lua : b.cmd
                if (q !== "" && (b.keys + "\n" + b.desc + "\n" + action + "\n" + pack.name)
                        .toLowerCase().indexOf(q) < 0)
                    continue
                var missing = (b.needs || []).filter(n => !present[n])
                items.push({
                    preset: b, id: HyprPresets.id(b), keys: b.keys, desc: b.desc,
                    action: action, section: b.section,
                    state: st.state, other: st.row, missing: missing,
                })
            }
            if (items.length) out.push({ name: pack.name, note: pack.note, items: items })
        }
        return out
    }

    readonly property int presetTotal: {
        var n = 0
        HyprPresets.PACKS.forEach(p => n += p.binds.length)
        return n
    }

    readonly property int presetBound: {
        if (!model) return 0
        var n = 0
        HyprPresets.PACKS.forEach(p => p.binds.forEach(b => {
            if (HyprPresets.status(model, b).state === "bound") n++
        }))
        return n
    }

    // --- selection -------------------------------------------------------

    function toggleSelect(item) {
        if (item.state === "bound") {
            say("Already in your config" + (item.other ? " on line " + item.other.line : ""), false)
            return
        }
        var next = {}
        for (var k in selection) if (k !== item.id) next[k] = selection[k]
        if (selection[item.id] !== true) next[item.id] = true
        selection = next
        selectionCount = Object.keys(next).length
        presetAck = false
    }

    function selectPack(group, on) {
        var next = {}
        for (var k in selection) next[k] = selection[k]
        group.items.forEach(it => {
            if (it.state === "bound") return
            if (on) next[it.id] = true
            else delete next[it.id]
        })
        selection = next
        selectionCount = Object.keys(next).length
        presetAck = false
    }

    function packFullySelected(group) {
        var any = false
        for (var i = 0; i < group.items.length; i++) {
            var it = group.items[i]
            if (it.state === "bound") continue
            any = true
            if (selection[it.id] !== true) return false
        }
        return any
    }

    function clearSelection() {
        selection = ({})
        selectionCount = 0
        presetAck = false
    }

    // the ticked presets, in catalogue order
    function selectedPresets() {
        var out = []
        HyprPresets.PACKS.forEach(p => p.binds.forEach(b => {
            if (selection[HyprPresets.id(b)] === true) out.push(b)
        }))
        return out
    }

    // ticked presets whose combo is already used for something else
    readonly property int selectedTaken: {
        if (selectionCount === 0 || !model) return 0
        var n = 0
        HyprPresets.PACKS.forEach(p => p.binds.forEach(b => {
            if (selection[HyprPresets.id(b)] === true && HyprPresets.status(model, b).state === "taken") n++
        }))
        return n
    }

    function addSelected() {
        if (busy || selectionCount === 0) return
        if (selectedTaken > 0 && !presetAck) {
            presetAck = true
            say(selectedTaken + " of these combos are already used for something else · Add again to bind them anyway", true)
            return
        }
        var list = selectedPresets()
        commit(HyprBinds.addBinds(model, list.map(HyprPresets.fields)),
            "Added " + list.length + (list.length === 1 ? " bind" : " binds"))
    }

    // --- editor ----------------------------------------------------------

    // section: the file section it goes in; keys: a combo to start from
    function openAdd(slot, section, keys) {
        if (editSlot === slot) { closeEditor(); return }
        resetEditorState()
        editMode = "add"
        editSlot = slot
        editRow = null
        openRow = null
        editKeys = keys || ""
        editCmd = ""
        editDesc = ""
        editKind = "exec"
        editCategory = section !== "" ? section
            : model && model.categories.length ? model.categories[0].name : ""
        if (editKeys === "") { editFocus = ""; startCapture() }
        else editFocus = "cmd"
    }

    // a bind's row: editable ones open the editor, the rest what they run
    function openBind(row) {
        var slot = "row:" + row.callStart
        if (editSlot === slot) { closeEditor(); return }
        resetEditorState()
        editSlot = slot
        if (!row.editable) {
            editMode = ""
            editRow = null
            openRow = row
            return
        }
        openRow = null
        editMode = "edit"
        editRow = row
        editKeys = row.keys
        editKind = row.isExec ? "exec" : "lua"
        // a Lua action as the file has it, hl.dsp. and all
        editCmd = row.isExec ? row.command : row.cmdSrc
        editDesc = row.comment
        editCategory = row.category
        var o = HyprBinds.readOpts(row.optsSrc)
        editFlagsSimple = o.simple
        editFlags = o.flags
        editOptsSrc = row.optsSrc
        editFocus = "cmd"
    }

    // a preset, opened in the editor so the combo or command can be changed
    // before it is written
    function openPreset(item) {
        var slot = "preset:" + item.id
        if (editSlot === slot) { closeEditor(); return }
        var p = item.preset
        resetEditorState()
        editMode = "add"
        editSlot = slot
        editRow = null
        openRow = null
        editKind = p.lua ? "lua" : "exec"
        editKeys = p.keys
        editCmd = p.lua ? p.lua : p.cmd
        editDesc = p.desc
        editCategory = p.section
        var o = HyprBinds.readOpts(p.opts || "")
        editFlagsSimple = o.simple
        editFlags = o.flags
        editOptsSrc = p.opts || ""
        editFocus = "keys"
    }

    function resetEditorState() {
        capturing = false
        captureMods = ""
        conflictAck = ""
        editError = ""
        editFlags = ({})
        editFlagsSimple = true
        editOptsSrc = ""
    }

    function closeEditor() {
        editMode = ""
        editSlot = ""
        editRow = null
        openRow = null
        capturing = false
    }

    function toggleFlag(name) {
        var next = {}
        for (var k in editFlags) if (k !== name) next[k] = editFlags[k]
        if (editFlags[name] !== true) next[name] = true
        editFlags = next
        editError = ""
    }

    // the sections to offer: the config's, plus one a preset brought with it
    readonly property var editCategories: {
        var names = model ? model.categories.map(c => c.name) : []
        if (editCategory !== "" && names.indexOf(editCategory) < 0) names = names.concat([editCategory])
        return names
    }

    readonly property var conflicts: editMode === "" || !model ? []
        : HyprBinds.conflictsFor(model, editKeys, editRow ? editRow.callStart : -1)

    function save() {
        var keys = HyprBinds.tidyKeys(editKeys)
        var cmd = editCmdKept ? editRow.cmdSrc : editCmd.trim()
        var isMouse = editFlags["mouse"] === true
        if (keys.keyCount === 0) { editError = "The combo needs a key, not just modifiers"; return }
        if (keys.keyCount > 1 && !isMouse) { editError = "One key per combo — join them with + only after modifiers"; return }
        if (cmd === "") {
            editError = editKind === "lua" ? "The action can't be empty" : "The command can't be empty"
            return
        }
        if (editKind === "lua" && cmd.indexOf("(") < 0) {
            editError = "A Lua action is a call, like hl.dsp.window.close()"
            return
        }

        var norm = HyprBinds.normalizeKeys(keys.text)
        if (conflicts.length > 0 && conflictAck !== norm) {
            conflictAck = norm
            editError = ""
            return
        }

        var fields = {
            keys: keys.text, desc: editDesc, category: editCategory,
            kind: editKind, command: cmd, src: cmd,
            opts: editFlagsSimple ? HyprBinds.optsSource(editFlags) : editOptsSrc,
        }
        if (editMode === "add") {
            commit(HyprBinds.addBind(model, fields), "Added " + keys.text)
        } else {
            commit(HyprBinds.editBind(model, editRow, fields), "Updated " + keys.text)
        }
    }

    function remove() {
        commit(HyprBinds.removeBind(model, editRow), "Deleted " + editRow.keys)
    }

    // --- writing ---------------------------------------------------------

    function commit(newText, message) {
        if (busy) return
        luaFile.reload()
        if (luaFile.text() !== model.src) {
            reparse(true)
            say("hyprland.lua changed on disk since it was read; nothing written", true)
            return
        }
        if (newText === model.src) { closeEditor(); return }
        pendingMessage = message
        lastWritten = newText
        HyprLuaWrite.write(newText, root.written)
    }

    function undo() {
        if (busy) return
        luaFile.reload()
        if (luaFile.text() !== lastWritten) {
            lastWritten = ""
            say("hyprland.lua has changed since the last write; not undoing over it", true)
            return
        }
        pendingMessage = "Undone"
        lastWritten = ""
        HyprLuaWrite.undo(root.written)
    }

    // HyprLuaWrite's result for a write or undo started here
    function written(status, detail) {
        luaFile.reload()
        reparse(false)

        if (status === "syntax") {
            lastWritten = ""
            editError = HyprLuaWrite.syntaxMessage(detail)
            if (editMode === "") say(HyprLuaWrite.syntaxMessage(detail), true)
            return
        }
        if (status !== "ok") {
            lastWritten = ""
            say("Couldn't write hyprland.lua" + (detail ? ": " + detail.split("\n")[0] : ""), true)
            return
        }
        closeEditor()
        clearSelection()
        var complaint = HyprLuaWrite.reloadComplaint(detail)
        if (complaint !== "") say("Written, but Hyprland reports: " + complaint, true)
        else say(pendingMessage, false)
    }

    // --- key capture -----------------------------------------------------

    // the editor's sink takes the keys once it sees capturing go true
    function startCapture() {
        captureMods = ""
        capturing = true
    }

    function startFind() {
        closeEditor()
        captureMods = ""
        finding = true
        findSink.forceActiveFocus()
    }
    function stopFind() {
        finding = false
        search.forceFocus()
    }

    function modsText(mods) {
        var out = []
        if (mods & Qt.MetaModifier) out.push("SUPER")
        if (mods & Qt.ControlModifier) out.push("CTRL")
        if (mods & Qt.AltModifier) out.push("ALT")
        if (mods & Qt.ShiftModifier) out.push("SHIFT")
        return out.join(" + ")
    }

    // Qt key -> xkb keysym name, the spelling Hyprland takes. Shifted
    // symbols map back to their unshifted key, since SHIFT is already one of
    // the modifiers: SHIFT + 1 arrives as Key_Exclam.
    readonly property var keyNames: ({
        [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return", [Qt.Key_Space]: "space",
        [Qt.Key_Tab]: "Tab", [Qt.Key_Backtab]: "Tab", [Qt.Key_Escape]: "Escape",
        [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete", [Qt.Key_Insert]: "Insert",
        [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Page_Up", [Qt.Key_PageDown]: "Page_Down",
        [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down",
        [Qt.Key_Print]: "Print", [Qt.Key_Pause]: "Pause",
        [Qt.Key_Equal]: "equal", [Qt.Key_Plus]: "equal", [Qt.Key_Minus]: "minus", [Qt.Key_Underscore]: "minus",
        [Qt.Key_Comma]: "comma", [Qt.Key_Less]: "comma", [Qt.Key_Period]: "period", [Qt.Key_Greater]: "period",
        [Qt.Key_Slash]: "slash", [Qt.Key_Question]: "slash", [Qt.Key_Backslash]: "backslash", [Qt.Key_Bar]: "backslash",
        [Qt.Key_Semicolon]: "semicolon", [Qt.Key_Colon]: "semicolon",
        [Qt.Key_Apostrophe]: "apostrophe", [Qt.Key_QuoteDbl]: "apostrophe",
        [Qt.Key_BracketLeft]: "bracketleft", [Qt.Key_BraceLeft]: "bracketleft",
        [Qt.Key_BracketRight]: "bracketright", [Qt.Key_BraceRight]: "bracketright",
        [Qt.Key_QuoteLeft]: "grave", [Qt.Key_AsciiTilde]: "grave",
        [Qt.Key_Exclam]: "1", [Qt.Key_At]: "2", [Qt.Key_NumberSign]: "3", [Qt.Key_Dollar]: "4",
        [Qt.Key_Percent]: "5", [Qt.Key_AsciiCircum]: "6", [Qt.Key_Ampersand]: "7",
        [Qt.Key_Asterisk]: "8", [Qt.Key_ParenLeft]: "9", [Qt.Key_ParenRight]: "0",
        [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume", [Qt.Key_VolumeDown]: "XF86AudioLowerVolume",
        [Qt.Key_VolumeMute]: "XF86AudioMute", [Qt.Key_MicMute]: "XF86AudioMicMute",
        [Qt.Key_MonBrightnessUp]: "XF86MonBrightnessUp", [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown",
        [Qt.Key_MediaPlay]: "XF86AudioPlay", [Qt.Key_MediaTogglePlayPause]: "XF86AudioPlay",
        [Qt.Key_MediaPause]: "XF86AudioPause", [Qt.Key_MediaStop]: "XF86AudioStop",
        [Qt.Key_MediaNext]: "XF86AudioNext", [Qt.Key_MediaPrevious]: "XF86AudioPrev",
    })

    function keyName(key) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key)
        if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key)
        if (key >= Qt.Key_F1 && key <= Qt.Key_F35) return "F" + (key - Qt.Key_F1 + 1)
        return keyNames[key] || ""
    }

    readonly property var modifierKeys: [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta,
        Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr, Qt.Key_Hyper_L, Qt.Key_Hyper_R]

    // --- pieces ----------------------------------------------------------

    component Label: Text {
        color: Theme.text
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontBody
        elide: Text.ElideRight
    }

    // the editor's label column, narrower than a page's: its controls are
    // text fields that want the room
    readonly property int editLabelWidth: Theme.fit(170)
    // the keycaps column, in both lists
    readonly property int keysWidth: Theme.fit(150)

    // A pack heading: the name, the rule, what the pack is for, and the one
    // chip that ticks or unticks the lot.
    component PackHeading: Item {
        id: head
        property string text: ""
        property string note: ""
        property string allText: "All"
        signal allClicked()

        width: parent ? parent.width : 0
        height: Theme.rowHeightTall

        Label {
            id: headingLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.heading(head.text)
            color: Theme.headingColor
            font.pixelSize: Theme.fontSmall
            font.weight: Theme.headingBold ? Theme.weightStrong : Theme.weightBody
            font.letterSpacing: Theme.headingSpacing
        }

        Rectangle {
            visible: Theme.headingRule
            anchors.left: headingLabel.right
            anchors.leftMargin: Theme.spaceL
            anchors.right: noteLabel.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.borderWidth
            color: Theme.stroke
        }

        Label {
            id: noteLabel
            anchors.right: allChip.left
            anchors.rightMargin: Theme.spaceM
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
            text: head.note
        }

        FlyoutChip {
            id: allChip
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: head.allText
            onClicked: head.allClicked()
        }
    }

    // The editor, built in the slot of whatever opened it. Its fields hold
    // root's edit* values, so it can be rebuilt (a re-sorted list) without
    // losing what was typed.
    component BindEditor: SettingsIndent {
        id: ed

        // combo: typed, or recorded from the keyboard
        SettingsField {
            labelWidth: root.editLabelWidth
            label: "Keys"
            hint: root.capturing ? "Escape to type it instead" : ""
            searchable: false

            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                height: Theme.rowHeightTall

                FlyoutInput {
                    id: keysInput
                    anchors.left: parent.left
                    anchors.right: recordChip.left
                    anchors.rightMargin: Theme.spaceM
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.capturing
                    echoPassword: false
                    placeholder: "SUPER + SHIFT + T"
                    text: root.editKeys
                    onTextChanged: { root.editKeys = text; root.editError = "" }
                    onAccepted: cmdInput.forceFocus()
                    onEscapePressed: root.closeEditor()
                }

                // stands in for the field while recording
                Rectangle {
                    anchors.fill: keysInput
                    visible: root.capturing
                    radius: Theme.radiusInner
                    color: Theme.base
                    border.width: Theme.borderWidth
                    border.color: Theme.strokeFocus

                    Label {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spaceL
                        verticalAlignment: Text.AlignVCenter
                        color: root.captureMods !== "" ? Theme.textStrong : Theme.subtext
                        text: root.captureMods !== "" ? root.captureMods + " + …" : "Press a combination"
                    }
                }

                Item {
                    id: captureSink
                    Keys.onPressed: event => {
                        event.accepted = true
                        var mods = event.modifiers
                        if (root.modifierKeys.indexOf(event.key) >= 0) {
                            root.captureMods = root.modsText(mods)
                            return
                        }
                        if (event.key === Qt.Key_Escape && !(mods & ~Qt.KeypadModifier)) {
                            root.capturing = false
                            keysInput.forceFocus()
                            return
                        }
                        var name = root.keyName(event.key)
                        if (name === "") return
                        var m = root.modsText(mods)
                        root.editKeys = m !== "" ? m + " + " + name : name
                        root.capturing = false
                        if (cmdInput.visible) cmdInput.forceFocus()
                        else descInput.forceFocus()
                    }
                    Keys.onReleased: event => {
                        event.accepted = true
                        if (root.capturing) root.captureMods = root.modsText(event.modifiers)
                    }
                }

                Connections {
                    target: root
                    function onCapturingChanged() { if (root.capturing) captureSink.forceActiveFocus() }
                }

                FlyoutChip {
                    id: recordChip
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.capturing ? "Stop" : "Record"
                    selected: root.capturing
                    onClicked: {
                        if (root.capturing) { root.capturing = false; keysInput.forceFocus() }
                        else root.startCapture()
                    }
                }
            }
        }

        // what it does: a shell command, or a Lua action (a dispatcher, a
        // function from the config); one spread over lines is kept as written
        SettingsField {
            labelWidth: root.editLabelWidth
            label: "Does"
            hint: root.editCmdKept ? "Kept as written" : ""
            searchable: false

            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.editCmdKept ? keptText.implicitHeight : Theme.rowHeightTall

                Label {
                    id: keptText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    visible: root.editCmdKept
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    maximumLineCount: 4
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall
                    text: root.editRow ? root.editRow.cmdSrc : ""
                }

                FlyoutInput {
                    id: cmdInput
                    anchors.left: parent.left
                    anchors.right: kindPick.left
                    anchors.rightMargin: Theme.spaceM
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.editCmdKept
                    echoPassword: false
                    placeholder: root.editKind === "lua" ? "hl.dsp.window.close()" : "alacritty -e btop"
                    text: root.editCmd
                    onTextChanged: { root.editCmd = text; root.editError = "" }
                    onAccepted: descInput.forceFocus()
                    onEscapePressed: root.closeEditor()
                }

                // a shell command run through hl.dsp.exec_cmd(), or Lua
                FlyoutSegmented {
                    id: kindPick
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.editCmdKept
                    fill: false
                    model: [{ value: "exec", text: "Command" }, { value: "lua", text: "Lua" }]
                    current: root.editKind
                    onPicked: v => { root.editKind = v; root.editError = "" }
                }
            }
        }

        SettingsField {
            labelWidth: root.editLabelWidth
            label: "Description"
            searchable: false

            FlyoutInput {
                id: descInput
                anchors.left: parent.left
                anchors.right: parent.right
                echoPassword: false
                // what the list shows when there's no comment
                placeholder: (root.editRow ? root.editRow.autoDesc : "What it does") + " · saved as a comment"
                text: root.editDesc
                onTextChanged: root.editDesc = text
                onAccepted: root.save()
                onEscapePressed: root.closeEditor()
            }
        }

        // hl.bind's options, as toggles -- unless the call's table holds
        // something these chips can't say, in which case it's left alone
        SettingsField {
            labelWidth: root.editLabelWidth
            label: "Options"
            hint: root.editFlagsSimple ? "" : "Kept as written"
            searchable: false

            Flow {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Theme.spaceS
                visible: root.editFlagsSimple

                Repeater {
                    model: root.flagOrder
                    FlyoutChip {
                        required property var modelData
                        text: root.flagLabels[modelData] || modelData
                        selected: root.editFlags[modelData] === true
                        onClicked: root.toggleFlag(modelData)
                    }
                }
            }

            Label {
                anchors.left: parent.left
                anchors.right: parent.right
                visible: !root.editFlagsSimple
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                text: root.editOptsSrc
            }
        }

        SettingsField {
            labelWidth: root.editLabelWidth
            label: "Section"
            searchable: false

            SettingsDropdown {
                anchors.left: parent.left
                width: Theme.fit(260)
                model: root.editCategories
                current: root.editCategory
                onPicked: v => root.editCategory = v
            }
        }

        // conflict warning, validation, luac's complaint
        Label {
            width: parent.width
            visible: text !== ""
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            color: Theme.alert
            font.pixelSize: Theme.fontSmall
            text: {
                if (root.editError !== "") return root.editError
                if (root.conflicts.length === 0) return ""
                var c = root.conflicts[0]
                return HyprBinds.normalizeKeys(root.editKeys) + " is already bound: " + c.desc
                    + " (line " + c.line + ")"
                    + (root.conflicts.length > 1 ? " and " + (root.conflicts.length - 1) + " more" : "")
                    + (root.conflictAck !== "" ? " · Save again to bind it anyway" : "")
            }
        }

        Item {
            width: parent.width
            height: Theme.rowHeightTall

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceM

                FlyoutChip {
                    visible: root.editMode === "edit"
                    text: "Delete"
                    confirmText: "Delete this bind?"
                    enabled: !root.busy
                    onClicked: root.remove()
                }
                FlyoutChip { text: "Cancel"; onClicked: root.closeEditor() }
                FlyoutChip {
                    text: root.conflicts.length > 0
                        && root.conflictAck === HyprBinds.normalizeKeys(root.editKeys)
                        ? "Save anyway" : root.editMode === "add" ? "Add" : "Save"
                    enabled: !root.busy
                    selected: true
                    onClicked: root.save()
                }
            }
        }

        Component.onCompleted: Qt.callLater(() => {
            if (root.capturing) captureSink.forceActiveFocus()
            else if (root.editFocus === "keys") keysInput.forceFocus()
            else if (root.editFocus === "cmd" && cmdInput.visible) cmdInput.forceFocus()
            else descInput.forceFocus()
        })
    }

    // what a bind that can't be edited here runs, and why not
    component BindReadout: SettingsIndent {
        id: ro
        // set by the Loader's component; undefined for the moment between
        // the readout being built and the row arriving, or the row going
        property var row: null

        SettingsField {
            labelWidth: root.editLabelWidth
            label: "Does"
            hint: ro.row ? ro.row.reason : ""
            searchable: false

            Label {
                anchors.left: parent.left
                anchors.right: parent.right
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                maximumLineCount: 4
                color: Theme.text
                font.pixelSize: Theme.fontSmall
                text: ro.row ? ro.row.cmdSrc : ""
            }
        }
        Item {
            width: parent.width
            height: Theme.rowHeightTall

            FlyoutChip {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Open at line " + (ro.row ? ro.row.line : "")
                icon: "󰏌"
                onClicked: if (ro.row) root.openConf(ro.row.line)
            }
        }
    }

    // "Add a bind…": the last row of a group, or of an empty lookup
    component AddRow: Column {
        id: add
        property string slot: ""
        property string section: ""
        property string keys: ""
        property string label: "Add a bind…"
        width: parent ? parent.width : 0

        FlyoutRow {
            leadingIcon: "󰐕"
            label: add.label
            highlighted: root.editSlot === add.slot
            trailing: root.editSlot === add.slot ? "󰅀" : "󰅂"
            enabled: root.model !== null && !root.busy
            onActivated: root.openAdd(add.slot, add.section, add.keys)
        }
        Loader {
            width: parent.width
            active: root.editSlot === add.slot
            visible: active
            sourceComponent: Component { BindEditor {} }
        }
    }

    // --- layout ----------------------------------------------------------

    function focusSearch() { search.forceFocus() }

    // search, or the combo being pressed, with Press keys beside it
    Item {
        width: parent.width
        height: Theme.rowHeightTall + Theme.spaceM

        FlyoutInput {
            id: search
            anchors.left: parent.left
            anchors.right: findChip.left
            anchors.rightMargin: Theme.spaceM
            height: parent.height
            visible: !root.finding
            glyph: "/"
            placeholder: "Search keys, descriptions, commands"
            echoPassword: false
            onTextChanged: root.query = text
            onEscapePressed: {
                if (text !== "") text = ""
                else if (root.findKeys !== "") root.findKeys = ""
                else if (root.selectionCount > 0) root.clearSelection()
            }
        }

        Rectangle {
            anchors.fill: search
            visible: root.finding
            radius: Theme.radiusInner
            color: Theme.base
            border.width: Theme.borderWidth
            border.color: Theme.strokeFocus

            Label {
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceL
                verticalAlignment: Text.AlignVCenter
                color: root.captureMods !== "" ? Theme.textStrong : Theme.subtext
                text: root.captureMods !== "" ? root.captureMods + " + …" : "Press the keys to look up · Escape to stop"
            }

            Item {
                id: findSink
                Keys.onPressed: event => {
                    event.accepted = true
                    var mods = event.modifiers
                    if (root.modifierKeys.indexOf(event.key) >= 0) {
                        root.captureMods = root.modsText(mods)
                        return
                    }
                    if (event.key === Qt.Key_Escape && !(mods & ~Qt.KeypadModifier)) {
                        root.stopFind()
                        return
                    }
                    var name = root.keyName(event.key)
                    if (name === "") return
                    var m = root.modsText(mods)
                    search.text = ""
                    root.findKeys = m !== "" ? m + " + " + name : name
                    root.stopFind()
                }
                Keys.onReleased: event => {
                    event.accepted = true
                    if (root.finding) root.captureMods = root.modsText(event.modifiers)
                }
            }
        }

        FlyoutChip {
            id: findChip
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.finding ? "Stop" : "Press keys"
            icon: "󰌌"
            selected: root.finding
            onClicked: root.finding ? root.stopFind() : root.startFind()
        }
    }

    // the combo being looked up, while there is one
    Item {
        visible: root.findKeys !== ""
        width: parent.width
        height: visible ? Theme.rowHeightTall : 0

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceM

            Label {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                text: root.groups.length > 0 ? "The bind on" : "Nothing uses"
            }
            Keycaps { anchors.verticalCenter: parent.verticalCenter; keys: root.findKeys }
            FlyoutChip {
                anchors.verticalCenter: parent.verticalCenter
                text: "Show all"
                onClicked: root.findKeys = ""
            }
        }
    }

    // counts, Undo, and the file all of this is about: the path is a link,
    // and while a bind is open it opens on that bind's line
    Item {
        width: parent.width
        height: Theme.headingHeight

        Label {
            anchors.left: parent.left
            anchors.right: undoChip.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Theme.fontSmall
            color: Theme.subtext
            text: root.busy ? "Writing…"
                : !root.model ? ""
                : root.model.rows.length + " binds · " + root.editableCount + " editable here"
                    + (root.editableCount < root.model.rows.length ? ", the rest open in the file" : "")
        }

        FlyoutChip {
            id: undoChip
            anchors.right: confLink.left
            anchors.rightMargin: root.lastWritten !== "" ? Theme.spaceL : 0
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? implicitWidth : 0
            text: "Undo"
            visible: root.lastWritten !== ""
            enabled: !root.busy
            onClicked: root.undo()
        }

        Label {
            id: confLink
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Theme.fontSmall
            font.underline: linkMouse.containsMouse
            color: linkMouse.containsMouse ? Theme.textStrong : Theme.muted
            text: root.shortConfPath + (root.linkLine > 0 ? ":" + root.linkLine : "")

            MouseArea {
                id: linkMouse
                anchors.fill: parent
                anchors.margins: -Theme.spaceS
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openConf(root.linkLine)
            }
        }
    }

    // ---- the list: your binds, then the suggestions ----
    Item {
        width: parent.width
        height: root.bodyHeight
            - (root.findKeys !== "" ? Theme.rowHeightTall + Theme.spaceM : 0)
            - (selectionBar.visible ? selectionBar.height + Theme.spaceM : 0)

        Flickable {
            id: list
            anchors.fill: parent
            // room for the rows' hover fill, which bleeds past the column
            anchors.leftMargin: -Theme.spaceS
            anchors.rightMargin: -Theme.spaceS
            contentHeight: listCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: listCol
                x: Theme.spaceS
                width: list.width - Theme.spaceS * 2
                spacing: Theme.spaceXs

                Repeater {
                    model: root.groups

                    Column {
                        id: group
                        required property var modelData
                        width: listCol.width
                        spacing: Theme.spaceXs

                        Item { width: 1; height: Theme.spaceS }
                        FlyoutHeading { text: group.modelData.name.toUpperCase() + "  " + group.modelData.rows.length }

                        Repeater {
                            model: group.modelData.rows

                            Column {
                                id: row
                                required property var modelData
                                readonly property string slot: "row:" + modelData.callStart
                                readonly property bool open: root.editSlot === slot
                                width: group.width

                                // keycaps, the description, then the command in
                                // what's left of the line
                                Item {
                                    width: parent.width
                                    height: Theme.rowHeight + Theme.spaceXs

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: -Theme.spaceS
                                        anchors.rightMargin: -Theme.spaceS
                                        radius: Theme.radiusInner
                                        color: rowMouse.containsMouse ? Theme.hoverFill : "transparent"
                                    }
                                    // the open one's tick, as in every list that opens in place
                                    Rectangle {
                                        visible: row.open
                                        anchors.left: parent.left
                                        anchors.leftMargin: -Theme.spaceS
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Theme.indicatorWidth
                                        height: parent.height - 6
                                        radius: width / 2
                                        color: Theme.accent
                                    }

                                    Item {
                                        id: keysCell
                                        anchors.left: parent.left
                                        anchors.leftMargin: row.open ? Theme.spaceM : 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: root.keysWidth
                                        height: caps.height
                                        clip: true

                                        Keycaps {
                                            id: caps
                                            keys: row.modelData.keys
                                            alert: row.modelData.conflict === true
                                        }
                                    }

                                    Label {
                                        id: descText
                                        anchors.left: keysCell.right
                                        anchors.leftMargin: Theme.spaceL
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, (endCell.x - x) * 0.6)
                                        text: row.modelData.desc
                                        color: row.open || rowMouse.containsMouse ? Theme.textStrong : Theme.text
                                    }
                                    Label {
                                        anchors.left: descText.right
                                        anchors.leftMargin: Theme.spaceM
                                        anchors.right: endCell.left
                                        anchors.rightMargin: Theme.spaceM
                                        anchors.baseline: descText.baseline
                                        text: row.modelData.command
                                        color: Theme.subtext
                                        font.pixelSize: Theme.fontCaption
                                    }

                                    // a lock on the ones that can't be edited
                                    // here; on hover, a pencil or their line
                                    Label {
                                        id: endCell
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.max(Theme.fs(18), implicitWidth)
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideNone
                                        readonly property bool hot: rowMouse.containsMouse || row.open
                                        text: row.modelData.editable ? (hot ? "󰏫" : "")
                                            : hot ? "line " + row.modelData.line + " 󰏌" : "󰌾"
                                        color: hot ? Theme.textStrong : Theme.muted
                                        font.family: row.modelData.editable || !hot ? Theme.fontIcon : Theme.fontText
                                        font.pixelSize: row.modelData.editable || !hot ? Theme.fontIconSize : Theme.fontSmall
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (!root.busy) root.openBind(row.modelData)
                                    }
                                }

                                Loader {
                                    width: parent.width
                                    active: row.open
                                    visible: active
                                    sourceComponent: row.modelData.editable ? editorComp : readoutComp
                                    Component { id: editorComp; BindEditor {} }
                                    Component { id: readoutComp; BindReadout { row: row.modelData } }
                                }
                            }
                        }

                        AddRow {
                            slot: "add:" + group.modelData.name
                            section: group.modelData.section
                        }
                    }
                }

                // nothing found
                Label {
                    visible: root.model !== null && root.groups.length === 0 && root.findKeys === ""
                    width: parent.width
                    topPadding: Theme.spaceXl
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.subtext
                    text: root.query !== "" ? "No binds match \"" + root.query + "\"" : "No hl.bind() calls found"
                }
                // a combo nothing uses: offer it
                AddRow {
                    visible: root.model !== null && root.groups.length === 0 && root.findKeys !== ""
                    slot: "find"
                    keys: root.findKeys
                    label: "Add a bind on " + root.findKeys + "…"
                }

                // ---- suggestions ----
                Item { width: 1; height: Theme.spaceL }
                PackHeading {
                    text: "SUGGESTED"
                    note: root.presetBound + " of " + root.presetTotal + " already added"
                    allText: root.hideBound ? "Show added" : "Hide added"
                    onAllClicked: root.hideBound = !root.hideBound
                }
                Label {
                    width: parent.width
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall
                    text: "Binds worth having: tick the ones you want, or 󰏫 to change one first"
                }

                // which pack to show, or all of them
                Flow {
                    width: parent.width
                    spacing: Theme.spaceS
                    topPadding: Theme.spaceS
                    bottomPadding: Theme.spaceS

                    FlyoutChip {
                        text: "All"
                        selected: root.packFilter === ""
                        onClicked: root.packFilter = ""
                    }
                    Repeater {
                        model: root.packNames
                        FlyoutChip {
                            required property var modelData
                            text: modelData
                            selected: root.packFilter === modelData
                            onClicked: root.packFilter = root.packFilter === modelData ? "" : modelData
                        }
                    }
                }

                Repeater {
                    model: root.presetGroups

                    Column {
                        id: pack
                        required property var modelData
                        width: listCol.width
                        spacing: Theme.spaceXs

                        Item { width: 1; height: Theme.spaceS }

                        PackHeading {
                            text: pack.modelData.name.toUpperCase()
                            note: pack.modelData.note
                            allText: root.packFullySelected(pack.modelData) ? "None" : "All"
                            onAllClicked: root.selectPack(pack.modelData, !root.packFullySelected(pack.modelData))
                        }

                        Repeater {
                            model: pack.modelData.items

                            Column {
                                id: pItem
                                required property var modelData
                                readonly property bool open: root.editSlot === "preset:" + modelData.id
                                width: pack.width

                            Item {
                                id: pRow
                                readonly property var modelData: pItem.modelData
                                readonly property bool ticked: root.selection[modelData.id] === true
                                readonly property bool done: modelData.state === "bound"
                                readonly property bool unavailable: modelData.missing.length > 0

                                width: pack.width
                                height: Theme.rowHeight + Theme.spaceXs

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.leftMargin: -Theme.spaceS
                                    anchors.rightMargin: -Theme.spaceS
                                    radius: Theme.radiusInner
                                    color: pRow.ticked ? Theme.selectedFill
                                        : pMouse.containsMouse ? Theme.hoverFill : "transparent"
                                    border.width: pRow.ticked ? Theme.borderWidth : 0
                                    border.color: Theme.selectedStroke
                                }

                                // first, so the pencil's own area below sits
                                // above it and gets the click
                                MouseArea {
                                    id: pMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.busy) return
                                        root.toggleSelect(pRow.modelData)
                                    }
                                }

                                // tick box, or a check for what's already there
                                Text {
                                    id: mark
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.fs(20)
                                    horizontalAlignment: Text.AlignHCenter
                                    text: pRow.done ? "󰄬" : pRow.ticked ? "󰄲" : "󰄱"
                                    color: pRow.done ? Theme.good
                                        : pRow.ticked ? Theme.textStrong : Theme.muted
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontIconSize
                                }

                                Item {
                                    id: pKeys
                                    anchors.left: mark.right
                                    anchors.leftMargin: Theme.spaceM
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: root.keysWidth - mark.width - Theme.spaceM
                                    height: pCaps.height
                                    clip: true

                                    Keycaps {
                                        id: pCaps
                                        keys: pRow.modelData.keys
                                        dim: pRow.done
                                        alert: pRow.modelData.state === "taken"
                                    }
                                }

                                Label {
                                    id: pDesc
                                    anchors.left: pKeys.right
                                    anchors.leftMargin: Theme.spaceL
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, (pState.x - x) * 0.6)
                                    text: pRow.modelData.desc
                                    color: pRow.unavailable ? Theme.textDisabled : Theme.text
                                }
                                Label {
                                    anchors.left: pDesc.right
                                    anchors.leftMargin: Theme.spaceM
                                    anchors.right: pState.left
                                    anchors.rightMargin: Theme.spaceM
                                    anchors.baseline: pDesc.baseline
                                    text: pRow.modelData.action
                                    color: Theme.subtext
                                    font.pixelSize: Theme.fontCaption
                                }

                                // what the config already says about it
                                Label {
                                    id: pState
                                    anchors.right: pEdit.left
                                    anchors.rightMargin: Theme.sp(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    // capped, so a long "taken by" doesn't
                                    // squeeze the rest out of the line
                                    width: Math.min(implicitWidth, Theme.fs(200))
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: Theme.fontSmall
                                    color: pRow.unavailable || pRow.modelData.state === "taken"
                                        ? Theme.alert : Theme.subtext
                                    text: pRow.unavailable ? "needs " + pRow.modelData.missing.join(", ")
                                        : pRow.modelData.state === "bound" ? "added"
                                        : pRow.modelData.state === "taken"
                                            ? "taken: " + pRow.modelData.other.desc.toLowerCase()
                                        : pRow.modelData.state === "elsewhere"
                                            ? "already on " + pRow.modelData.other.keys
                                        // the ordinary case, only while pointed at
                                        : pMouse.containsMouse || editMouse.containsMouse
                                            ? "goes in " + pRow.modelData.section : ""
                                }

                                // open it in the editor instead of ticking it
                                Text {
                                    id: pEdit
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.fs(18)
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "󰏫"
                                    visible: !pRow.done && (pMouse.containsMouse || editMouse.containsMouse || pItem.open)
                                    color: editMouse.containsMouse || pItem.open ? Theme.textStrong : Theme.subtext
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontIconSize

                                    MouseArea {
                                        id: editMouse
                                        anchors.fill: parent
                                        anchors.margins: -Theme.spaceS
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (!root.busy) root.openPreset(pRow.modelData)
                                    }
                                }
                            }

                            Loader {
                                width: parent.width
                                active: pItem.open
                                visible: active
                                sourceComponent: Component { BindEditor {} }
                            }
                            }
                        }
                    }
                }

                Label {
                    visible: root.model !== null && root.presetGroups.length === 0
                    width: parent.width
                    topPadding: Theme.spaceM
                    bottomPadding: Theme.spaceXl
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.subtext
                    text: root.query !== "" || root.findKeys !== "" ? "No presets match"
                        : root.hideBound ? "Every preset here is already in your config · Show added to see them"
                        : "No presets"
                }
            }
        }

        // scroll indicator, out in the page's gutter where every other
        // page keeps its own
        ScrollBar {
            anchors.right: parent.right
            anchors.rightMargin: -(Theme.scrollGutter + Theme.spaceS)
            flickable: list
        }
    }

    // ---- what's ticked, and the one button that writes it ----
    Rectangle {
        id: selectionBar
        visible: root.selectionCount > 0
        width: parent.width
        height: visible ? Theme.rowHeightTall + Theme.panelPad * 2 : 0
        radius: Theme.radiusInner
        color: Theme.fieldFill
        border.width: Theme.borderWidth
        border.color: root.selectedTaken > 0 ? Theme.alert : Theme.stroke

        Label {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceXl
            anchors.right: selectionActions.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.textStrong
            text: root.selectionCount + (root.selectionCount === 1 ? " preset ticked" : " presets ticked")
                + (root.selectedTaken > 0
                    ? " · " + root.selectedTaken + " on combos something else uses"
                    : " · written into their sections, one write")
        }

        Row {
            id: selectionActions
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceXl
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceM

            FlyoutChip { text: "Clear"; onClicked: root.clearSelection() }
            FlyoutChip {
                text: (root.selectedTaken > 0 && root.presetAck ? "Add anyway · " : "Add ") + root.selectionCount
                selected: true
                enabled: !root.busy && root.model !== null
                onClicked: root.addSelected()
            }
        }
    }
}
