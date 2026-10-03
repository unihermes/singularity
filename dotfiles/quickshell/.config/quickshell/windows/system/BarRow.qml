// Singularity - Quickshell
// ~/.config/quickshell/windows/system/BarRow.qml
//
// A label and its figure on one line with a full-width meter under them,
// for anything with a name of its own: a filesystem's mount point and
// device, a sensor, the battery's capacity left.

import QtQuick
import "../../services"
import "../../flyouts"

Item {
    id: root

    property string label: ""
    property string sublabel: ""
    property string value: ""
    property real fraction: 0
    property bool critical: false

    width: parent ? parent.width : 0
    implicitHeight: top.implicitHeight + Theme.spaceS + Theme.meterHeight

    Item {
        id: top
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: Theme.chipHeight

        Text {
            id: labelText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Theme.text
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }

        Text {
            anchors.left: labelText.right
            anchors.leftMargin: Theme.spaceL
            anchors.right: valueText.left
            anchors.rightMargin: Theme.spaceL
            anchors.baseline: labelText.baseline
            text: root.sublabel
            elide: Text.ElideMiddle
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }

        Text {
            id: valueText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.value
            color: root.critical ? Theme.alert : Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }
    }

    Meter {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        fraction: root.fraction
        fillColor: root.critical ? Theme.alert : Theme.meterFill
    }
}
