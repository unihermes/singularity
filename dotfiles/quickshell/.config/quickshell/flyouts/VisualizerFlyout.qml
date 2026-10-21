// Singularity - Quickshell
// ~/.config/quickshell/flyouts/VisualizerFlyout.qml
//
// The music chip's flyout: the spectrum large with what's playing and its
// transport under it, then the visualizer's look (style, bands, whether
// the chip hides in silence), then Open Media and Settings.

import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "visualizer"
    menuWidth: Theme.flyoutMenuWidth

    readonly property var player: Media.player
    // rising for the styles that stand on the floor, else mirrored
    readonly property bool rise: Theme.vizStyle === "rise"

    FlyoutHeading {
        text: "VISUALIZER"
        hints: root.player ? [root.player.identity] : []
    }

    // the spectrum, as wide as the panel
    Row {
        id: spectrum
        width: parent.width
        height: Theme.fs(64)
        spacing: Theme.spaceXs
        readonly property real band: (width - spacing * (Visualizer.barCount - 1)) / Visualizer.barCount

        Repeater {
            model: Visualizer.barCount

            Item {
                required property int index
                readonly property real v: Math.max(0, Math.min(1, (Visualizer.bars[index] || 0) / 100))
                width: spectrum.band
                height: spectrum.height

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: root.rise ? undefined : parent.verticalCenter
                    anchors.bottom: root.rise ? parent.bottom : undefined
                    width: parent.width
                    height: Math.max(3, parent.height * parent.v)
                    radius: Math.min(Theme.radiusSmall, width / 2)
                    color: Theme.meterFill
                }
            }
        }
    }

    // what's playing, and its transport
    Item {
        visible: root.player !== null
        width: parent.width
        implicitHeight: Math.max(nowPlaying.implicitHeight, transport.implicitHeight)

        Column {
            id: nowPlaying
            anchors.left: parent.left
            anchors.right: transport.left
            anchors.rightMargin: Theme.spaceM
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.player ? root.player.trackTitle || root.player.identity : ""
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: Theme.fontBody
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: text !== ""
                text: root.player ? root.player.trackArtist || "" : ""
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }

        Row {
            id: transport
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXs

            FlyoutChip { glyph: true; text: "󰒮"; enabled: !!root.player && root.player.canGoPrevious; onClicked: Media.previous() }
            FlyoutChip { glyph: true; text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"; enabled: !!root.player && root.player.canTogglePlaying; onClicked: Media.toggle() }
            FlyoutChip { glyph: true; text: "󰒭"; enabled: !!root.player && root.player.canGoNext; onClicked: Media.next() }
        }
    }

    FlyoutDivider {}

    FlyoutStepper {
        label: "Style"
        wrap: true
        valueWidth: 84
        readonly property var order: Settings.choices.vizStyle
        displayValue: Settings.choiceLabel(Theme.vizStyle, "vizStyle")
        onStepped: d => Settings.set("vizStyle", order[(order.indexOf(Theme.vizStyle) + d + order.length) % order.length])
    }

    FlyoutStepper {
        label: "Bars"
        value: Settings.vizBars
        minimum: Settings.limits.vizBars.min
        maximum: Settings.limits.vizBars.max
        onStepped: d => Settings.set("vizBars", Settings.vizBars + d)
    }

    FlyoutAction {
        icon: "󰖁"
        label: "Hide when silent"
        checked: Settings.vizHideSilent
        onActivated: Settings.set("vizHideSilent", !Settings.vizHideSilent)
    }

    FlyoutDivider {}

    FlyoutChipLine {
        chips: [
            { icon: "󰝚", text: "Open Media", act: "media" },
            { icon: "󰒓", text: "Settings",   act: "settings" },
        ]
        onPicked: act => {
            if (act === "settings") root.scope.openSettings("appearance")
            else root.scope.toggleFlyout("media", root.scope.barWindow.widgetItem("visualizer"))
        }
    }
}
