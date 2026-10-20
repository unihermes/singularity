// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutSegmented.qml
//
// Two to four short choices as one joined strip, the current one lit.
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
    // equal segments across the row when there's no label; else they hug
    // their text at the right (a Settings field)
    property bool fill: label === ""

    signal picked(var value)

    function valueOf(m) { return m !== null && typeof m === "object" && "value" in m ? m.value : m }
    function textOf(m) { return m !== null && typeof m === "object" && "text" in m ? m.text : labelFor(m) }

    width: (fill || label !== "") && parent ? parent.width : implicitWidth
    implicitWidth: segs.implicitWidth + root.edge * 2
    implicitHeight: Theme.rowHeightTall
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
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontBody
    }

    // How the strip is drawn is the style's (Theme.style):
    //   channel    a channel strip; the chosen one accent in its groove
    //   double     a stroked strip; the chosen one ringed in accent
    //   solid      a sunken track with a raised accent pill
    //   glass      a frosted strip
    //   flat       separate flat blocks
    readonly property string kind: Theme.style
    // drawn as a row of separate choices rather than one strip
    readonly property bool loose: kind === "flat"
    readonly property int gap: loose ? Theme.spaceXs : 0
    readonly property int edge: loose ? 0
        : kind === "solid" || kind === "glass" ? Theme.spaceXs : Theme.borderWidth

    Rectangle {
        id: strip
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.fill ? parent.width : segs.implicitWidth + root.edge * 2
        height: Theme.rowHeight
        radius: root.kind === "solid" || root.kind === "glass" ? Theme.radius : Theme.radiusInner
        color: root.loose ? "transparent"
            : root.kind === "solid" ? Theme.meterTrack
            : root.kind === "glass" ? (Theme.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06))
            : Theme.controlFill("transparent")
        border.width: root.loose || root.kind === "solid" ? 0
            : Theme.controlBorder(Theme.stroke)
        border.color: root.kind === "glass" ? Theme.stroke : Theme.controlStroke(Theme.stroke)

        ControlEdge {
            visible: !root.loose && root.kind !== "solid" && root.kind !== "glass"
            sunken: true; radius: strip.radius
        }

        Row {
            id: segs
            x: root.edge
            y: root.edge
            height: parent.height - root.edge * 2
            spacing: root.gap

            Repeater {
                id: rep
                model: root.model

                Item {
                    id: seg
                    required property var modelData
                    required property int index
                    readonly property bool on: root.valueOf(modelData) === root.current
                    readonly property bool hot: segMouse.containsMouse

                    height: segs.height
                    implicitWidth: segText.implicitWidth + Theme.spaceL * 2
                    // shared out evenly when the strip is stretched
                    width: root.fill
                        ? (strip.width - root.edge * 2 - root.gap * (rep.count - 1)) / rep.count : implicitWidth

                    // the segment's ground
                    Rectangle {
                        id: ground
                        anchors.fill: parent
                        anchors.margins: root.loose || root.edge === 0 || root.kind === "solid" || root.kind === "glass" ? 0 : 1
                        radius: root.kind === "solid" || root.kind === "glass" ? Math.max(0, Theme.radius - 2)
                            : Theme.radiusSmall
                        color: {
                            var k = root.kind
                            if (seg.on) {
                                if (k === "double") return Theme.overlay
                                if (k === "glass") return Theme.isLight ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(1, 1, 1, 0.2)
                                return Theme.accent
                            }
                            if (k === "flat") return seg.hot ? Theme.muted : Theme.overlay
                            return seg.hot ? Theme.hoverFillSoft : "transparent"
                        }
                        border.width: seg.on && root.kind === "double" ? Theme.borderWidth
                            : seg.on && root.kind === "channel" ? Theme.channelGrooveWidth : 0
                        border.color: root.kind === "channel" ? Theme.channelGroove : Theme.accent
                    }

                    // the hairline between joined segments
                    Rectangle {
                        visible: seg.index > 0 && !root.loose
                            && root.kind !== "solid" && root.kind !== "glass"
                        width: Theme.borderWidth
                        height: parent.height - Theme.spaceS * 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.stroke
                    }

                    Text {
                        id: segText
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round((parent.width - width) / 2)
                        text: root.textOf(seg.modelData)
                        color: {
                            var k = root.kind
                            if (seg.on) {
                                if (k === "double" || k === "glass") return Theme.textStrong
                                return Theme.textOnAccent
                            }
                            return seg.hot ? Theme.textStrong : Theme.text
                        }
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
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
