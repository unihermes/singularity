// Singularity - Quickshell
// ~/.config/quickshell/windows/KeybindsBody.qml
//
// The Keybinds editor. Two tabs over one list area, so the window is the
// same height whichever is showing:
//
//   Binds    every hl.bind() in hyprland.lua, grouped by the config's
//            `-- --- Section ---` markers, searchable, with add / edit /
//            delete for the binds simple enough to rewrite safely
//   Presets  a catalogue of binds worth having (HyprPresets.js), each shown
//            against what the config already has: tick the ones you want and
//            they are written in one go, or open one in the editor first and
//            change the combo before it lands
//
// Parsing and rewriting live in HyprBinds.js, the safe write in
// HyprLuaWrite.qml, the catalogue in HyprPresets.js. Nothing here builds Lua
// by hand.
//
// Hosted twice: by Keybinds.qml as its own window, and by the Settings
// window's Keybinds page. Anything that used to hang off the window's
// visibility hangs off `active` instead.
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

    // true while whatever hosts this is on screen: the standalone window's
    // visible, or the Settings page existing at all
    property bool active: false
    // Escape in an empty search closes the host only when the host is the
    // Keybinds window; inside Settings it would take the whole window with it
    property bool standalone: true
    signal closeRequested()

    readonly property string confPath: HyprLuaWrite.confPath
    readonly property string home: Quickshell.env("HOME")
    // "~/.config/hypr/hyprland.lua" reads better than the absolute path
    readonly property string shortConfPath: confPath.indexOf(home) === 0
        ? "~" + confPath.slice(home.length) : confPath

    // the line the link and the toolbar chip would open: the bind in the
    // editor, or the one a notice is about
    readonly property int linkLine: editRow ? editRow.line : noticeLine

    // The config itself, straight from here. With a line it goes to the
    // editor at that line; without one it goes through open-file.sh, which
    // honours whatever this machine actually opens .lua with (LinkRow.qml
    // and the launcher's file search use the same script).
    function openConf(line) {
        if (line > 0) Quickshell.execDetached(["alacritty", "-e", "nvim", "+" + line, confPath])
        else Quickshell.execDetached([home + "/.config/quickshell/scripts/open-file.sh", confPath])
    }

    // total height of the list, editor and preset bar together, so opening
    // any of them shrinks the list instead of resizing (and re-centring) the
    // window
    property int bodyHeight: Theme.fs(520)

    property var model: null
    property string query: ""
    property string notice: ""
    property bool noticeIsError: false
    readonly property bool busy: HyprLuaWrite.busy
    // what the last write put on disk; undo only runs while the file still says it
    property string lastWritten: ""
    property string pendingMessage: ""

    // "binds" | "presets"
    property string tab: "binds"

    // editor
    property string editMode: ""     // "" | "add" | "edit"
    property var editRow: null
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
    // the combo a conflict warning was shown for; saving it again goes ahead
    property string conflictAck: ""
    property bool deleteArmed: false
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

    // the line the notice is about, so the path link can jump to it
    property int noticeLine: 0

    function say(msg, isError) {
        notice = msg
        noticeIsError = isError
        noticeLine = 0
    }

    function reparse(fromDisk) {
        var text = luaFile.text()
        if (model && text === model.src) return
        model = HyprBinds.parse(text)
        if (fromDisk && editMode !== "") {
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
            if (root.active && !root.busy) root.reparse(true)
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

    onActiveChanged: activate()
    Component.onCompleted: if (active) activate()

    // load fresh on show, drop the editor, selection and search on hide
    function activate() {
        if (active) {
            luaFile.reload()
            model = null
            reparse(false)
            if (luaFile.text() === "") say("Couldn't read " + confPath, true)
            haveProc.running = true
            search.forceFocus()
        } else {
            closeEditor()
            clearSelection()
            search.text = ""
            notice = ""
            tab = "binds"
            packFilter = ""
        }
    }

    function showTab(name) {
        if (tab === name) return
        tab = name
        notice = ""
        closeEditor()
        search.forceFocus()
    }

    // --- grouping: the config's own binds --------------------------------

    readonly property var groups: {
        if (!model || tab !== "binds") return []
        var q = query.trim().toLowerCase()
        var names = model.categories.map(c => c.name)
        var byName = {}
        var out = []
        for (var i = 0; i < model.rows.length; i++) {
            var r = model.rows[i]
            var cat = r.category !== "" ? r.category : "Other"
            if (q !== "" && (r.keys + "\n" + r.desc + "\n" + r.command + "\n" + cat).toLowerCase().indexOf(q) < 0)
                continue
            if (!byName[cat]) byName[cat] = []
            byName[cat].push(r)
        }
        names.concat(["Other"]).forEach(n => {
            if (byName[n]) out.push({ name: n, rows: byName[n] })
        })
        return out
    }

    readonly property int editableCount: model ? model.rows.filter(r => r.editable).length : 0

    // --- grouping: the catalogue -----------------------------------------

    readonly property var packNames: HyprPresets.PACKS.map(p => p.name)

    // Every preset, wrapped with what the config says about it and whether
    // the tools it needs are installed.
    readonly property var presetGroups: {
        if (tab !== "presets") return []
        var q = query.trim().toLowerCase()
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

    function isSelected(id) { return selection[id] === true }

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
        notice = ""
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

    function openAdd() {
        editMode = "add"
        editRow = null
        keysInput.text = ""
        cmdInput.text = ""
        descInput.text = ""
        editKind = "exec"
        editCategory = model && model.categories.length ? model.categories[0].name : ""
        resetEditorState()
        startCapture()
    }

    function openEdit(row) {
        editMode = "edit"
        editRow = row
        keysInput.text = row.keys
        cmdInput.text = row.command
        descInput.text = row.comment
        editKind = row.isExec ? "exec" : "lua"
        editCategory = row.category
        resetEditorState()
        var o = HyprBinds.readOpts(row.optsSrc)
        editFlagsSimple = o.simple
        editFlags = o.flags
        editOptsSrc = row.optsSrc
        cmdInput.forceFocus()
    }

    // a preset, opened in the editor so the combo or command can be changed
    // before it is written
    function openPreset(item) {
        var p = item.preset
        editMode = "add"
        editRow = null
        editKind = p.lua ? "lua" : "exec"
        keysInput.text = p.keys
        cmdInput.text = p.lua ? p.lua : p.cmd
        descInput.text = p.desc
        editCategory = p.section
        resetEditorState()
        var o = HyprBinds.readOpts(p.opts || "")
        editFlagsSimple = o.simple
        editFlags = o.flags
        editOptsSrc = p.opts || ""
        keysInput.forceFocus()
    }

    function resetEditorState() {
        capturing = false
        captureMods = ""
        conflictAck = ""
        deleteArmed = false
        editError = ""
        notice = ""
        editFlags = ({})
        editFlagsSimple = true
        editOptsSrc = ""
    }

    function closeEditor() {
        editMode = ""
        editRow = null
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
        : HyprBinds.conflictsFor(model, keysInput.text, editRow ? editRow.callStart : -1)

    function save() {
        var keys = HyprBinds.tidyKeys(keysInput.text)
        var cmd = cmdInput.text.trim()
        var isMouse = editFlags["mouse"] === true
        if (keys.keyCount === 0) { editError = "The combo needs a key, not just modifiers"; return }
        if (keys.keyCount > 1 && !isMouse) { editError = "One key per combo -- join them with + only after modifiers"; return }
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
            keys: keys.text, desc: descInput.text, category: editCategory,
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
        if (!deleteArmed) { deleteArmed = true; return }
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

    function startCapture() {
        capturing = true
        captureMods = ""
        captureSink.forceActiveFocus()
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
        font.pixelSize: Theme.fontBody
        elide: Text.ElideRight
    }

    component FieldLabel: Label {
        width: Theme.fs(90)
        height: Theme.rowHeightTall
        verticalAlignment: Text.AlignVCenter
        color: Theme.subtext
    }

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
            font.bold: Theme.headingBold
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

    // --- layout ----------------------------------------------------------

    // toolbar: tabs, search, then actions -- one row, on both tabs, so the
    // list below is the same height either way
    Item {
        width: parent.width
        height: Theme.rowHeightTall

        Row {
            id: tabs
            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceS
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceS

            FlyoutChip {
                text: "Binds"
                selected: root.tab === "binds"
                onClicked: root.showTab("binds")
            }
            FlyoutChip {
                text: root.selectionCount > 0 ? "Presets · " + root.selectionCount : "Presets"
                selected: root.tab === "presets"
                onClicked: root.showTab("presets")
            }
        }

        FlyoutInput {
            id: search
            anchors.left: tabs.right
            anchors.leftMargin: Theme.spaceL
            anchors.right: toolbar.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            placeholder: root.tab === "presets" ? "Search presets" : "Search keys, descriptions, commands"
            echoPassword: false
            onTextChanged: root.query = text
            // Tab walks between the two lists, since the field keeps focus
            onTabPressed: root.showTab(root.tab === "binds" ? "presets" : "binds")
            onBackTabPressed: root.showTab(root.tab === "binds" ? "presets" : "binds")
            onEscapePressed: {
                if (text !== "") text = ""
                else if (root.selectionCount > 0) root.clearSelection()
                else if (root.standalone) root.closeRequested()
            }
        }

        Row {
            id: toolbar
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceM

            FlyoutChip {
                text: "Undo"
                visible: root.lastWritten !== ""
                enabled: !root.busy
                onClicked: root.undo()
            }
            FlyoutChip {
                text: root.hideBound ? "Show added" : "Hide added"
                visible: root.tab === "presets"
                onClicked: root.hideBound = !root.hideBound
            }
            FlyoutChip {
                // straight to the bind being edited, when there is one
                text: root.linkLine > 0 ? "Open at line " + root.linkLine : "Open file"
                onClicked: root.openConf(root.linkLine)
            }
            FlyoutChip {
                text: "+ Add"
                visible: root.tab === "binds"
                selected: root.editMode === "add"
                enabled: root.model !== null && !root.busy
                onClicked: root.editMode === "add" ? root.closeEditor() : root.openAdd()
            }
        }
    }

    // status line, and the file all of this is about: the path is a link,
    // and while a bind is open in the editor it opens on that bind's line
    Item {
        width: parent.width
        height: Theme.headingHeight

        Label {
            anchors.left: parent.left
            anchors.right: confLink.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Theme.fontSmall
            color: root.notice !== "" ? (root.noticeIsError ? Theme.alert : Theme.text) : Theme.subtext
            text: root.busy ? "Writing…"
                : root.notice !== "" ? root.notice
                : !root.model ? ""
                : root.tab === "presets"
                    ? root.presetTotal + " presets, " + root.presetBound + " already added"
                        + " · tick to add, 󰏫 to change one first"
                    : root.model.rows.length + " binds, " + root.editableCount
                        + " editable here · the rest are generated or not plain commands"
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

    // ---- editor ----
    Rectangle {
        id: editor
        visible: root.editMode !== ""
        width: parent.width
        height: visible ? editorCol.implicitHeight + Theme.panelPad * 2 : 0
        radius: Theme.radiusInner
        color: Theme.fieldFill
        border.width: Theme.borderWidth
        border.color: Theme.stroke

        Column {
            id: editorCol
            x: Theme.spaceXl
            y: Theme.panelPad
            width: parent.width - Theme.spaceXl * 2
            spacing: Theme.spaceM

            FlyoutHeading {
                text: root.editMode === "add" ? "NEW BIND"
                    : "EDIT BIND · LINE " + (root.editRow ? root.editRow.line : "")
            }

            // combo: typed, or recorded from the keyboard
            Row {
                width: parent.width
                spacing: Theme.spaceL

                FieldLabel { text: "Keys" }

                Item {
                    width: parent.width - Theme.fs(90) - Theme.spaceL - recordChip.width - Theme.spaceL
                    height: Theme.rowHeightTall

                    FlyoutInput {
                        id: keysInput
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spaceS
                        anchors.rightMargin: Theme.spaceS
                        visible: !root.capturing
                        echoPassword: false
                        placeholder: "SUPER + SHIFT + T"
                        onTextChanged: root.editError = ""
                        onAccepted: cmdInput.forceFocus()
                        onEscapePressed: root.closeEditor()
                    }

                    // stands in for the field while recording
                    Rectangle {
                        anchors.fill: parent
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
                            text: root.captureMods !== "" ? root.captureMods + " + …"
                                : "Press a combination · Escape to type it instead"
                        }
                    }

                    Item {
                        id: captureSink
                        focus: false
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
                            keysInput.text = m !== "" ? m + " + " + name : name
                            root.capturing = false
                            cmdInput.forceFocus()
                        }
                        Keys.onReleased: event => {
                            event.accepted = true
                            if (root.capturing) root.captureMods = root.modsText(event.modifiers)
                        }
                    }
                }

                FlyoutChip {
                    id: recordChip
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.capturing ? "Stop" : "Record"
                    selected: root.capturing
                    onClicked: {
                        if (root.capturing) { root.capturing = false; keysInput.forceFocus() }
                        else root.startCapture()
                    }
                }
            }

            // what it does: a shell command, or a dispatcher written in Lua
            Row {
                width: parent.width
                spacing: Theme.spaceL
                FieldLabel { text: "Does" }
                Row {
                    spacing: Theme.spaceS
                    height: Theme.rowHeightTall
                    FlyoutChip {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Command"
                        selected: root.editKind === "exec"
                        onClicked: { root.editKind = "exec"; root.editError = "" }
                    }
                    FlyoutChip {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Lua action"
                        selected: root.editKind === "lua"
                        onClicked: { root.editKind = "lua"; root.editError = "" }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: Theme.spaceM
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSmall
                        text: root.editKind === "lua" ? "a hl.dsp dispatcher, written out"
                            : "run through hl.dsp.exec_cmd()"
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spaceL
                FieldLabel { text: root.editKind === "lua" ? "Action" : "Command" }
                Item {
                    width: parent.width - Theme.fs(90) - Theme.spaceL
                    height: Theme.rowHeightTall
                    FlyoutInput {
                        id: cmdInput
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spaceS
                        anchors.rightMargin: Theme.spaceS
                        echoPassword: false
                        placeholder: root.editKind === "lua" ? "hl.dsp.window.close()"
                            : "shell command, run through exec_cmd"
                        onTextChanged: root.editError = ""
                        onAccepted: descInput.forceFocus()
                        onEscapePressed: root.closeEditor()
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spaceL
                FieldLabel { text: "Description" }
                Item {
                    width: parent.width - Theme.fs(90) - Theme.spaceL
                    height: Theme.rowHeightTall
                    FlyoutInput {
                        id: descInput
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spaceS
                        anchors.rightMargin: Theme.spaceS
                        echoPassword: false
                        // what the list shows when there's no comment
                        placeholder: root.editRow ? root.editRow.autoDesc + " (optional, saved as a comment)"
                            : "optional, saved as a comment on the line"
                        onAccepted: root.save()
                        onEscapePressed: root.closeEditor()
                    }
                }
            }

            // hl.bind's options, as toggles -- unless the call's table holds
            // something these chips can't say, in which case it's left alone
            Row {
                width: parent.width
                spacing: Theme.spaceL
                FieldLabel { text: "Options" }
                Flow {
                    width: parent.width - Theme.fs(90) - Theme.spaceL
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
                    width: parent.width - Theme.fs(90) - Theme.spaceL
                    height: Theme.rowHeightTall
                    verticalAlignment: Text.AlignVCenter
                    visible: !root.editFlagsSimple
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall
                    text: "kept as written: " + root.editOptsSrc
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spaceL
                FieldLabel { text: "Section" }
                Flow {
                    width: parent.width - Theme.fs(90) - Theme.spaceL
                    spacing: Theme.spaceS
                    Repeater {
                        model: root.editCategories
                        FlyoutChip {
                            required property var modelData
                            text: modelData
                            selected: root.editCategory === modelData
                            onClicked: root.editCategory = modelData
                        }
                    }
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
                    return HyprBinds.normalizeKeys(keysInput.text) + " is already bound: " + c.desc
                        + " (line " + c.line + ")"
                        + (root.conflicts.length > 1 ? " and " + (root.conflicts.length - 1) + " more" : "")
                        + (root.conflictAck !== "" ? " · Save again to bind it anyway" : "")
                }
            }

            Item {
                width: parent.width
                height: Theme.fs(22)

                FlyoutChip {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.editMode === "edit"
                    text: root.deleteArmed ? "Click again to delete" : "Delete"
                    selected: root.deleteArmed
                    enabled: !root.busy
                    onClicked: root.remove()
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spaceM
                    FlyoutChip { text: "Cancel"; onClicked: root.closeEditor() }
                    FlyoutChip {
                        text: root.conflicts.length > 0
                            && root.conflictAck === HyprBinds.normalizeKeys(keysInput.text)
                            ? "Save anyway" : "Save"
                        enabled: !root.busy
                        selected: true
                        onClicked: root.save()
                    }
                }
            }
        }
    }

    // ---- what's ticked, and the one button that writes it ----
    Rectangle {
        id: selectionBar
        visible: root.tab === "presets" && root.selectionCount > 0 && root.editMode === ""
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

    // ---- list ----
    Item {
        width: parent.width
        height: root.bodyHeight
            - (editor.visible ? editor.height + Theme.spaceM : 0)
            - (selectionBar.visible ? selectionBar.height + Theme.spaceM : 0)

        // the config's own binds
        Flickable {
            id: list
            anchors.fill: parent
            anchors.rightMargin: Theme.sp(10)
            visible: root.tab === "binds"
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
                        FlyoutHeading { text: group.modelData.name.toUpperCase() }

                        Repeater {
                            model: group.modelData.rows

                            Item {
                                id: row
                                required property var modelData
                                readonly property bool editing: root.editRow !== null
                                    && root.editRow.callStart === modelData.callStart

                                width: group.width
                                height: Theme.row(36)

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.leftMargin: -Theme.spaceS
                                    anchors.rightMargin: -Theme.spaceS
                                    radius: Theme.radiusInner
                                    color: row.editing ? Theme.selectedFill
                                        : rowMouse.containsMouse ? Theme.hoverFill : "transparent"
                                    border.width: row.editing ? Theme.borderWidth : 0
                                    border.color: Theme.selectedStroke
                                }

                                Label {
                                    id: keysText
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.fs(200)
                                    text: (row.modelData.conflict ? "󰀦 " : "") + row.modelData.keys
                                    color: row.modelData.conflict ? Theme.alert : Theme.textStrong
                                }

                                Column {
                                    anchors.left: keysText.right
                                    anchors.leftMargin: Theme.spaceXl
                                    anchors.right: flagsText.left
                                    anchors.rightMargin: Theme.spaceXl
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Label {
                                        width: parent.width
                                        text: row.modelData.desc
                                    }
                                    Label {
                                        width: parent.width
                                        text: row.modelData.command
                                        color: Theme.subtext
                                        font.pixelSize: Theme.fontSmall
                                    }
                                }

                                Label {
                                    id: flagsText
                                    anchors.right: stateIcon.left
                                    anchors.rightMargin: Theme.sp(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: row.modelData.flags.map(f => root.flagLabels[f] || f).join(" · ")
                                    color: Theme.subtext
                                    font.pixelSize: Theme.fontSmall
                                }

                                // pencil on hover when editable, a lock when not
                                Text {
                                    id: stateIcon
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.fs(18)
                                    horizontalAlignment: Text.AlignHCenter
                                    text: row.modelData.editable ? "󰏫" : "󰌾"
                                    visible: !row.modelData.editable || rowMouse.containsMouse || row.editing
                                    color: row.modelData.editable ? Theme.textStrong : Theme.textDisabled
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontIconSize
                                }

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: row.modelData.editable ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (root.busy) return
                                        if (row.modelData.editable) root.openEdit(row.modelData)
                                        else {
                                            root.say("Line " + row.modelData.line + ": " + row.modelData.reason
                                                + " -- open the file to edit it", false)
                                            root.noticeLine = row.modelData.line
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Label {
                    visible: root.model !== null && root.groups.length === 0
                    width: parent.width
                    topPadding: Theme.spaceXl
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.subtext
                    text: root.query !== "" ? "No binds match \"" + root.query + "\"" : "No hl.bind() calls found"
                }
            }
        }

        // the catalogue
        Flickable {
            id: presetList
            anchors.fill: parent
            anchors.rightMargin: Theme.sp(10)
            visible: root.tab === "presets"
            contentHeight: presetCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: presetCol
                x: Theme.spaceS
                width: presetList.width - Theme.spaceS * 2
                spacing: Theme.spaceXs

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
                        width: presetCol.width
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

                            Item {
                                id: pRow
                                required property var modelData
                                readonly property bool ticked: root.selection[modelData.id] === true
                                readonly property bool done: modelData.state === "bound"
                                readonly property bool unavailable: modelData.missing.length > 0

                                width: pack.width
                                height: Theme.row(36)

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

                                Label {
                                    id: pKeys
                                    anchors.left: mark.right
                                    anchors.leftMargin: Theme.spaceM
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.fs(180)
                                    text: pRow.modelData.keys
                                    color: pRow.done ? Theme.subtext
                                        : pRow.modelData.state === "taken" ? Theme.alert
                                        : Theme.textStrong
                                }

                                Column {
                                    anchors.left: pKeys.right
                                    anchors.leftMargin: Theme.spaceXl
                                    anchors.right: pState.left
                                    anchors.rightMargin: Theme.spaceXl
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Label {
                                        width: parent.width
                                        text: pRow.modelData.desc
                                        color: pRow.unavailable ? Theme.textDisabled : Theme.text
                                    }
                                    Label {
                                        width: parent.width
                                        text: pRow.modelData.action
                                        color: Theme.subtext
                                        font.pixelSize: Theme.fontSmall
                                    }
                                }

                                // what the config already says about it
                                Label {
                                    id: pState
                                    anchors.right: pEdit.left
                                    anchors.rightMargin: Theme.sp(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    // capped, so a long "taken by" doesn't
                                    // squeeze the command out of the middle
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
                                            ? "you have this on " + pRow.modelData.other.keys
                                        : "goes in " + pRow.modelData.section
                                }

                                // open it in the editor instead of ticking it
                                Text {
                                    id: pEdit
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.fs(18)
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "󰏫"
                                    visible: !pRow.done && (pMouse.containsMouse || editMouse.containsMouse)
                                    color: editMouse.containsMouse ? Theme.textStrong : Theme.subtext
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontIconSize

                                    MouseArea {
                                        id: editMouse
                                        anchors.fill: parent
                                        anchors.margins: -Theme.spaceS
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.busy) return
                                            root.showTab("presets")
                                            root.openPreset(pRow.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Label {
                    visible: root.presetGroups.length === 0
                    width: parent.width
                    topPadding: Theme.spaceXl
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.subtext
                    text: root.query !== "" ? "No presets match \"" + root.query + "\""
                        : root.hideBound ? "Every preset here is already in your config · Show added to see them"
                        : "No presets"
                }
            }
        }

        // scroll indicator
        ScrollBar {
            anchors.right: parent.right
            flickable: root.tab === "presets" ? presetList : list
        }
    }
}
