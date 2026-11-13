// A sidebar picker anchored to the control that opened it.
import QtQuick
import "../services"
import "../flyouts"

Item {
    id: root

    required property Item target
    property var choices: []
    property string current: ""
    property real menuWidth: Theme.fit(180)
    property bool above: false
    signal picked(string value)
    signal dismissed()
    property point origin: Qt.point(0, 0)

    function place() { if (visible && target) origin = target.mapToItem(root, 0, 0) }
    function showCurrent() {
        var i = choices.findIndex(choice => choice.value === current)
        if (i >= 0) list.positionViewAtIndex(i, ListView.Contain)
    }
    onVisibleChanged: if (visible) { Qt.callLater(place); Qt.callLater(showCurrent) }
    onCurrentChanged: if (visible) Qt.callLater(showCurrent)
    onWidthChanged: place()
    onHeightChanged: place()

    Timer {
        running: root.visible
        repeat: true
        interval: 100
        onTriggered: root.place()
    }

    anchors.fill: parent
    z: 40

    MouseArea {
        anchors.fill: parent
        onPressed: root.dismissed()
    }

    PanelFrame {
        width: Math.min(root.width, root.menuWidth)
        height: Math.min(list.contentHeight, Theme.rowHeight * 5) + Theme.spaceM * 2
        x: Math.max(0, Math.min(root.width - width, root.origin.x))
        y: Math.max(0, Math.min(root.height - height,
            root.above ? root.origin.y - height - Theme.spaceXs
                : root.origin.y + root.target.height + Theme.spaceXs))
        ground: Theme.panelFill

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: Theme.spaceM
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.choices
            delegate: FlyoutRow {
                required property var modelData
                width: ListView.view.width - (list.contentHeight > list.height ? Theme.scrollGutter : 0)
                label: modelData.text
                leadingImage: modelData.icon || ""
                highlighted: modelData.value === root.current
                onActivated: root.picked(modelData.value)
            }
            ScrollBar { flickable: list; anchors.right: parent.right }
        }
    }
}
