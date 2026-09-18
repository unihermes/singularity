// Singularity - Quickshell
// ~/.config/quickshell/windows/KeybindsBody.qml
//
// The Keybinds editor itself: every hl.bind() in hyprland.lua, grouped by the
// config's `-- --- Section ---` markers, searchable, with add / edit / delete
// for the binds simple enough to rewrite safely. Parsing and rewriting live in
// HyprBinds.js, the safe write in HyprLuaWrite.qml.
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
import "../services"
import "../flyouts"

Column {
    id: root

    // hl.bind options, as a person would say them
    readonly property var flagLabels: ({
        locked: "works when locked", repeating: "repeats when held", mouse: "mouse",
        release: "on release", long_press: "hold", non_consuming: "passes key on",
    })

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

    // total height of the list and editor together, so opening the editor
    // shrinks the list instead of resizing (and re-centring) the window
    property int bodyHeight: Theme.fs(520)

    property var model: null
    property string query: ""
    property string notice: ""
    property bool noticeIsError: false
    readonly property bool busy: HyprLuaWrite.busy
    // what the last write put on disk; undo only runs while the file still says it
    property string lastWritten: ""
    property string pendingMessage: ""

    // editor
    property string editMode: ""     // "" | "add" | "edit"
    property var editRow: null
    property string editCategory: ""
    property bool capturing: false
    property string captureMods: ""
    // the combo a conflict warning was shown for; saving it again goes ahead
    property string conflictAck: ""
    property bool deleteArmed: false
    property string editError: ""

    function say(msg, isError) {
        notice = msg
        noticeIsError = isError
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

    onActiveChanged: activate()
    Component.onCompleted: if (active) activate()

    // load fresh on show, drop the editor and search on hide
    function activate() {
        if (active) {
            luaFile.reload()
            model = null
            reparse(false)
            if (luaFile.text() === "") say("Couldn't read " + confPath, true)
            search.forceFocus()
        } else {
            closeEditor()
            search.text = ""
            notice = ""
        }
    }

    // --- grouping --------------------------------------------------------

    readonly property var groups: {
        if (!model) return []
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

    // --- editor ----------------------------------------------------------

    function openAdd() {
        editMode = "add"
        editRow = null
        keysInput.text = ""
        cmdInput.text = ""
        descInput.text = ""
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
        editCategory = row.category
        resetEditorState()
        cmdInput.forceFocus()
    }

    function resetEditorState() {
        capturing = false
        captureMods = ""
        conflictAck = ""
        deleteArmed = false
        editError = ""
        notice = ""
    }

    function closeEditor() {
        editMode = ""
        editRow = null
        capturing = false
    }

    readonly property var conflicts: editMode === "" || !model ? []
        : HyprBinds.conflictsFor(model, keysInput.text, editRow ? editRow.callStart : -1)

    function save() {
        var keys = HyprBinds.tidyKeys(keysInput.text)
        var cmd = cmdInput.text.trim()
        if (keys.keyCount === 0) { editError = "The combo needs a key, not just modifiers"; return }
        if (keys.keyCount > 1) { editError = "One key per combo -- join them with + only after modifiers"; return }
        if (cmd === "") { editError = "The command can't be empty"; return }

        var norm = HyprBinds.normalizeKeys(keys.text)
        if (conflicts.length > 0 && conflictAck !== norm) {
            conflictAck = norm
            editError = ""
            return
        }

        var fields = { keys: keys.text, command: cmd, desc: descInput.text, category: editCategory }
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
            return
        }
        if (status !== "ok") {
            lastWritten = ""
            say("Couldn't write hyprland.lua" + (detail ? ": " + detail.split("\n")[0] : ""), true)
            return
        }
        closeEditor()
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

    // --- layout ----------------------------------------------------------

    // toolbar: search, then actions
    Item {
        width: parent.width
        height: Theme.rowHeightTall

        FlyoutInput {
            id: search
            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceS
            anchors.right: toolbar.left
            anchors.rightMargin: Theme.spaceXl
            anchors.verticalCenter: parent.verticalCenter
            placeholder: "Search keys, descriptions, commands"
            echoPassword: false
            onTextChanged: root.query = text
            onEscapePressed: {
                if (text !== "") text = ""
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
                text: "Open file"
                onClicked: Quickshell.execDetached(["alacritty", "-e", "nvim", root.confPath])
            }
            FlyoutChip {
                text: "+ Add"
                selected: root.editMode === "add"
                enabled: root.model !== null && !root.busy
                onClicked: root.editMode === "add" ? root.closeEditor() : root.openAdd()
            }
        }
    }

    Label {
        width: parent.width
        height: Theme.headingHeight
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: Theme.fontSmall
        color: root.notice !== "" ? (root.noticeIsError ? Theme.alert : Theme.text) : Theme.subtext
        text: root.busy ? "Writing…"
            : root.notice !== "" ? root.notice
            : root.model ? root.model.rows.length + " binds, " + root.editableCount
                + " editable here · the rest are generated or not plain commands, see Open file"
            : ""
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

            Row {
                width: parent.width
                spacing: Theme.spaceL
                FieldLabel { text: "Command" }
                Item {
                    width: parent.width - Theme.fs(90) - Theme.spaceL
                    height: Theme.rowHeightTall
                    FlyoutInput {
                        id: cmdInput
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spaceS
                        anchors.rightMargin: Theme.spaceS
                        echoPassword: false
                        placeholder: "shell command, run through exec_cmd"
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

            Row {
                width: parent.width
                spacing: Theme.spaceL
                FieldLabel { text: "Section" }
                Flow {
                    width: parent.width - Theme.fs(90) - Theme.spaceL
                    spacing: Theme.spaceS
                    Repeater {
                        model: root.model ? root.model.categories.map(c => c.name) : []
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

    // ---- list ----
    Item {
        width: parent.width
        height: root.bodyHeight - (editor.visible ? editor.height + Theme.spaceM : 0)

        Flickable {
            id: list
            anchors.fill: parent
            anchors.rightMargin: Theme.sp(10)
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
                                        else root.say("Line " + row.modelData.line + ": " + row.modelData.reason
                                            + " -- edit it in hyprland.lua", false)
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

        // scroll indicator
        ScrollBar {
            anchors.right: parent.right
            flickable: list
        }
    }
}
