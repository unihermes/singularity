// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/ModuleArt.qml
//
// The Bar and Motion tabs' tile pictures: each draws one value of a
// setting the way the shell draws it, small, in the theme's colours.
// `kind` names the setting (workspaceStyle, windowStyle, clockStyle,
// controlIcon, vizStyle, windowAnim); `value`
// is the tile's own value, from the Loader it sits in.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

Item {
    id: art
    property string kind: ""
    readonly property string value: parent && parent.value !== undefined ? parent.value : ""
    readonly property var appColours: ["#e66a3c", "#3c8ee6", "#5ac36e", "#c8a23c"]
    width: Theme.fs(150)
    height: Theme.fs(28)

    // --- workspaces: five, the second current, the fourth occupied ---
    Row {
        visible: art.kind === "workspaceStyle"
        anchors.centerIn: parent
        spacing: Theme.fs(4)
        Repeater {
            model: art.value === "names" ? ["web", "code", "chat"] : art.value === "roman" ? ["I", "II", "III", "IV", "V"] : 5
            Item {
                id: ws
                required property int index
                required property var modelData
                readonly property bool cur: index === 1
                readonly property color ink: cur ? Theme.accent : index === 3 ? Theme.subtext : Theme.muted
                anchors.verticalCenter: parent.verticalCenter
                width: wsBox.width
                height: Theme.fs(14)

                Item {
                    id: wsBox
                    anchors.verticalCenter: parent.verticalCenter
                    width: childrenRect.width
                    height: childrenRect.height
                    Rectangle {
                        visible: art.value === "pills" || art.value === "dots" || art.value === "lines" || art.value === "blocks"
                        width: art.value === "pills" ? (ws.cur ? Theme.fs(16) : Theme.fs(6))
                            : art.value === "lines" ? Theme.fs(9) : art.value === "blocks" ? Theme.fs(9) : Theme.fs(7)
                        height: art.value === "lines" ? 2 : art.value === "blocks" ? Theme.fs(9) : art.value === "pills" ? Theme.fs(6) : Theme.fs(7)
                        radius: art.value === "blocks" || art.value === "lines" ? Math.min(1, Theme.radius) : Theme.pill(height)
                        color: art.value === "blocks" && !ws.cur && ws.index !== 3 ? "transparent" : ws.ink
                        border.width: art.value === "blocks" ? 1 : 0
                        border.color: Theme.muted
                    }
                    Text {
                        visible: art.value === "numbers" || art.value === "roman" || art.value === "names"
                        text: art.value === "numbers" ? String(ws.index + 1) : String(ws.modelData)
                        color: ws.cur ? Theme.textStrong : ws.index === 3 ? Theme.subtext : Theme.muted
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontCaption
                        font.weight: Theme.weightBody
                    }
                    Rectangle {
                        visible: art.value === "apps"
                        width: Theme.fs(10)
                        height: width
                        radius: 2
                        color: ws.index < 4 ? art.appColours[ws.index] : Theme.muted
                        opacity: ws.index === 2 || ws.index === 4 ? 0.35 : 1
                        Rectangle {
                            visible: ws.cur
                            anchors.top: parent.bottom
                            anchors.topMargin: 2
                            width: parent.width
                            height: 2
                            color: Theme.accent
                        }
                    }
                }
            }
        }
    }

    // --- open windows: three apps, the first focused ---
    Row {
        id: winRow
        visible: art.kind === "windowStyle"
        anchors.centerIn: parent
        spacing: art.value === "segmented" ? 0 : Theme.fs(5)
        Repeater {
            model: 3
            Item {
                id: wn
                required property int index
                readonly property bool foc: index === 0
                readonly property color appColour: art.appColours[index]
                readonly property real iconSize: art.value === "lift" ? (foc ? Theme.fs(15) : Theme.fs(9))
                    : art.value === "rings" ? Theme.fs(9) : Theme.fs(11)
                anchors.verticalCenter: parent.verticalCenter
                width: wnRow.width + (art.value === "segmented" || art.value === "liquid" ? Theme.fs(8)
                    : art.value === "rings" || art.value === "viewfinder" || art.value === "tint" ? Theme.fs(6) : 0)
                height: Theme.fs(22)

                // a ground: inset's well, the lit segment, liquid's blob
                Rectangle {
                    anchors.fill: parent
                    visible: wn.foc && ["inset", "segmented", "liquid"].indexOf(art.value) !== -1
                    radius: art.value === "liquid" ? height / 2 : Theme.radiusSmall
                    color: art.value === "inset" ? Theme.base
                        : Qt.alpha(Theme.accent, art.value === "liquid" ? 0.45 : 0.3)
                    border.width: art.value === "inset" ? 1 : 0
                    border.color: Theme.stroke
                }
                // segmented: the divider between two unlit segments
                Rectangle {
                    visible: art.value === "segmented" && wn.index > 1
                    width: 1
                    height: parent.height
                    color: Theme.stroke
                }

                // tint's tile in the app's colour, rings' ring
                Rectangle {
                    visible: art.value === "tint" || (art.value === "rings" && wn.foc)
                    anchors.centerIn: parent
                    width: wn.width
                    height: width
                    radius: art.value === "rings" ? width / 2 : Theme.radiusSmall
                    color: art.value === "tint" ? Qt.alpha(wn.appColour, wn.foc ? 0.55 : 0.18) : "transparent"
                    border.width: art.value === "rings" ? 1.5 : 0
                    border.color: Theme.accent
                }

                // viewfinder's corners round the focused icon
                Repeater {
                    model: art.value === "viewfinder" && wn.foc ? 4 : 0
                    Item {
                        required property int index
                        readonly property bool east: index % 2 === 1
                        readonly property bool south: index > 1
                        x: east ? wn.width - width : 0
                        y: (wn.height - wn.width) / 2 + (south ? wn.width - height : 0)
                        width: Theme.fs(4)
                        height: width
                        Rectangle { y: parent.south ? parent.height - height : 0; width: parent.width; height: 1.5; color: Theme.accent }
                        Rectangle { x: parent.east ? parent.width - width : 0; width: 1.5; height: parent.height; color: Theme.accent }
                    }
                }

                Row {
                    id: wnRow
                    anchors.centerIn: parent
                    spacing: Theme.fs(3)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: wn.iconSize
                        height: width
                        radius: 2
                        color: art.value === "fade" && !wn.foc ? Theme.muted : wn.appColour
                        opacity: art.value === "fade" && !wn.foc ? 0.5 : art.value === "lift" && !wn.foc ? 0.8 : 1
                    }
                }

                // the marks under the icons
                Rectangle {
                    visible: art.value === "icons"
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: wn.foc ? Theme.fs(12) : Theme.fs(4)
                    height: 2
                    color: wn.foc ? Theme.accent : Theme.muted
                }
            }
        }
    }
    // glide: one groove under the icons, a slider at the focused one
    Rectangle {
        visible: art.kind === "windowStyle" && art.value === "glide"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: Theme.fs(48)
        height: 3
        radius: 1.5
        color: Theme.overlay
        Rectangle { width: Theme.fs(12); height: 3; radius: 1.5; color: Theme.accent }
    }
    // segmented: the track round all three
    Rectangle {
        visible: art.kind === "windowStyle" && art.value === "segmented"
        anchors.centerIn: parent
        width: winRow.width
        height: Theme.fs(22)
        radius: Theme.radiusSmall
        color: "transparent"
        border.width: 1
        border.color: Theme.stroke
    }

    // --- clock: the style's own format, now ---
    Text {
        visible: art.kind === "clockStyle"
        anchors.centerIn: parent
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: art.kind === "clockStyle" ? Qt.formatDateTime(new Date(), Theme.hours(Theme.clockFormats[art.value] || "HH:mm")) : ""
        color: Theme.textStrong
        font.family: Theme.fontText
        font.pixelSize: Theme.fontCaption
        font.weight: Theme.weightBody
    }

    // --- the Control Centre's glyph ---
    Text {
        visible: art.kind === "controlIcon"
        anchors.centerIn: parent
        text: Theme.controlGlyphs[art.value] || ""
        color: Theme.textStrong
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fs(20)
    }

    // --- the visualizer: eight bands ---
    Row {
        visible: art.kind === "vizStyle"
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: [0.4, 0.75, 1, 0.6, 0.85, 0.5, 0.3, 0.55]
            Item {
                id: band
                required property real modelData
                width: Theme.fs(5)
                height: Theme.fs(24)
                Rectangle {
                    visible: art.value !== "dots" && art.value !== "line"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: art.value === "mirror" ? parent.verticalCenter : undefined
                    anchors.bottom: art.value === "rise" ? parent.bottom : undefined
                    width: parent.width
                    height: parent.height * band.modelData
                    radius: Theme.pill(width)
                    color: Theme.meterFill
                }
                Column {
                    visible: art.value === "dots"
                    anchors.bottom: parent.bottom
                    spacing: 2
                    Repeater {
                        model: Math.max(1, Math.round(band.modelData * 4))
                        Rectangle { width: Theme.fs(4); height: width; radius: Theme.pill(width); color: Theme.meterFill }
                    }
                }
                Rectangle {
                    visible: art.value === "line"
                    y: parent.height * (1 - band.modelData)
                    width: parent.width + 2
                    height: 2
                    color: Theme.meterFill
                }
            }
        }
    }

    // --- window animation: a window opening, over and over while hovered ---
    Item {
        id: anim
        visible: art.kind === "windowAnim"
        anchors.fill: parent
        readonly property bool playing: !!art.parent && art.parent.hovered === true && art.value !== "none"
        property real t: 1

        NumberAnimation on t {
            running: anim.playing
            loops: Animation.Infinite
            from: 0; to: 1.4
            duration: 1100
            onRunningChanged: if (!running) anim.t = 1
        }

        Rectangle {
            readonly property real k: Math.min(1, anim.t)
            readonly property real e: 1 - Math.pow(1 - k, 3)
            anchors.centerIn: parent
            anchors.verticalCenterOffset: art.value === "rise" ? (1 - e) * Theme.fs(14)
                : art.value === "drop" ? -(1 - e) * Theme.fs(14) : 0
            anchors.horizontalCenterOffset: art.value === "slide" ? -(1 - e) * Theme.fs(24) : 0
            width: Theme.fs(34)
            height: Theme.fs(22)
            radius: 3
            color: Theme.overlay
            border.width: 1
            border.color: Theme.subtext
            opacity: art.value === "slide" || art.value === "rise" || art.value === "drop" ? 1 : e
            scale: art.value === "popin" ? 0.6 + 0.4 * e : art.value === "zoom" ? 0.3 + 0.7 * e : 1
            transform: Scale {
                origin.y: Theme.fs(22)
                yScale: art.value === "fold" ? Math.max(0.05, anim.e) : 1
            }
        }
        readonly property real e: 1 - Math.pow(1 - Math.min(1, t), 3)
    }
}
