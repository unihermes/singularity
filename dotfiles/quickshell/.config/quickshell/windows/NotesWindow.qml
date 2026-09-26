// Singularity - Quickshell
// ~/.config/quickshell/windows/NotesWindow.qml
//
// Sticky notes: a small window of tabbed notes, toggled with SUPER+N. It
// floats pinned over every workspace in the top-right corner of the screen,
// placed there by hyprland.lua's "notes" rule and open hook rather than
// centred like Settings and System. The notes themselves are
// services/Notes.qml, saved as you type.
//
//   click a tab           switch to it
//   double-click a tab    rename it (Enter keeps, Escape drops)
//   ×  on the open tab    delete it; a second click confirms when it has text
//   Ctrl+T / Ctrl+W       new tab / delete the open one
//   Ctrl+Tab, Ctrl+PgDn   next tab (Shift / PgUp for the previous)
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

    implicitWidth: Theme.fit(400)
    implicitHeight: Theme.fit(480)

    function open() { visible = true }
    function close() {
        Notes.flush()
        visible = false
    }
    function toggle() { visible ? close() : open() }

    onClosed: close()
    onVisibleChanged: if (visible) editor.forceActiveFocus()

    // the tab being renamed, -1 for none
    property int renaming: -1
    // the tab whose × has been clicked once, waiting for the second
    property int armed: -1

    function removeTab(i) {
        if (Notes.tabs[i].text.trim() !== "" && armed !== i) {
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

    // the editor follows the open tab; set rather than bound, so typing
    // doesn't fight a binding
    function loadCurrent() {
        const t = Notes.tabs[Notes.current]
        if (t && editor.text !== t.text) editor.text = t.text
        armed = -1
    }
    Connections {
        target: Notes
        function onCurrentChanged() { root.loadCurrent() }
        function onTabsChanged() { root.loadCurrent() }
    }
    Component.onCompleted: loadCurrent()

    WindowChrome {
        id: chrome
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
                        font.bold: tab.open
                    }

                    TextInput {
                        id: renameField
                        visible: tab.editing
                        width: Math.max(Theme.fit(60), contentWidth + 2)
                        color: Theme.textStrong
                        selectionColor: Theme.selectedStroke
                        selectedTextColor: Theme.textStrong
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontSmall
                        font.bold: true
                        maximumLength: 40
                        function finish(keep) {
                            if (root.renaming !== tab.index) return
                            if (keep) Notes.rename(tab.index, text)
                            root.renaming = -1
                            editor.forceActiveFocus()
                        }
                        Keys.onReturnPressed: finish(true)
                        Keys.onEnterPressed: finish(true)
                        Keys.onEscapePressed: finish(false)
                        onActiveFocusChanged: if (!activeFocus) finish(true)
                    }

                    // delete, on the open tab only
                    Text {
                        visible: tab.open && !tab.editing
                        text: root.armed === tab.index ? "Delete?" : "×"
                        color: root.armed === tab.index ? Theme.alert
                            : closeMouse.containsMouse ? Theme.textStrong : Theme.subtext
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontSmall
                        font.bold: root.armed === tab.index

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            anchors.margins: -Theme.spaceS
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.removeTab(tab.index)
                        }
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
                editor.forceActiveFocus()
            }
        }
    }

    // --- the note --------------------------------------------------------------

    WindowPanel {
        id: page
        anchors.top: strip.bottom
        anchors.topMargin: Theme.spaceL
        x: Theme.windowPad
        width: root.width - Theme.windowPad * 2
        height: root.height - y - Theme.windowPad

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: Theme.panelPad
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
                selectByMouse: true
                persistentSelection: true
                color: Theme.text
                selectionColor: Theme.selectedStroke
                selectedTextColor: Theme.textStrong
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody

                onTextChanged: Notes.setText(Notes.current, text)
                onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)

                Text {
                    visible: editor.text === ""
                    text: "Write something..."
                    color: Theme.textDisabled
                    font: editor.font
                }

                Keys.onEscapePressed: root.close()
                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (!ctrl) return
                    if (event.key === Qt.Key_T) Notes.add()
                    else if (event.key === Qt.Key_W) root.removeTab(Notes.current)
                    else if (event.key === Qt.Key_Tab || event.key === Qt.Key_PageDown) Notes.step(1)
                    else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_PageUp) Notes.step(-1)
                    else return
                    event.accepted = true
                }
            }
        }

        ScrollBar {
            anchors.right: parent.right
            anchors.rightMargin: 2
            flickable: flick
        }
    }
}
