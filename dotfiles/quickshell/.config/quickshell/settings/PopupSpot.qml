// Singularity - Quickshell
// ~/.config/quickshell/settings/PopupSpot.qml
//
// Where notification popups appear, picked on a small screen: six spots,
// top or bottom by left, centre or right, with a popup card drawn in the
// one chosen. The bar is drawn where it sits, since the popups clear it.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../services"

Item {
    id: root

    property string posX: Settings.notifPositionX
    property string posY: Settings.notifPositionY
    signal picked(string x, string y)

    readonly property bool barBottom: Settings.barPosition === "bottom"
    readonly property real barH: Math.round(height * 0.09)

    implicitWidth: Theme.fit(150)
    implicitHeight: Math.round(implicitWidth * 10 / 16)

    // the card's corner for a spot
    function cardX(x) { return x === "left" ? width * 0.03 : x === "center" ? (width - card.width) / 2 : width * 0.97 - card.width }
    function cardY(y) {
        return y === "top" ? (barBottom ? 0 : barH) + height * 0.04
            : height - (barBottom ? barH : 0) - height * 0.04 - card.height
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: Theme.base
        border.width: 1
        border.color: Theme.border

        Image {
            anchors.fill: parent
            source: "file://" + Quickshell.env("HOME") + "/.local/state/singularity/current-wallpaper"
            sourceSize.width: 320
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.55
        }

        Rectangle {
            y: root.barBottom ? parent.height - root.barH : 0
            width: parent.width
            height: root.barH
            color: Theme.bar
        }
    }

    // the spot under the pointer, outlined
    Rectangle {
        id: ghost
        visible: hoverX !== "" && (hoverX !== root.posX || hoverY !== root.posY)
        property string hoverX: ""
        property string hoverY: ""
        x: root.cardX(hoverX)
        y: root.cardY(hoverY)
        width: card.width
        height: card.height
        radius: Math.min(Theme.radiusSmall, height / 4)
        color: "transparent"
        border.width: 1
        border.color: Theme.subtext
    }

    Rectangle {
        id: card
        width: Math.round(root.width * 0.31)
        height: Math.round(root.height * 0.17)
        x: root.cardX(root.posX)
        y: root.cardY(root.posY)
        radius: Math.min(Theme.radiusSmall, height / 4)
        color: Theme.surface
        border.width: 1
        border.color: Theme.muted
        Behavior on x { NumberAnimation { duration: Theme.dur(140); easing.type: Theme.ease } }
        Behavior on y { NumberAnimation { duration: Theme.dur(140); easing.type: Theme.ease } }

        // the selected-row tick, and two lines of text
        Rectangle { x: 1; y: parent.height * 0.2; width: 2; height: parent.height * 0.6; color: Theme.accent }
        Rectangle { x: parent.width * 0.14; y: parent.height * 0.28; width: parent.width * 0.62; height: 2; radius: 1; color: Theme.subtext }
        Rectangle { x: parent.width * 0.14; y: parent.height * 0.58; width: parent.width * 0.42; height: 2; radius: 1; color: Theme.muted }
    }

    Repeater {
        model: [["top", "left"], ["top", "center"], ["top", "right"], ["bottom", "left"], ["bottom", "center"], ["bottom", "right"]]

        MouseArea {
            required property var modelData
            required property int index
            x: (index % 3) * root.width / 3
            y: index < 3 ? 0 : root.height / 2
            width: root.width / 3
            height: root.height / 2
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
                if (containsMouse) { ghost.hoverY = modelData[0]; ghost.hoverX = modelData[1] }
                else if (ghost.hoverY === modelData[0] && ghost.hoverX === modelData[1]) ghost.hoverX = ""
            }
            onClicked: root.picked(modelData[1], modelData[0])
        }
    }
}
