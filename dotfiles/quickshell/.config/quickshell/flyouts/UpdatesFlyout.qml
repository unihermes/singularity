// Neutrino - Quickshell
// ~/.config/quickshell/UpdatesFlyout.qml
//
// Split out of shell.qml. Self-contained: only needs the Updates singleton.

import QtQuick
import "../services"

FlyoutPanel {
    flyout: "updates"
    menuWidth: 300

    FlyoutHeading {
        text: "UPDATES  " + Updates.count
            + (Updates.aurCount > 0 ? "  (" + Updates.aurCount + " AUR)" : "")
    }

    ListView {
        id: updList
        width: parent.width
        height: Math.min(contentHeight, 12 * 22)
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: Updates.packages

        delegate: Item {
            required property var modelData
            width: updList.width
            height: 22

            Text {
                anchors.left: parent.left
                anchors.right: ver.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name + (modelData.aur ? "  ·aur" : "")
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }
            Text {
                id: ver
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 150)
                horizontalAlignment: Text.AlignRight
                text: modelData.to
                elide: Text.ElideLeft
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    FlyoutDivider {}

    FlyoutRow {
        label: "Update now"
        trailing: "󰚰"
        onActivated: {
            Updates.update()
            scope.openFlyout = ""
        }
    }

    FlyoutRow {
        label: Updates.checking ? "Checking..." : "Check again"
        trailing: Updates.lastChecked ? Qt.formatTime(Updates.lastChecked, "HH:mm") : ""
        enabled: !Updates.checking
        onActivated: Updates.refresh()
    }
}
