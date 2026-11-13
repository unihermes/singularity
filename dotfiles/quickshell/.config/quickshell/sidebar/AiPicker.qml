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

    anchors.fill: parent
    z: 40

    MouseArea {
        anchors.fill: parent
        onPressed: root.dismissed()
    }

    PanelFrame {
        readonly property point origin: root.target.mapToItem(root, 0, 0)
        width: Math.min(root.width, root.menuWidth)
        height: Math.min(list.contentHeight, Theme.rowHeight * 5) + Theme.spaceXs * 2
        x: Math.max(0, Math.min(root.width - width, origin.x))
        y: Math.max(0, Math.min(root.height - height,
            root.above ? origin.y - height - Theme.spaceXs
                : origin.y + root.target.height + Theme.spaceXs))
        ground: Theme.surface

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: Theme.spaceXs
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
