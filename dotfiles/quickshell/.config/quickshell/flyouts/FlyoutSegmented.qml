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
    // [{ value, text }], or plain values named by labelFor
    property var model: []
    property var labelFor: v => String(v)
    property var current
    property bool enabled: true
    // Equal segments across the whole row when there's no label beside it
    // (a flyout's own strip). Off, each segment hugs its text and the strip
    // sits at the right -- a Settings field's control slot.
    property bool fill: label === ""

    signal picked(var value)

    function valueOf(m) { return m !== null && typeof m === "object" && "value" in m ? m.value : m }
    function textOf(m) { return m !== null && typeof m === "object" && "text" in m ? m.text : labelFor(m) }

    width: (fill || label !== "") && parent ? parent.width : implicitWidth
    implicitWidth: segs.implicitWidth + Theme.borderWidth * 2
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
        width: root.fill ? parent.width : segs.implicitWidth + Theme.borderWidth * 2
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
                    readonly property bool on: root.valueOf(modelData) === root.current

                    height: segs.height
                    implicitWidth: segText.implicitWidth + Theme.spaceL * 2
                    // shared out evenly when the strip is stretched
                    width: root.fill ? (strip.width - Theme.borderWidth * 2) / rep.count : implicitWidth

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
                        text: root.textOf(seg.modelData)
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
                        onClicked: if (!seg.on) root.picked(root.valueOf(seg.modelData))
                    }
                }
            }
        }
    }
}
