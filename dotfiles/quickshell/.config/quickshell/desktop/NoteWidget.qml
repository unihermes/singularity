// Singularity - Quickshell
// ~/.config/quickshell/desktop/NoteWidget.qml
//
// A sticky note on the desktop: one of the Notes tabs (SUPER+N), to read
// and type in. Its title in the accent, + for a new note beside it and ×
// to take it off the desktop (it stays in the Notes window). Typing here
// and in the window lands in the same tab (Notes.edited).

import QtQuick
import "../services"

WidgetCard {
    id: root

    required property string noteId
    // the screen's DesktopWidgets, which places a new note
    property var desk: null

    readonly property int index: Notes.indexOf(noteId)
    readonly property var tab: Notes.tabs[index] || { title: "", text: "" }

    // set rather than bound, so typing doesn't fight a binding
    // (not while it's going: its tab already gone)
    function load() { if (index >= 0 && editor && editor.text !== tab.text) editor.text = tab.text }
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

        WidgetText {
            id: title
            width: parent.width - tools.width - Theme.fit(8)
            card: root
            px: Theme.fit(13)
            text: root.tab.title.toUpperCase()
            color: root.accent
            font.weight: Font.Bold
            font.letterSpacing: 1
        }
        Row {
            id: tools
            anchors.right: parent.right
            anchors.verticalCenter: title.verticalCenter
            spacing: Theme.fit(12)
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
                onClicked: Notes.setDesk(root.index, null)
            }
        }
    }

    Flickable {
        id: flick
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
            selectByMouse: true
            color: root.fg
            selectionColor: root.accent
            selectedTextColor: "#000000"
            font.family: root.font
            font.weight: Font.DemiBold
            font.pixelSize: Theme.fit(15)

            onTextChanged: if (activeFocus) Notes.setText(root.index, text)
            onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
            Keys.onEscapePressed: focus = false

            Text {
                visible: editor.text === "" && !editor.activeFocus
                text: "Click to write…"
                color: root.fgFaint
                font: editor.font
            }
        }
    }
}
