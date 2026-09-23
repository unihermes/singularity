// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutSegmented.qml
//
// A setting with two to four short choices, all on show: a label on the
// left and the choices as one joined strip of segments on the right, the
// current one lit. One click to any choice, where FlyoutRow's click-to-cycle
// can cost two -- and you can see what the others are before you pick.
//
//   FlyoutSegmented {
//       label: "Position"
//       model: [{ value: "top", text: "Top" }, { value: "bottom", text: "Bottom" }]
//       current: Settings.barPosition
//       onPicked: v => Settings.set("barPosition", v)
//   }

import QtQuick
import "../services"

Item {
    id: root

    property string label: ""
    // [{ value, text }]
    property var model: []
    property var current
    property bool enabled: true

    signal picked(var value)

    width: parent ? parent.width : 0
    implicitHeight: Theme.rowHeight
    opacity: enabled ? 1 : 0.5

    Text {
        anchors.left: parent.left
        anchors.right: strip.left
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        visible: root.label !== ""
        text: root.label
        elide: Text.ElideRight
        color: Theme.text
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }

    // the strip: one stroke round the lot, a hairline between segments
    Rectangle {
        id: strip
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // full width when there's no label to share the row with
        width: root.label === "" ? parent.width : segs.implicitWidth + Theme.borderWidth * 2
        height: Theme.chipHeight
        radius: Theme.radiusInner
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.stroke

        Row {
            id: segs
            x: Theme.borderWidth
            y: Theme.borderWidth
            height: parent.height - Theme.borderWidth * 2

            Repeater {
                id: rep
                model: root.model

                Item {
                    id: seg
                    required property var modelData
                    required property int index
                    readonly property bool on: modelData.value === root.current

                    height: segs.height
                    implicitWidth: segText.implicitWidth + Theme.spaceL * 2
                    // shared out evenly when the strip is stretched
                    width: root.label === "" ? (strip.width - Theme.borderWidth * 2) / rep.count : implicitWidth

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: Theme.radiusSmall
                        color: seg.on ? Theme.selectedFill
                            : segMouse.containsMouse ? Theme.hoverFillSoft : "transparent"
                        border.width: seg.on ? Theme.borderWidth : 0
                        border.color: Theme.selectedStroke
                    }

                    Rectangle {
                        visible: seg.index > 0
                        width: Theme.borderWidth
                        height: parent.height - Theme.spaceS * 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.stroke
                    }

                    Text {
                        id: segText
                        anchors.centerIn: parent
                        text: seg.modelData.text
                        color: seg.on || segMouse.containsMouse ? Theme.textStrong : Theme.text
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontSmall
                    }

                    MouseArea {
                        id: segMouse
                        anchors.fill: parent
                        enabled: root.enabled
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!seg.on) root.picked(seg.modelData.value)
                    }
                }
            }
        }
    }
}
