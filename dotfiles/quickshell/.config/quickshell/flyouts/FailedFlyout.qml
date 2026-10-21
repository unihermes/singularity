// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FailedFlyout.qml
//
// A line per failed unit with its log, restart and clear as icons, then
// the count and Clear all. Self-contained: only needs FailedUnits.

import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "failed"
    menuWidth: Theme.flyoutMenuWidth

    FlyoutHeading { text: "FAILED SERVICES" }

    FlyoutRow {
        visible: FailedUnits.count === 0
        label: "Nothing has failed"
        enabled: false
    }

    Repeater {
        model: FailedUnits.units

        Item {
            required property var modelData
            width: parent ? parent.width : 0
            implicitHeight: Theme.rowHeight

            Text {
                anchors.left: parent.left
                anchors.right: buttons.left
                anchors.rightMargin: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name + (modelData.user ? "  user" : "")
                elide: Text.ElideMiddle
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }

            Row {
                id: buttons
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceXs
                IconButton { icon: "󰦨"; onClicked: { FailedUnits.showLog(modelData); scope.openFlyout = "" } }
                IconButton { icon: "󰑐"; onClicked: FailedUnits.restart(modelData) }
                IconButton { icon: "󰅖"; onClicked: FailedUnits.clear(modelData) }
            }
        }
    }

    FlyoutDivider { visible: FailedUnits.count > 0 }

    Item {
        visible: FailedUnits.count > 0
        width: parent.width
        implicitHeight: Theme.chipHeight

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: FailedUnits.count + " failed"
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
        FlyoutChip {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Clear all"
            confirmText: "Clear " + FailedUnits.count + "?"
            onClicked: FailedUnits.units.slice().forEach(u => FailedUnits.clear(u))
        }
    }
}
