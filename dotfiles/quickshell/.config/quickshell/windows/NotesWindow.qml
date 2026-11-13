// Sticky notes (SUPER+N): tabbed, pinned top-right over every workspace by
// window-rules.lua's "notes" rule; saved as you type (services/Notes.qml).
// Every note lives here; a pinned one also shows on the desktop.
//
//   click a tab           switch to it
//   double-click a tab    rename it (Enter keeps, Escape drops)
//   Text / List           the open note as free text or a checklist
//   Pin                   put it on the desktop, or take it off (lit there)
//   Delete                delete it; a second click confirms when it has text
//   Ctrl+T / Ctrl+W       new tab / delete the open one
//   Ctrl+L                text or checklist
//   Ctrl+Tab, Ctrl+PgDn   next tab (Shift / PgUp for the previous)
//   Ctrl+B / Ctrl+I       bold / italic selection
//   Ctrl+Shift+X          strike through selection
//   a checklist:          Enter adds a row, Backspace on an empty one removes it
//   Escape                hide the window

import Quickshell
import QtQuick
import "../services"
import "../flyouts"

FloatingWindow {
    id: root

    visible: false
    title: "Notes"
    color: "transparent"

    implicitWidth: Theme.fit(440)
    implicitHeight: Theme.fit(520)

    function open() { visible = true }
    function close() {
        Notes.flush()
        visible = false
    }
    function toggle() { visible ? close() : open() }

    onClosed: close()
    onVisibleChanged: if (visible) root.focusNote()

    // the tab being renamed, -1 for none
    property int renaming: -1
    // the tab whose × has been clicked once, waiting for the second
    property int armed: -1
    property bool loadingNote: false

    function removeTab(i) {
        if (Notes.hasContent(Notes.tabs[i]) && armed !== i) {
            armed = i
            disarm.restart()
            return
        }
        armed = -1
        Notes.remove(i)
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = -1
    }

    readonly property var tab: Notes.tabs[Notes.current] || Notes.blank("")
    readonly property bool list: tab.kind === "list"
    readonly property int doneCount: tab.items.filter(it => it.done).length

    // the open note's editor takes the keys
    function focusNote() {
        if (list) { if (checklist.count > 0) checklist.focusRow(checklist.count - 1); else checklist.insertAfter(-1) }
        else editor.forceActiveFocus()
    }

    function setKind(kind) {
        Notes.setKind(Notes.current, kind)
        Qt.callLater(focusNote)
    }

    // the editor follows the open tab; set rather than bound, so typing
    // doesn't fight a binding
    function loadCurrent() {
        const t = Notes.tabs[Notes.current]
        if (t && editor.text !== Notes.editorText(t)) {
            loadingNote = true
            editor.text = Notes.editorText(t)
            loadingNote = false
        }
        armed = -1
    }
    Connections {
        target: Notes
        function onCurrentChanged() { root.loadCurrent() }
        function onTabsChanged() { root.loadCurrent() }
        // typed in the desktop's note
        function onEdited(i) { if (i === Notes.current && !editor.activeFocus) root.loadCurrent() }
    }
    Component.onCompleted: loadCurrent()

    WindowChrome {
        window: root
    }

    // --- tabs ----------------------------------------------------------------

    Item {
        id: strip
        x: Theme.windowPad
        y: Theme.windowPad
        width: root.width - Theme.windowPad * 2
        height: Theme.rowHeight

        // the strip's empty space moves the window, as a header does
        MouseArea {
            anchors.fill: parent
            onPressed: root.startSystemMove()
        }

        ListView {
            id: tabList
            anchors.left: parent.left
            height: parent.height
            orientation: ListView.Horizontal
            spacing: Theme.spaceS
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // no wider than the tabs, so the space after them still drags
            width: Math.min(contentWidth, parent.width - addBtn.width - Theme.spaceM)
            model: Notes.tabs
            currentIndex: Notes.current
            highlightFollowsCurrentItem: false
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Rectangle {
                id: tab
                required property var modelData
                required property int index
                readonly property bool open: index === Notes.current
                readonly property bool editing: root.renaming === index

                width: row.implicitWidth + Theme.spaceL * 2
                height: tabList.height
                radius: Theme.radiusInner
                color: open ? Theme.selectedFill : tabMouse.containsMouse ? Theme.hoverFillSoft : "transparent"
                border.width: Theme.borderWidth
                border.color: open ? Theme.selectedStroke : tabMouse.containsMouse ? Theme.strokeHover : Theme.stroke

                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notes.select(tab.index)
                    onDoubleClicked: {
                        root.renaming = tab.index
                        renameField.text = tab.modelData.title
                        renameField.selectAll()
                        renameField.forceActiveFocus()
                    }
                }

                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: Theme.spaceM

                    Text {
                        visible: !tab.editing
                        text: tab.modelData.title
                        color: tab.open ? Theme.textStrong : Theme.text
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontSmall
                        font.weight: tab.open ? Theme.weightStrong : Theme.weightBody
                    }

                    TextInput {
                        id: renameField
                        visible: tab.editing
                        width: Math.max(Theme.fit(60), contentWidth + 2)
                        color: Theme.textStrong
                        selectionColor: Theme.selectedStroke
                        selectedTextColor: Theme.hasAccent ? Theme.textOnAccent : Theme.textStrong
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontSmall
                        font.bold: true
                        maximumLength: 40
                        function finish(keep) {
                            if (root.renaming !== tab.index) return
                            if (keep) Notes.rename(tab.index, text)
                            root.renaming = -1
                            root.focusNote()
                        }
                        Keys.onReturnPressed: finish(true)
                        Keys.onEnterPressed: finish(true)
                        Keys.onEscapePressed: finish(false)
                        onActiveFocusChanged: if (!activeFocus) finish(true)
                    }

                    // a checklist
                    Text {
                        visible: !tab.editing && tab.modelData.kind === "list"
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰄬"
                        color: tab.open ? Theme.accent : Theme.subtext
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontSmall
                    }

                    // on the desktop
                    Rectangle {
                        visible: !tab.editing && !!tab.modelData.desk
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.fit(6)
                        height: width
                        radius: width / 2
                        color: Theme.accent
                    }
                }
            }
        }

        FlyoutChip {
            id: addBtn
            anchors.left: tabList.right
            anchors.leftMargin: Theme.spaceM
            anchors.verticalCenter: parent.verticalCenter
            text: "+"
            onClicked: {
                Notes.add()
                root.focusNote()
            }
        }
    }

    // --- the note --------------------------------------------------------------

    WindowPanel {
        anchors.top: strip.bottom
        anchors.topMargin: Theme.spaceL
        x: Theme.windowPad
        width: root.width - Theme.windowPad * 2
        height: root.height - y - Theme.windowPad

        Item {
            id: tools
            x: Theme.panelPad
            y: Theme.spaceS
            width: parent.width - Theme.panelPad * 2
            height: Theme.chipHeight

            Row {
                spacing: Theme.spaceS
                FlyoutChip { text: "Text"; selected: !root.list; onClicked: root.setKind("text") }
                FlyoutChip { text: "List"; selected: root.list; onClicked: root.setKind("list") }
            }
            Row {
                anchors.right: parent.right
                spacing: Theme.spaceS
                FlyoutChip { visible: !root.list; text: "B"; selected: editor.cursorSelection.font.bold; onClicked: Notes.toggleFormat(editor, "bold") }
                FlyoutChip { visible: !root.list; text: "I"; selected: editor.cursorSelection.font.italic; onClicked: Notes.toggleFormat(editor, "italic") }
                FlyoutChip { visible: !root.list; text: "S̶"; selected: editor.cursorSelection.font.strikeout; onClicked: Notes.toggleFormat(editor, "strikeout") }
                FlyoutChip {
                    visible: root.list
                    text: "Clear done"
                    enabled: root.doneCount > 0
                    onClicked: Notes.clearDone(Notes.current)
                }
            }
        }

        Rectangle {
            id: rule
            x: Theme.panelPad
            y: tools.y + tools.height + Theme.spaceS
            width: tools.width
            height: Theme.borderWidth
            color: Theme.stroke
        }

        NoteChecklist {
            id: checklist
            visible: root.list
            x: Theme.panelPad
            y: rule.y + rule.height + Theme.spaceM
            width: tools.width
            height: footer.y - y - Theme.spaceS
            slot: Notes.current
            onEscaped: root.close()
        }

        // pin and delete, and the checklist's tally
        Item {
            id: footer
            x: Theme.panelPad
            y: parent.height - height - Theme.spaceM
            width: tools.width
            height: Theme.chipHeight

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.list ? (root.tab.items.length === 0 ? "" : root.doneCount + " of " + root.tab.items.length + " done") : ""
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }
            Row {
                anchors.right: parent.right
                spacing: Theme.spaceS
                FlyoutChip {
                    text: root.tab.desk ? "Pinned" : "Pin"
                    icon: "󰐃"
                    selected: !!root.tab.desk
                    onClicked: Notes.toggleDesk(Notes.current)
                }
                FlyoutChip {
                    text: root.armed === Notes.current ? "Sure?" : "Delete"
                    icon: "󰅖"
                    selected: root.armed === Notes.current
                    onClicked: root.removeTab(Notes.current)
                }
            }
        }

        Flickable {
            id: flick
            visible: !root.list
            x: Theme.panelPad
            y: rule.y + rule.height + Theme.spaceM
            width: tools.width
            height: footer.y - y - Theme.spaceS
            contentWidth: width
            contentHeight: editor.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // keep the cursor in view while typing past the bottom
            function ensureVisible(r) {
                if (contentY >= r.y) contentY = r.y
                else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height
            }

            TextEdit {
                id: editor
                width: flick.width
                // clicks below the last line still land in the note
                height: Math.max(implicitHeight, flick.height)
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.RichText
                selectByMouse: true
                persistentSelection: true
                color: Theme.text
                selectionColor: Theme.selectedStroke
                selectedTextColor: Theme.hasAccent ? Theme.textOnAccent : Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody

                onTextChanged: if (!root.loadingNote) Notes.setText(Notes.current, text)
                onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)

                Text {
                    visible: editor.length === 0
                    text: "Write something…"
                    color: Theme.textDisabled
                    font: editor.font
                }

                Keys.onEscapePressed: root.close()
                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (!ctrl) return
                    if (event.key === Qt.Key_B) Notes.toggleFormat(editor, "bold")
                    else if (event.key === Qt.Key_I) Notes.toggleFormat(editor, "italic")
                    else if (event.key === Qt.Key_X && (event.modifiers & Qt.ShiftModifier)) Notes.toggleFormat(editor, "strikeout")
                    else if (event.key === Qt.Key_T) Notes.add()
                    else if (event.key === Qt.Key_L) root.setKind(root.list ? "text" : "list")
                    else if (event.key === Qt.Key_W) root.removeTab(Notes.current)
                    else if (event.key === Qt.Key_Tab || event.key === Qt.Key_PageDown) Notes.step(1)
                    else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_PageUp) Notes.step(-1)
                    else return
                    event.accepted = true
                }
            }
        }

        ScrollBar {
            visible: !root.list
            anchors.right: parent.right
            anchors.rightMargin: 2
            flickable: flick
        }
    }
}
