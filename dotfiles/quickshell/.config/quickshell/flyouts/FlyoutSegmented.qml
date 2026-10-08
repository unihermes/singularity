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
    //   capsule    separate pills          glass   a frosted strip
    //   bevel      radio buttons           terminal  (•) and ( ) text
    //   underline  text tabs over a hairline, the chosen one underlined
    //   tabbed     folder tabs             ledger  ink boxes, the chosen inverted
    //   corners    bracketed cells
    readonly property string kind: Theme.style
    // drawn as a row of separate choices rather than one strip
    readonly property bool loose: ["capsule", "bevel", "terminal", "corners"].indexOf(kind) !== -1
    readonly property int gap: kind === "bevel" || kind === "terminal" ? Theme.spaceL
        : kind === "capsule" || kind === "corners" ? Theme.spaceS : 0
    readonly property int edge: loose || kind === "underline" || kind === "tabbed" ? 0
        : kind === "solid" || kind === "glass" ? Theme.spaceXs : Theme.borderWidth

    Rectangle {
        id: strip
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.fill ? parent.width : segs.implicitWidth + root.edge * 2
        height: Theme.rowHeight
        radius: root.kind === "ledger" ? 0 : root.kind === "solid" || root.kind === "glass" ? Theme.radius : Theme.radiusInner
        color: root.loose || root.kind === "underline" || root.kind === "tabbed" ? "transparent"
            : root.kind === "solid" ? Theme.meterTrack
            : root.kind === "glass" ? (Theme.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06))
            : Theme.controlFill("transparent")
        border.width: root.loose || root.kind === "solid" || root.kind === "underline" || root.kind === "tabbed" ? 0
            : Theme.controlBorder(Theme.stroke)
        border.color: root.kind === "glass" ? Theme.stroke : Theme.controlStroke(Theme.stroke)

        ControlEdge {
            visible: !root.loose && root.kind !== "solid" && root.kind !== "glass"
            sunken: true; radius: strip.radius
        }

        // underline and tabbed: the hairline the tabs stand on
        Rectangle {
            visible: root.kind === "underline" || root.kind === "tabbed"
            anchors.bottom: parent.bottom
            width: parent.width
            height: Theme.borderWidth
            color: Theme.stroke
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
                    // bevel's radio and terminal's (•) sit before the text
                    readonly property int lead: root.kind === "bevel" ? radio.width + Theme.spaceS
                        : root.kind === "terminal" ? termMark.implicitWidth : 0

                    height: segs.height
                    implicitWidth: lead + segText.implicitWidth + (root.kind === "bevel" || root.kind === "terminal" ? 0 : Theme.spaceL * 2)
                    // shared out evenly when the strip is stretched
                    width: root.fill && !(root.kind === "bevel" || root.kind === "terminal")
                        ? (strip.width - root.edge * 2 - root.gap * (rep.count - 1)) / rep.count : implicitWidth

                    // the segment's ground
                    Rectangle {
                        id: ground
                        anchors.fill: parent
                        anchors.margins: root.loose || root.edge === 0 || root.kind === "solid" || root.kind === "glass" ? 0 : 1
                        anchors.bottomMargin: root.kind === "tabbed" ? 0 : anchors.margins
                        visible: root.kind !== "bevel" && root.kind !== "terminal"
                        radius: root.kind === "capsule" ? height / 2
                            : root.kind === "ledger" || root.kind === "corners" || root.kind === "underline" ? 0
                            : root.kind === "tabbed" ? Theme.radiusSmall
                            : root.kind === "solid" || root.kind === "glass" ? Math.max(0, Theme.radius - 2)
                            : Theme.radiusSmall
                        bottomLeftRadius: root.kind === "tabbed" ? 0 : radius
                        bottomRightRadius: root.kind === "tabbed" ? 0 : radius
                        color: {
                            var k = root.kind
                            if (seg.on) {
                                if (k === "double" || k === "tabbed") return Theme.overlay
                                if (k === "ledger") return Theme.text
                                if (k === "glass") return Theme.isLight ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(1, 1, 1, 0.2)
                                if (k === "corners") return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                                if (k === "underline") return "transparent"
                                return Theme.accent
                            }
                            if (seg.hot) return Theme.hoverFillSoft
                            return k === "capsule" ? Theme.overlay : "transparent"
                        }
                        border.width: seg.on && (root.kind === "double" || root.kind === "tabbed") ? Theme.borderWidth
                            : seg.on && root.kind === "channel" ? Theme.channelGrooveWidth : 0
                        border.color: root.kind === "channel" ? Theme.channelGroove
                            : root.kind === "tabbed" ? Theme.stroke : Theme.accent

                        CornerMarks {
                            visible: root.kind === "corners"
                            color: seg.on ? Theme.accent : seg.hot ? Theme.textStrong : Theme.muted
                        }

                        // underline: the chosen tab's accent line
                        Rectangle {
                            visible: root.kind === "underline" && seg.on
                            x: Theme.spaceM
                            y: Theme.opt("over") ? 0 : parent.height - height
                            width: parent.width - Theme.spaceM * 2
                            height: Math.max(2, Theme.borderWidth * 2)
                            radius: height / 2
                            color: Theme.accent
                        }
                        // tabbed: the chosen tab opens into the hairline below it
                        Rectangle {
                            visible: root.kind === "tabbed" && seg.on
                            anchors.bottom: parent.bottom
                            x: Theme.borderWidth
                            width: parent.width - Theme.borderWidth * 2
                            height: Theme.borderWidth
                            color: Theme.overlay
                        }
                    }

                    // the hairline between joined segments; ledger's is ink
                    Rectangle {
                        visible: seg.index > 0 && !root.loose && root.kind !== "underline" && root.kind !== "tabbed"
                            && root.kind !== "solid" && root.kind !== "glass"
                        width: Theme.borderWidth
                        height: root.kind === "ledger" ? parent.height : parent.height - Theme.spaceS * 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.stroke
                    }

                    // bevel's radio button
                    Rectangle {
                        id: radio
                        visible: root.kind === "bevel"
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(Theme.switchHeight * 0.8)
                        height: width
                        radius: width / 2
                        color: Theme.base
                        border.width: Theme.borderWidth
                        border.color: seg.hot ? Theme.strokeHover : Theme.bevelDark
                        Rectangle {
                            visible: seg.on
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.4)
                            height: width
                            radius: width / 2
                            color: Theme.textStrong
                        }
                    }

                    // terminal's (•) / ( )
                    Text {
                        id: termMark
                        visible: root.kind === "terminal"
                        anchors.verticalCenter: parent.verticalCenter
                        text: seg.on ? "(•) " : "( ) "
                        color: seg.on ? Theme.accent : Theme.muted
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontSmall
                    }

                    Text {
                        id: segText
                        anchors.verticalCenter: parent.verticalCenter
                        x: seg.lead > 0 ? seg.lead : Math.round((parent.width - width) / 2)
                        text: root.textOf(seg.modelData)
                        color: {
                            var k = root.kind
                            if (seg.on) {
                                if (k === "ledger") return Theme.panel
                                if (k === "double" || k === "glass" || k === "bevel" || k === "terminal"
                                        || k === "underline") return Theme.textStrong
                                if (k === "tabbed" || k === "corners") return Theme.accent
                                return Theme.textOnAccent
                            }
                            return seg.hot ? Theme.textStrong : k === "underline" || k === "tabbed" ? Theme.subtext : Theme.text
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
