// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Launcher.qml
//
// The search-first launcher that replaces wofi, drawn with the bar's own
// theme. Two modes, switched with Tab:
//   apps       CTRL+SPACE -- desktop entries (services/Apps.qml)
//   clipboard  SUPER+H    -- cliphist history (services/Clipboard.qml)
// Both arrive as `qs ipc call launcher toggle <mode>` (shell.qml), which
// sets scope.launcherMode and opens "launcher" in the shared openFlyout.

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "../services"

OverlayWindow {
    id: root

    readonly property bool open: scope.openFlyout === "launcher"
    readonly property bool clipMode: root.scope.launcherMode === "clipboard"
    property string query: ""

    readonly property var items: {
        if (!open) return []
        if (!clipMode) return Apps.list(query)
        var q = query.trim().toLowerCase()
        return q === "" ? Clipboard.history
            : Clipboard.history.filter(e => e.preview.toLowerCase().indexOf(q) !== -1)
    }

    readonly property int visibleRows: 12

    // Rows scroll under a still pointer when the arrow keys move the list,
    // and that counts as hovering a new row. Only real pointer movement
    // may move the selection, or it snaps back to wherever the mouse sits.
    property point lastPointer: Qt.point(-1, -1)
    function pointerMoved(item, x, y) {
        var p = item.mapToGlobal(x, y)
        if (p.x === lastPointer.x && p.y === lastPointer.y) return false
        lastPointer = p
        return true
    }

    function requestClose() { scope.openFlyout = "" }

    function reset() {
        query = ""
        search.text = ""
        list.currentIndex = 0
        if (clipMode) Clipboard.refresh()
        Qt.callLater(search.forceFocus)
    }

    function activate(item) {
        if (!item) return
        requestClose()
        if (clipMode) Clipboard.select(item)
        else Apps.launch(item)
    }

    function removeCurrent() {
        if (!clipMode || list.count === 0) return
        var i = list.currentIndex
        Clipboard.remove(items[i])
        Qt.callLater(() => list.currentIndex = Math.min(i, list.count - 1))
    }

    onOpenChanged: if (open) reset()
    onClipModeChanged: if (open) reset()

    visible: open
    focusMode: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    layerNamespace: "neutrino-flyout"

    MouseArea {
        anchors.fill: parent
        onClicked: root.requestClose()
    }

    PanelFrame {
        id: box
        width: Theme.fs(760)
        height: body.implicitHeight + Theme.sp(40)
        anchors.horizontalCenter: parent.horizontalCenter
        // pinned from the top so the box grows downward as the list
        // fills, instead of re-centring on every keystroke
        y: Math.round(root.height * 0.18)

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            id: body
            x: Theme.sp(22)
            y: Theme.sp(20)
            width: parent.width - Theme.sp(44)
            spacing: Theme.spaceM

            Item {
                width: parent.width
                height: title.implicitHeight

                Text {
                    id: title
                    text: Theme.heading(root.clipMode ? "CLIPBOARD" : "APPLICATIONS")
                    color: Theme.headingColor
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                    font.bold: Theme.headingBold
                    font.letterSpacing: Theme.headingSpacing
                }

                Text {
                    anchors.right: parent.right
                    text: "Tab  " + (root.clipMode ? "Applications" : "Clipboard")
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                }
            }

            FlyoutInput {
                id: search
                width: parent.width
                echoPassword: false
                placeholder: root.clipMode ? "Search clipboard" : "Search applications"
                onTextChanged: {
                    root.query = text
                    list.currentIndex = 0
                }
                onAccepted: if (list.count > 0) root.activate(root.items[list.currentIndex])
                onDownPressed: if (list.currentIndex < list.count - 1) list.currentIndex++
                onUpPressed: if (list.currentIndex > 0) list.currentIndex--
                onEscapePressed: root.requestClose()
                onTabPressed: root.scope.launcherMode = root.clipMode ? "apps" : "clipboard"
                onShiftDeletePressed: root.removeCurrent()
            }

            Text {
                visible: list.count === 0
                width: parent.width
                height: Theme.rowHeightTall
                verticalAlignment: Text.AlignVCenter
                text: root.query !== "" ? "No matches"
                    : root.clipMode ? "Clipboard history is empty" : "No applications"
                color: Theme.textDisabled
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }

            ListView {
                id: list
                visible: count > 0
                width: parent.width
                height: Math.min(count, root.visibleRows) * (Theme.rowHeightTall + spacing)
                clip: true
                spacing: Theme.spaceXs
                boundsBehavior: Flickable.StopAtBounds
                model: root.items
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: Theme.rowHeightTall

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusInner
                        color: row.ListView.isCurrentItem ? Theme.hoverFill : "transparent"
                    }

                    IconImage {
                        id: appIcon
                        visible: !root.clipMode
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spaceS
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: Theme.fs(18)
                        source: root.clipMode ? "" : Quickshell.iconPath(row.modelData.icon, true)
                    }

                    Text {
                        id: glyph
                        visible: root.clipMode
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spaceS
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.fs(18)
                        horizontalAlignment: Text.AlignHCenter
                        text: root.clipMode && row.modelData.isImage ? "󰋩" : "󰅍"
                        color: Theme.subtext
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontBody
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spaceS + Theme.fs(18) + Theme.sp(10)
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spaceS
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.clipMode
                            ? (row.modelData.isImage ? "Image" : row.modelData.preview)
                            : row.modelData.name
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        color: row.ListView.isCurrentItem ? Theme.textStrong : Theme.text
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontBody
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: mouse => {
                            if (root.pointerMoved(rowMouse, mouse.x, mouse.y)) list.currentIndex = row.index
                        }
                        onClicked: root.activate(row.modelData)
                    }
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignRight
                text: root.clipMode
                    ? "Enter copy   Shift+Del remove   Esc close"
                    : "Enter open   Esc close"
                color: Theme.textDisabled
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }
        }
    }
}
