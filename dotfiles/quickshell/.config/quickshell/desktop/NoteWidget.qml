// Singularity - Quickshell
// ~/.config/quickshell/desktop/NoteWidget.qml
//
// One of the Notes tabs (SUPER+N) on the desktop, to read and type in: its
// title in the accent with ‹ › to show another tab, the text under it.
// Typing here and in the Notes window lands in the same tab (Notes.edited).

import QtQuick
import "../services"

WidgetCard {
    id: root

    // the tab shown: the one saved by title, else the first
    readonly property int index: {
        const t = Settings.deskWidget("note").tab
        const i = Notes.tabs.findIndex(x => x.title === t)
        return i >= 0 ? i : 0
    }
    readonly property var tab: Notes.tabs[index] || { title: "Note", text: "" }

    function show(delta) {
        const n = Notes.tabs.length
        if (n < 2) return
        Settings.setDeskWidget("note", { tab: Notes.tabs[((index + delta) % n + n) % n].title })
    }

    // set rather than bound, so typing doesn't fight a binding
    function load() { if (editor.text !== tab.text) editor.text = tab.text }
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
            width: parent.width - arrows.width
            card: root
            px: Theme.fit(13)
            text: root.tab.title.toUpperCase()
            color: root.accent
            font.weight: Font.Bold
            font.letterSpacing: 1
        }
        Row {
            id: arrows
            visible: Notes.tabs.length > 1
            anchors.right: parent.right
            spacing: Theme.fit(12)
            WidgetGlyph { card: root; px: Theme.fit(14); text: "󰅁"; onClicked: root.show(-1) }
            WidgetGlyph { card: root; px: Theme.fit(14); text: "󰅂"; onClicked: root.show(1) }
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
