// Singularity - Quickshell
// ~/.config/quickshell/settings/FingerHands.qml
//
// Two hands seen from the back, their fingers buttons named as fprintd names
// them (left-thumb, right-index-finger, ...): lit when enrolled, alert-red
// while armed to remove, and filling from the palm while one is enrolled.

import QtQuick
import "../services"

Row {
    id: root

    property var enrolled: []
    property string enrolling: ""
    property real progress: 0
    property string armed: ""
    signal picked(string finger)

    readonly property real u: Theme.fit(100) / 100
    spacing: 40 * u

    Repeater {
        model: ["left", "right"]

        Item {
            id: hand
            required property string modelData
            readonly property bool isLeft: modelData === "left"
            readonly property real palmX: (isLeft ? 14 : 66) * root.u

            width: 200 * root.u
            height: 150 * root.u

            // little to index on the left hand, index to little on the right
            // (the thumbs sit outside them); each runs 16 under the palm
            readonly property var fingers: {
                var lens = { index: 62, middle: 70, ring: 62, little: 48 }
                var order = isLeft ? ["little", "ring", "middle", "index"] : ["index", "middle", "ring", "little"]
                var out = order.map((n, i) => ({ name: modelData + "-" + n + "-finger",
                    x: palmX / root.u + 4 + i * 27, y: 100 - lens[n], len: lens[n] + 16, tilt: 0 }))
                out.push({ name: modelData + "-thumb", x: palmX / root.u + (isLeft ? 104 : -10), y: 96, len: 50,
                    tilt: isLeft ? 38 : -38 })
                return out
            }

            Repeater {
                model: hand.fingers

                Rectangle {
                    id: finger
                    required property var modelData
                    readonly property bool going: root.enrolling === modelData.name
                    readonly property bool lit: root.enrolled.indexOf(modelData.name) >= 0
                    readonly property bool isArmed: root.armed === modelData.name
                    readonly property real under: 16 * root.u

                    x: modelData.x * root.u
                    y: modelData.y * root.u
                    width: 22 * root.u
                    height: modelData.len * root.u
                    radius: width / 2
                    rotation: modelData.tilt
                    transformOrigin: Item.Bottom
                    color: isArmed ? Theme.alert : lit ? Theme.accent : Theme.surface
                    border.width: Math.max(1, Theme.borderWidth)
                    border.color: isArmed ? Theme.alert : lit || going ? Theme.accent
                        : hover.hovered ? Theme.subtext : Theme.muted

                    // the touches so far, up from the palm's edge
                    Rectangle {
                        visible: finger.going
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: parent.border.width
                        height: finger.under + (finger.height - finger.under - 2 * parent.border.width) * root.progress
                        radius: width / 2
                        color: Theme.accent
                        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }

                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.picked(finger.modelData.name) }
                }
            }

            Rectangle {
                x: hand.palmX
                y: 96 * root.u
                width: 120 * root.u
                height: 50 * root.u
                radius: 16 * root.u
                color: Theme.surface
                border.width: Math.max(1, Theme.borderWidth)
                border.color: Theme.muted

                Text {
                    anchors.centerIn: parent
                    text: hand.isLeft ? "Left" : "Right"
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }
            }
        }
    }
}
