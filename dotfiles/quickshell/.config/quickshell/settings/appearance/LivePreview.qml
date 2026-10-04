// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/LivePreview.qml
//

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../../services"
import "../../flyouts"
import "../../bar"
import ".."

ClippingRectangle {
    id: lp
    readonly property real sc: 0.62
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
        height: Theme.barHeight + Theme.spaceS + flyout.height
        scale: lp.sc
        transformOrigin: Item.TopLeft

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
            ModuleFrame { PreviewGlyph { text: "󰣇" } }
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
        }

        PreviewGroup {
            anchors.horizontalCenter: parent.horizontalCenter
            ModuleFrame {
                active: true
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

        PreviewGroup {
            anchors.right: parent.right
            anchors.rightMargin: Theme.barInset + Theme.moduleGap
            ModuleFrame { PreviewGlyph { text: "󰖩" } }
            ModuleFrame {
                fixedWidth: Theme.moduleWidth
                fillValue: 0.45
                PreviewGlyph { text: "󰕾" }
            }
            ModuleFrame {
                fixedWidth: Theme.moduleWidth
                fillValue: 0.8
                fillColor: Theme.good
                PreviewGlyph { text: "󰂄" }
            }
        }

        PanelFrame {
            id: flyout
            readonly property int padX: Theme.channelWidth * 2 + 3 + Theme.spaceL
            readonly property int padY: Theme.channelWidth * 2 + 3 + Theme.spaceS
            anchors.right: parent.right
            y: Theme.barHeight + Theme.spaceS
            width: Theme.fit(260) + padX * 2
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
    }

    // a picture: nothing in it takes the pointer
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
    }
}
