// Singularity - Quickshell
// ~/.config/quickshell/flyouts/LinkLine.qml
//
// An opened notification's buttons as links in the accent, a dot between,
// wrapping onto more lines. `links`: [{ text, primary, run }], the primary
// one in the strong weight.

import QtQuick
import "../services"

Flow {
    id: root

    property var links: []

    width: parent ? parent.width : 0
    spacing: Theme.spaceS

    Repeater {
        model: root.links

        Row {
            id: linkItem
            required property var modelData
            required property int index
            spacing: Theme.spaceS

            Text {
                visible: linkItem.index > 0
                text: "·"
                color: Theme.muted
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }

            Text {
                text: linkItem.modelData.text
                color: linkMouse.containsMouse ? Theme.bright : Theme.accent
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
                font.weight: linkItem.modelData.primary ? Theme.weightStrong : Theme.weightBody
                font.underline: linkMouse.containsMouse

                MouseArea {
                    id: linkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: linkItem.modelData.run()
                }
            }
        }
    }
}
