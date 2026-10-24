// Singularity - Quickshell
// ~/.config/quickshell/flyouts/MediaFlyout.qml
//
// The Music module's flyout, one page. The track: the art beside the
// title, artist and player, a small spectrum (the bar's style) under them while the
// visualizer is on; the progress (click to seek) and the transport. Every
// player as a row when there are several (a click picks which the module
// follows). Then the switches: Visualizer, with its Style and Bars under
// it while it's on, Title on the bar, Hide when silent. Self-contained:
// only needs the Media and Visualizer singletons.

import Quickshell.Widgets
import QtQuick
import "../services"

FlyoutPanel {
    id: mediaFlyout
    flyout: "media"
    menuWidth: Theme.flyoutMenuWidth

    readonly property var player: Media.player

    // MPRIS position isn't pushed while playing, only on seeks and
    // track changes, so it's nudged each second while this is open
    Timer {
        interval: 1000
        repeat: true
        running: mediaFlyout.open && mediaFlyout.player && mediaFlyout.player.isPlaying
        onTriggered: if (mediaFlyout.player) mediaFlyout.player.positionChanged()
    }

    FlyoutHeading { text: "NOW PLAYING" }

    // the art, or a music mark without it, beside the track
    Row {
        width: parent.width
        spacing: Theme.spaceM

        ClippingRectangle {
            id: artFrame
            width: Theme.fit(72)
            height: width
            radius: Theme.radiusInner
            color: Theme.meterTrack
            border.width: Theme.borderWidth
            border.color: Theme.stroke

            Image {
                id: art
                anchors.fill: parent
                source: mediaFlyout.player ? mediaFlyout.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                // decoded at the frame's size, not the art's: a browser's
                // video thumbnail can be several megapixels
                sourceSize.width: artFrame.width * 2
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "󰝚"
                color: Theme.muted
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize * 2
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - artFrame.width - parent.spacing
            spacing: 1

            Text {
                width: parent.width
                text: mediaFlyout.player ? (mediaFlyout.player.trackTitle || "Nothing playing") : "No player open"
                elide: Text.ElideRight
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: Theme.fontBody
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: mediaFlyout.player ? [mediaFlyout.player.trackArtist, mediaFlyout.player.identity]
                    .filter(t => !!t).join(" · ") : ""
                elide: Text.ElideRight
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }

            // the spectrum in the bar's style, under the track
            Item {
                visible: Settings.vizShown
                width: parent.width
                height: Theme.fit(18) + Theme.spaceS

                Spectrum {
                    anchors.bottom: parent.bottom
                    spacing: Theme.spaceXs
                    bandW: Math.min(Theme.fit(6), (parent.width - spacing * (Visualizer.barCount - 1)) / Visualizer.barCount)
                    bandH: Theme.fit(18)
                }
            }
        }
    }

    // progress, and click-to-seek where the player allows it
    Item {
        width: parent.width
        height: Theme.rowHeight
        visible: mediaFlyout.player && mediaFlyout.player.lengthSupported && mediaFlyout.player.length > 0

        readonly property real frac: mediaFlyout.player && mediaFlyout.player.length > 0
            ? Math.max(0, Math.min(1, mediaFlyout.player.position / mediaFlyout.player.length)) : 0

        Meter {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Theme.spaceS
            fraction: parent.frac
            // position ticks once a second; easing each step reads as lag
            animated: false


            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -Theme.spaceM
                anchors.bottomMargin: -Theme.spaceM
                enabled: mediaFlyout.player && mediaFlyout.player.canSeek
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: mouse => mediaFlyout.player.position =
                    mediaFlyout.player.length * Math.max(0, Math.min(1, mouse.x / width))
            }
        }

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            text: mediaFlyout.player ? Media.fmtTime(mediaFlyout.player.position) : ""
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: mediaFlyout.player ? Media.fmtTime(mediaFlyout.player.length) : ""
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    Row {
        visible: !!mediaFlyout.player
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spaceL

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "󰒮"
            enabled: mediaFlyout.player && mediaFlyout.player.canGoPrevious
            onClicked: mediaFlyout.player.previous()
        }
        FlyoutChip {
            glyph: true
            anchors.verticalCenter: parent.verticalCenter
            text: mediaFlyout.player && mediaFlyout.player.isPlaying ? "󰏤" : "󰐊"
            enabled: mediaFlyout.player && mediaFlyout.player.canTogglePlaying
            onClicked: mediaFlyout.player.togglePlaying()
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "󰒭"
            enabled: mediaFlyout.player && mediaFlyout.player.canGoNext
            onClicked: mediaFlyout.player.next()
        }
    }

    FlyoutDivider { visible: Media.players.length > 1 }

    // every player as a row: a click picks which the module follows
    Repeater {
        model: Media.players.length > 1 ? Media.players : []

        FlyoutRow {
            required property var modelData
            leadingIcon: modelData.isPlaying ? "󰏤" : "󰝚"
            label: modelData.identity
            highlighted: modelData === Media.player
            onActivated: Media.pick(modelData)
        }
    }

    FlyoutDivider {}

    FlyoutAction {
        icon: "󰺢"
        label: "Visualizer"
        checked: Settings.vizShown
        onActivated: Settings.set("vizShown", !Settings.vizShown)
    }

    // the visualizer's look, under its switch while it's on
    Column {
        visible: Settings.vizShown
        x: Theme.iconCell + Theme.spaceL
        width: parent.width - x

        FlyoutSegmented {
            model: Settings.choices.vizStyle
            // "One line" is too long for a segment
            labelFor: v => v === "line" ? "Line" : Settings.choiceLabel(v, "vizStyle")
            current: Theme.vizStyle
            onPicked: v => Settings.set("vizStyle", v)
        }

        FlyoutSliderRow {
            label: "Bars"
            inline: true
            value: Settings.vizBars
            minimum: Settings.limits.vizBars.min
            maximum: Settings.limits.vizBars.max
            onMoved: v => Settings.set("vizBars", v)
        }
    }

    FlyoutAction {
        icon: "󰊄"
        label: "Title on the bar"
        checked: Settings.musicTitle
        onActivated: Settings.set("musicTitle", !Settings.musicTitle)
    }

    FlyoutAction {
        icon: "󰖁"
        label: "Hide when silent"
        checked: Settings.vizHideSilent
        onActivated: Settings.set("vizHideSilent", !Settings.vizHideSilent)
    }

    FlyoutDivider {}

    FlyoutChipLine {
        chips: [{ icon: "󰒓", text: "Settings", act: "settings" }]
        onPicked: mediaFlyout.scope.openSettings("appearance")
    }
}
