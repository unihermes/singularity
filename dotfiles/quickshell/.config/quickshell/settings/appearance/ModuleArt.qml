// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/ModuleArt.qml
//
// The Bar and Panels tabs' tile pictures: each draws one value of a
// setting the way the shell draws it, small, in the theme's colours.
// `kind` names the setting (workspaceStyle, windowStyle, clockStyle,
// controlIcon, vizStyle, launcherLayout, powerStyle, windowAnim); `value`
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
                        radius: art.value === "blocks" || art.value === "lines" ? 1 : height / 2
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
        visible: art.kind === "windowStyle"
        anchors.centerIn: parent
        spacing: art.value === "segmented" || art.value === "tabs" ? 0 : Theme.fs(5)
        Repeater {
            model: 3
            Item {
                id: wn
                required property int index
                readonly property bool foc: index === 0
                readonly property bool named: art.value === "tabs" || art.value === "index"
                    || ((art.value === "titled" || art.value === "spotlight") && foc)
                readonly property real iconSize: art.value === "lift" ? (foc ? Theme.fs(15) : Theme.fs(9))
                    : art.value === "spotlight" && !foc ? Theme.fs(8) : Theme.fs(11)
                anchors.verticalCenter: parent.verticalCenter
                width: wnRow.width + (art.value === "segmented" || art.value === "tabs" || art.value === "index"
                    || (art.value === "spotlight" && foc) ? Theme.fs(8) : 0)
                height: Theme.fs(22)

                // a ground: inset's well, segments, tabs, index, spotlight's capsule
                Rectangle {
                    anchors.fill: parent
                    visible: wn.foc && ["inset", "segmented", "tabs", "index", "spotlight"].indexOf(art.value) !== -1
                        || (!wn.foc && art.value === "segmented")
                    radius: art.value === "spotlight" ? height / 2 : Theme.radiusSmall
                    color: art.value === "index" && wn.foc ? Theme.accent
                        : art.value === "inset" ? Theme.base
                        : wn.foc ? Theme.overlay : "transparent"
                    border.width: art.value === "inset" || art.value === "segmented" ? 1 : 0
                    border.color: Theme.stroke
                }

                Row {
                    id: wnRow
                    anchors.centerIn: parent
                    spacing: Theme.fs(3)
                    Rectangle {
                        visible: art.value !== "dots" && art.value !== "index"
                        anchors.verticalCenter: parent.verticalCenter
                        width: wn.iconSize
                        height: width
                        radius: 2
                        color: art.value === "lift" && !wn.foc ? Theme.muted : art.appColours[wn.index]
                    }
                    Rectangle {
                        visible: art.value === "dots"
                        anchors.verticalCenter: parent.verticalCenter
                        width: wn.foc ? Theme.fs(12) : Theme.fs(5)
                        height: Theme.fs(5)
                        radius: height / 2
                        color: wn.foc ? Theme.accent : Theme.muted
                    }
                    Text {
                        visible: wn.named
                        anchors.verticalCenter: parent.verticalCenter
                        text: art.value === "index" ? (wn.index + 1) + " " + ["web", "term", "files"][wn.index] : ["web", "term", "files"][wn.index]
                        color: art.value === "index" && wn.foc ? Theme.textOnAccent : wn.foc ? Theme.textStrong : Theme.subtext
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontCaption
                        font.weight: Theme.weightBody
                    }
                }

                // the marks under the icons: icons, titled, glide
                Rectangle {
                    visible: art.value === "icons" || art.value === "titled"
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: wn.foc ? Theme.fs(12) : Theme.fs(4)
                    height: 2
                    color: wn.foc ? Theme.accent : Theme.muted
                }
            }
        }
    }
    // glide: one rail under the icons, a slider at the focused one
    Rectangle {
        visible: art.kind === "windowStyle" && art.value === "glide"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: Theme.fs(48)
        height: 2
        color: Theme.border
        Rectangle { width: Theme.fs(12); height: 2; color: Theme.accent }
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
                    radius: width / 2
                    color: Theme.meterFill
                }
                Column {
                    visible: art.value === "dots"
                    anchors.bottom: parent.bottom
                    spacing: 2
                    Repeater {
                        model: Math.max(1, Math.round(band.modelData * 4))
                        Rectangle { width: Theme.fs(4); height: width; radius: width / 2; color: Theme.meterFill }
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

    // --- the launcher: a field, then rows, a grid of icons, or one line ---
    Column {
        visible: art.kind === "launcherLayout"
        anchors.centerIn: parent
        spacing: 3
        Rectangle { width: Theme.fs(60); height: Theme.fs(6); radius: 2; color: Theme.base; border.width: 1; border.color: Theme.stroke }
        Column {
            visible: art.value === "list"
            spacing: 2
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    width: Theme.fs(60)
                    height: Theme.fs(4)
                    radius: 1
                    color: index === 0 ? Theme.accent : Theme.muted
                }
            }
        }
        Grid {
            visible: art.value === "grid"
            columns: 4
            spacing: 3
            Repeater {
                model: 8
                Rectangle {
                    required property int index
                    width: Theme.fs(8)
                    height: width
                    radius: 2
                    color: index === 0 ? Theme.accent : Theme.muted
                }
            }
        }
        Row {
            visible: art.value === "line"
            spacing: 3
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    width: Theme.fs(18)
                    height: Theme.fs(5)
                    radius: 2
                    color: index === 0 ? Theme.accent : Theme.muted
                }
            }
        }
    }

    // --- the power menu: a row of tiles, a list, or full screen ---
    Rectangle {
        visible: art.kind === "powerStyle"
        anchors.centerIn: parent
        width: Theme.fs(70)
        height: Theme.fs(28)
        radius: 3
        color: art.value === "full" ? Qt.rgba(0, 0, 0, 0.6) : "transparent"
        Row {
            visible: art.value !== "list"
            anchors.centerIn: parent
            spacing: 3
            Repeater {
                model: art.value === "full" ? 3 : 4
                Rectangle {
                    width: art.value === "full" ? Theme.fs(13) : Theme.fs(10)
                    height: width
                    radius: 2
                    color: art.value === "full" ? Theme.subtext : Theme.muted
                }
            }
        }
        Column {
            visible: art.value === "list"
            anchors.centerIn: parent
            spacing: 2
            Repeater {
                model: 4
                Rectangle { width: Theme.fs(40); height: Theme.fs(4); radius: 1; color: Theme.muted }
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
