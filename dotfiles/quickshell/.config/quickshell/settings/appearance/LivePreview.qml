// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/LivePreview.qml
//
// The Appearance page's preview, drawn by the shell's own pieces at a
// reduced scale over the wallpaper. `kind` is what the tab showing changes:
//   flyout    the bar and a volume flyout off it
//   bar       the whole bar, a little larger
//   launcher  the bar and the launcher in its layout and position
//   windows   the bar and two windows, the left one focused

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../../services"
import "../../flyouts"
import "../../bar"
import ".."

ClippingRectangle {
    id: lp
    property string kind: "flyout"
    readonly property real sc: kind === "bar" ? 0.8 : 0.62
    // the bar on its own edge, the rest off it; the clock at the right
    // end under Flat's Taskbar layout
    readonly property bool atBottom: Theme.barPosition === "bottom"
    readonly property bool clockRight: Settings.taskbarLayoutOn
    // below the bar: the flyout, the launcher or the windows
    readonly property Item below: kind === "flyout" ? flyout : kind === "launcher" ? launcher
        : kind === "windows" ? desk : null
    width: parent ? parent.width : 0
    height: Math.round(stage.height * sc) + Theme.spaceL * 2
    radius: Theme.radiusInner
    color: Theme.base

    Image {
        anchors.fill: parent
        source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
        sourceSize.width: 640
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: 0.85
    }

    Item {
        id: stage
        x: Theme.spaceL
        y: Theme.spaceL
        width: (lp.width - Theme.spaceL * 2) / lp.sc
        height: Theme.barHeight + (lp.below ? Theme.spaceS + lp.below.height : 0)
        scale: lp.sc
        transformOrigin: Item.TopLeft

        Item {
            id: previewBar
            width: parent.width
            height: Theme.barHeight
            y: lp.atBottom && lp.below ? lp.below.height + Theme.spaceS : 0

            Rectangle {
                width: parent.width
                height: Theme.barHeight
                radius: Theme.barFloating ? Theme.barRadius : Theme.radiusSmall
                color: Qt.rgba(Theme.bar.r, Theme.bar.g, Theme.bar.b, Theme.barOpacity)
                border.width: Theme.barFloating ? Theme.borderWidth : 0
                border.color: Theme.stroke
            }

            PreviewGroup {
                x: Theme.barInset + Theme.moduleGap
                ModuleFrame { PreviewGlyph { text: Theme.controlGlyph } }
                ModuleFrame {
                    Row {
                        spacing: Theme.spaceS
                        anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                anchors.verticalCenter: parent.verticalCenter
                                width: index === 1 ? 18 : 6
                                height: 6
                                radius: 3
                                color: index === 1 ? Theme.accent : Theme.muted
                            }
                        }
                    }
                }
                // the whole bar: the open windows too
                ModuleFrame {
                    visible: lp.kind === "bar"
                    PreviewGlyph { text: "󰈹" }
                    PreviewGlyph { text: "󰆍"; color: Theme.subtext }
                    PreviewGlyph { text: "󰉋"; color: Theme.subtext }
                }
            }

            PreviewGroup {
                visible: !lp.clockRight
                anchors.horizontalCenter: parent.horizontalCenter
                Loader { sourceComponent: lp.clockRight ? null : clockChip }
            }

            PreviewGroup {
                anchors.right: parent.right
                anchors.rightMargin: Theme.barInset + Theme.moduleGap
                ModuleFrame { visible: lp.kind === "bar"; PreviewGlyph { text: "󰂚" } }
                ModuleFrame { visible: lp.kind === "bar"; PreviewGlyph { text: "󰂯" } }
                ModuleFrame { PreviewGlyph { text: "󰖩" } }
                ModuleFrame {
                    fixedWidth: Theme.moduleWidth
                    fillValue: 0.45
                    active: lp.kind === "flyout"
                    PreviewGlyph { text: "󰕾" }
                }
                ModuleFrame {
                    fixedWidth: Theme.moduleWidth
                    fillValue: 0.8
                    fillColor: Theme.good
                    PreviewGlyph { text: "󰂄" }
                }
                Loader { sourceComponent: lp.clockRight ? clockChip : null }
            }
        }

        Component {
            id: clockChip
            ModuleFrame {
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(new Date(), Theme.timeFormat)
                    color: Theme.textStrong
                    font.family: Theme.fontText
                    font.pixelSize: Theme.barLabelSize
                    font.weight: Theme.weightBody
                }
            }
        }

        // --- flyout --------------------------------------------------------
        PanelFrame {
            id: flyout
            visible: lp.kind === "flyout"
            readonly property int padX: Theme.channelWidth * 2 + 3 + Theme.spaceL
            readonly property int padY: Theme.channelWidth * 2 + 3 + Theme.spaceS
            anchors.right: parent.right
            y: lp.atBottom ? 0 : Theme.barHeight + Theme.spaceS
            width: Theme.fit(260 * Settings.flyoutWidth / 100) + padX * 2
            height: flyCol.implicitHeight + padY * 2
            ground: Theme.surface

            SectionRuns {
                x: Theme.channelWidth + 3
                width: flyout.width - x * 2
                height: flyout.height
                column: flyCol
                columnY: flyCol.y
            }

            Column {
                id: flyCol
                readonly property bool sectioned: true
                x: flyout.padX
                y: flyout.padY
                width: flyout.width - flyout.padX * 2
                spacing: Theme.spaceM

                FlyoutHeading { text: "VOLUME  45%" }
                Slider { width: parent.width; value: 45 }
                FlyoutDivider {}
                FlyoutAction { icon: "󰕾"; label: "Mute"; checked: false }
                FlyoutRow { label: "Speakers"; highlighted: true }
                FlyoutRow { label: "More in Settings"; trailing: "󰁔" }
            }
        }

        // --- launcher ------------------------------------------------------
        PanelFrame {
            id: launcher
            visible: lp.kind === "launcher"
            readonly property int pad: Theme.channelWidth * 2 + 3 + Theme.spaceL
            readonly property string layout: Theme.launcherLayout
            x: Math.round((parent.width - width) / 2)
            y: lp.atBottom ? 0 : Theme.barHeight + Theme.spaceS
            width: Math.min(parent.width, Theme.fit(Theme.launcherPosition === "full" ? 760 : 600))
            height: lCol.implicitHeight + pad * 2
            ground: Theme.panel

            Column {
                id: lCol
                x: launcher.pad
                y: launcher.pad
                width: launcher.width - launcher.pad * 2
                spacing: Theme.spaceM

                Rectangle {
                    width: parent.width
                    height: Theme.rowHeightTall
                    radius: Theme.radiusInner
                    color: Theme.fieldFill
                    border.width: Theme.borderWidth
                    border.color: Theme.strokeFocus
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.spaceL
                        text: "󰍉  fir"
                        color: Theme.textStrong
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontBody
                        font.weight: Theme.weightBody
                    }
                }

                // list: rows, a second line under each with details on
                Column {
                    visible: launcher.layout === "list"
                    width: parent.width
                    Repeater {
                        model: [["󰈹", "Firefox", "Web browser"], ["󰉋", "Files", "File manager"], ["󰛖", "Fira Code", "Font"]]
                        FlyoutRow {
                            required property var modelData
                            required property int index
                            leadingIcon: modelData[0]
                            label: modelData[1]
                            note: Theme.launcherDetails ? modelData[2] : ""
                            highlighted: index === 0
                        }
                    }
                }

                // grid: large icons, four across
                Row {
                    visible: launcher.layout === "grid"
                    spacing: Theme.spaceL
                    Repeater {
                        model: ["󰈹", "󰉋", "󰆍", "󰨞"]
                        Rectangle {
                            required property string modelData
                            required property int index
                            width: Theme.fs(64)
                            height: width
                            radius: Theme.radiusInner
                            color: index === 0 ? Theme.selectedFill : "transparent"
                            border.width: index === 0 ? Theme.borderWidth : 0
                            border.color: Theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData
                                color: Theme.textStrong
                                font.family: Theme.fontIcon
                                font.pixelSize: Theme.fs(30)
                            }
                        }
                    }
                }

                // line: one row of names, dmenu-like
                Row {
                    visible: launcher.layout === "line"
                    spacing: Theme.spaceL
                    Repeater {
                        model: ["Firefox", "Files", "Fira Code"]
                        Rectangle {
                            required property string modelData
                            required property int index
                            width: lineText.implicitWidth + Theme.spaceM * 2
                            height: Theme.chipHeight
                            radius: Theme.radiusSmall
                            color: index === 0 ? Theme.accent : "transparent"
                            Text {
                                id: lineText
                                anchors.centerIn: parent
                                text: parent.modelData
                                color: parent.index === 0 ? Theme.textOnAccent : Theme.text
                                font.family: Theme.fontText
                                font.pixelSize: Theme.fontBody
                                font.weight: Theme.weightBody
                            }
                        }
                    }
                }
            }
        }

        // --- windows -------------------------------------------------------
        Item {
            id: desk
            visible: lp.kind === "windows"
            y: lp.atBottom ? 0 : Theme.barHeight
            width: parent.width
            height: Theme.fs(170)
            readonly property int gapOut: Settings.edgeGap
            readonly property int gapIn: Theme.fs(4)

            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    readonly property bool focused: index === 0
                    x: desk.gapOut + index * (width + desk.gapIn * 2)
                    y: desk.gapOut + Theme.spaceS
                    width: (desk.width - desk.gapOut * 2 - desk.gapIn * 2) / 2
                    height: desk.height - y - desk.gapOut
                    radius: Theme.windowRadius
                    color: Theme.panel
                    opacity: (focused ? Settings.focusedOpacity : Settings.unfocusedOpacity) / 100
                    border.width: Theme.windowBorderWidth
                    border.color: focused ? Theme.windowBorderActive : Theme.windowBorderInactive

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: parent.border.width
                        radius: Math.max(0, parent.radius - parent.border.width)
                        color: "black"
                        visible: !parent.focused
                        opacity: lp.dimStrength
                    }

                    Column {
                        x: Theme.spaceL
                        y: Theme.spaceL
                        spacing: Theme.spaceS
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                width: Theme.fs(index === 0 ? 120 : 200 - index * 30)
                                height: Theme.fs(8)
                                radius: 2
                                color: index === 0 ? Theme.subtext : Theme.overlay
                            }
                        }
                    }
                }
            }
        }
    }

    // Hyprland's dimming of the unfocused window, as the Desktop tab has it
    readonly property real dimStrength: {
        var p = parent
        while (p && p.hyprField === undefined) p = p.parent
        if (!p) return 0
        var on = p.hyprField(["decoration"], "dim_inactive").value === true
        return on ? Number(p.hyprField(["decoration"], "dim_strength").value) || 0 : 0
    }

    // a picture: nothing in it takes the pointer
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
    }
}
