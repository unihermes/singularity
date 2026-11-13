// A sticky note on the desktop: one of the Notes tabs (SUPER+N), to read
// and type in. Its title in the accent, + for a new note beside it and ×
// to take it off the desktop (it stays in the Notes window). Typing here
// and in the window lands in the same tab (Notes.edited). 󰄬 turns it into a
// checklist and back. Double-click the title to rename it.

import QtQuick
import "../services"
import "../flyouts"

WidgetCard {
    id: root

    required property string noteId
    // the screen's DesktopWidgets, which places a new note
    property var desk: null
    // Esc: done typing here
    signal letGo()

    readonly property int index: Notes.indexOf(noteId)
    readonly property var tab: Notes.tabs[index] || { title: "", text: "", kind: "text" }
    property bool renaming: false
    readonly property bool list: tab.kind === "list"

    // set rather than bound, so typing doesn't fight a binding
    // (not while it's going: its tab already gone)
    property bool loadingNote: false
    function load() {
        if (index < 0 || !editor || editor.text === Notes.editorText(tab)) return
        loadingNote = true
        editor.text = Notes.editorText(tab)
        loadingNote = false
    }
    onIndexChanged: load()
    Connections {
        target: Notes
        function onTabsChanged() { root.load() }
        function onEdited(i) { if (i === root.index && !editor.activeFocus) root.load() }
    }
    Component.onCompleted: load()

    Item {
        id: top
        width: parent.width
        height: title.height

        WidgetCaption {
            id: title
            width: parent.width - tools.width - Theme.fit(8)
            card: root
            text: root.tab.title
            visible: !renaming

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onDoubleClicked: {
                    root.renaming = true
                    renameField.text = root.tab.title
                    renameField.selectAll()
                    renameField.forceActiveFocus()
                }
            }
        }

        TextInput {
            id: renameField
            visible: root.renaming
            anchors.verticalCenter: title.verticalCenter
            width: title.width
            color: root.accent
            selectionColor: root.accent
            selectedTextColor: Theme.textOnAccent
            font.family: root.font
            font.pixelSize: root.textCaption
            font.weight: root.weightStrong
            font.letterSpacing: 1
            font.capitalization: Font.AllUppercase
            maximumLength: 40
            clip: true
            function finish(keep) {
                if (!root.renaming) return
                root.renaming = false
                if (keep) Notes.rename(root.index, text)
            }
            Keys.onReturnPressed: finish(true)
            Keys.onEnterPressed: finish(true)
            Keys.onEscapePressed: { finish(false); root.letGo() }
            onActiveFocusChanged: if (!activeFocus) finish(true)
        }
        Row {
            id: tools
            anchors.right: parent.right
            anchors.verticalCenter: title.verticalCenter
            spacing: Theme.fit(12)
            WidgetGlyph {
                card: root
                px: Theme.fit(15)
                text: "󰄬"
                opacity: root.list ? 1 : 0.55
                onClicked: Notes.setKind(root.index, root.list ? "text" : "list")
            }
            WidgetGlyph {
                card: root
                px: Theme.fit(15)
                text: "󰐕"
                active: !!root.desk
                onClicked: root.desk.newNoteBeside("note:" + root.noteId)
            }
            WidgetGlyph {
                card: root
                px: Theme.fit(15)
                text: "󰅖"
                onClicked: Notes.closeDesk(root.index)
            }
        }
    }

    NoteChecklist {
        visible: root.list
        anchors.top: top.bottom
        anchors.topMargin: Theme.fit(8)
        width: parent.width
        height: parent.height - y
        slot: root.index
        textColor: root.fg
        dimColor: root.fgFaint
        accentColor: root.accent
        tickColor: Theme.textOnAccent
        selectionColor: root.accent
        selectedTextColor: Theme.textOnAccent
        fontFamily: root.font
        fontWeight: root.weightBody
        fontPixel: root.textBody
        onEscaped: root.letGo()
    }

    Flickable {
        id: flick
        visible: !root.list
        anchors.top: top.bottom
        anchors.topMargin: Theme.fit(6)
        width: parent.width
        height: parent.height - y
        contentWidth: width
        contentHeight: editor.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        function ensureVisible(r) {
            if (contentY >= r.y) contentY = r.y
            else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height
        }

        TextEdit {
            id: editor
            width: flick.width
            height: Math.max(implicitHeight, flick.height)
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.RichText
            selectByMouse: true
            color: root.fg
            selectionColor: root.accent
            selectedTextColor: Theme.textOnAccent
            font.family: root.font
            font.weight: root.weightBody
            font.pixelSize: root.textBody

            onTextChanged: if (activeFocus && !root.loadingNote) Notes.setText(root.index, text)
            onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
            Keys.onEscapePressed: { focus = false; root.letGo() }
            Keys.onPressed: event => {
                if (!(event.modifiers & Qt.ControlModifier)) return
                if (event.key === Qt.Key_B) Notes.toggleFormat(editor, "bold")
                else if (event.key === Qt.Key_I) Notes.toggleFormat(editor, "italic")
                else if (event.key === Qt.Key_X && (event.modifiers & Qt.ShiftModifier)) Notes.toggleFormat(editor, "strikeout")
                else return
                event.accepted = true
            }

            Text {
                visible: editor.length === 0 && !editor.activeFocus
                text: "Click to write…"
                color: root.fgFaint
                font: editor.font
            }
        }
    }
}
