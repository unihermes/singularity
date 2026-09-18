// Neutrino - Quickshell
// ~/.config/quickshell/FailedFlyout.qml
//
// Split out of shell.qml. Self-contained: only needs the FailedUnits singleton.

import QtQuick
import "../services"

FlyoutPanel {
    flyout: "failed"
    menuWidth: 300

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
            height: 46

            Text {
                id: unitName
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 2
                text: modelData.name
                elide: Text.ElideMiddle
                color: Theme.bright
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                text: modelData.user ? "user" : "system"
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }

            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                spacing: 4
                FlyoutChip { text: "Log";     onClicked: { FailedUnits.showLog(modelData); scope.openFlyout = "" } }
                FlyoutChip { text: "Restart"; onClicked: FailedUnits.restart(modelData) }
                FlyoutChip { text: "Clear";   onClicked: FailedUnits.clear(modelData) }
            }
        }
    }
}
