// Singularity - Quickshell
// ~/.config/quickshell/flyouts/NoteChecklist.qml
//
// A sticky note's checklist (Notes tab kind "list"), shared by the Notes
// window and the desktop's sticky. Click the box to tick a row, type in it.
//
//   Enter        new row below      Backspace on an empty row   remove it
//   Up / Down    previous / next row     Escape   leave (escaped())
//
// Rows are kept in a ListModel brought in line with the tab in place, so
// typing, focus and scroll survive the other editor's changes.

import QtQuick
import "../services"

ListView {
    id: root

    required property int slot
    // colours and type, as the host draws its text
    property color textColor: Theme.text
    property color dimColor: Theme.textDisabled
    property color accentColor: Theme.accent
    property color tickColor: Theme.textOnAccent
    property color selectionColor: Theme.selectedStroke
    property color selectedTextColor: Theme.textStrong
    property string fontFamily: Theme.fontText
    property int fontPixel: Theme.fontBody
    property int fontWeight: Theme.weightBody
    property string addText: "Add item"

    signal escaped()

    readonly property var items: (Notes.tabs[slot] || { items: [] }).items
    readonly property int box: Math.round(fontPixel * 1.15)

    // the row to give the cursor once it exists
    property int wantFocus: -1

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    spacing: Theme.spaceS
    interactive: contentHeight > height

    model: ListModel { id: rows }

    function sync() {
        const src = items
        while (rows.count > src.length) rows.remove(rows.count - 1)
        for (let k = 0; k < src.length; k++) {
            if (k >= rows.count) { rows.append({ text: src[k].text, done: src[k].done }); continue }
            const r = rows.get(k)
            if (r.text !== src[k].text) rows.setProperty(k, "text", src[k].text)
            if (r.done !== src[k].done) rows.setProperty(k, "done", src[k].done)
        }
        // a row inserted mid-list shifts the others down, so its delegate
        // already exists and never runs its completion
        if (wantFocus >= 0) Qt.callLater(() => root.focusRow(root.wantFocus))
    }
    onSlotChanged: sync()
    Component.onCompleted: sync()
    Connections {
        target: Notes
        function onTabsChanged() { root.sync() }
        function onEdited(i) { if (i === root.slot) root.sync() }
    }

    function focusRow(k) {
        if (k < 0) return
        wantFocus = k
        const row = itemAtIndex(k)
        if (row) row.take()
    }
    function insertAfter(k) {
        wantFocus = k + 1
        Notes.addItem(slot, k)
    }

    delegate: Item {
        id: row
        required property int index
        required property string text
        required property bool done

        width: root.width
        height: Math.max(root.box, field.contentHeight)

        function take() {
            field.forceActiveFocus()
            field.cursorPosition = field.length
            root.wantFocus = -1
            root.positionViewAtIndex(index, ListView.Contain)
        }
        Component.onCompleted: if (root.wantFocus === index) take()

        Rectangle {
            y: Math.round((root.fontPixel * 1.4 - root.box) / 2)
            width: root.box
            height: root.box
            radius: Theme.radiusInner / 2
            color: row.done ? root.accentColor : "transparent"
            border.width: Theme.borderWidth
            border.color: row.done ? root.accentColor : root.dimColor
            opacity: tickMouse.containsMouse && !row.done ? 0.7 : 1

            Text {
                anchors.centerIn: parent
                visible: row.done
                text: "󰄬"
                color: root.tickColor
                font.family: Theme.fontIcon
                font.pixelSize: Math.round(root.box * 0.8)
            }
            MouseArea {
                id: tickMouse
                anchors.fill: parent
                anchors.margins: -Theme.spaceS
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notes.toggleItem(root.slot, row.index)
            }
        }

        TextEdit {
            id: field
            x: root.box + Theme.spaceM
            width: parent.width - x
            text: row.text
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            color: row.done ? root.dimColor : root.textColor
            selectionColor: root.selectionColor
            selectedTextColor: root.selectedTextColor
            font.family: root.fontFamily
            font.pixelSize: root.fontPixel
            font.weight: root.fontWeight
            font.strikeout: row.done

            onTextChanged: Notes.setItemText(root.slot, row.index, text)
            onCursorRectangleChanged: if (activeFocus) {
                const y = row.y + cursorRectangle.y
                if (y < root.contentY) root.contentY = y
                else if (y + cursorRectangle.height > root.contentY + root.height)
                    root.contentY = y + cursorRectangle.height - root.height
            }

            Keys.onEscapePressed: root.escaped()
            Keys.onPressed: event => {
                if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.insertAfter(row.index)
                } else if (event.key === Qt.Key_Backspace && length === 0) {
                    root.focusRow(row.index - 1)
                    Notes.removeItem(root.slot, row.index)
                } else if (event.key === Qt.Key_Up && cursorRectangle.y < 1) {
                    root.focusRow(row.index - 1)
                } else if (event.key === Qt.Key_Down && cursorRectangle.y + cursorRectangle.height >= contentHeight - 1) {
                    root.focusRow(row.index + 1)
                } else return
                event.accepted = true
            }
        }
    }

    footer: Item {
        width: root.width
        height: root.fontPixel * 2

        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: root.box + Theme.spaceM
            text: "+  " + root.addText
            color: addMouse.containsMouse ? root.textColor : root.dimColor
            font.family: root.fontFamily
            font.pixelSize: root.fontPixel
            font.weight: root.fontWeight

            MouseArea {
                id: addMouse
                anchors.fill: parent
                anchors.margins: -Theme.spaceS
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.insertAfter(root.count - 1)
            }
        }
    }
}
