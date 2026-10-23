// Singularity - Quickshell
// ~/.config/quickshell/flyouts/MediaFlyout.qml
//
// The Music module's flyout. Now playing: the art large with the title,
// artist and player over its foot, the art only while the player plays and
// in its place the spectrum (while the visualizer is on and something
// sounds) or a music mark; the progress (click to seek) and the transport; every
// player as a row (a click picks which the module follows). Then the
// module's switches (Visualizer, Title on the bar) and Visualizer look, a
// page of its own (style, bars, hiding when silent). Self-contained: only
// needs the Media and Visualizer singletons.

import Quickshell.Widgets
import QtQuick
import "../services"

FlyoutPanel {
    id: mediaFlyout
    flyout: "media"
    menuWidth: Theme.flyoutMenuWidth

    readonly property var player: Media.player
    // "" is now playing, "look" the visualizer's look
    property string page: ""
    onOpenChanged: if (!open) page = ""

    // MPRIS position isn't pushed while playing, only on seeks and
    // track changes, so it's nudged each second while this is open
    Timer {
        interval: 1000
        repeat: true
        running: mediaFlyout.open && mediaFlyout.player && mediaFlyout.player.isPlaying
        onTriggered: if (mediaFlyout.player) mediaFlyout.player.positionChanged()
    }

    FlyoutHeading {
        crumb: mediaFlyout.page === "" ? "" : "NOW PLAYING"
        text: mediaFlyout.page === "" ? "NOW PLAYING" : "VISUALIZER"
        onCrumbClicked: mediaFlyout.page = ""
    }

    // the art, as wide as the panel, with the track over its foot; the art
    // only while the player plays, otherwise the spectrum or a mark
    ClippingRectangle {
        id: artFrame
        visible: mediaFlyout.page === ""
        width: parent.width
        height: Math.round(width * 0.62)
        radius: Theme.radiusInner
        color: Theme.meterTrack
        border.width: Theme.borderWidth
        border.color: Theme.stroke
        readonly property bool showArt: art.status === Image.Ready
            && !!mediaFlyout.player && mediaFlyout.player.isPlaying

        Image {
            id: art
            anchors.fill: parent
            source: mediaFlyout.player ? mediaFlyout.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            // decoded at the frame's size, not the art's: a browser's
            // video thumbnail can be several megapixels
            sourceSize.width: artFrame.width * 2
            asynchronous: true
            visible: artFrame.showArt
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Theme.fontDisplay / 2
            visible: !artFrame.showArt && !spectrum.visible
            text: "󰝚"
            color: Theme.muted
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontDisplay
        }

        // the spectrum in the art's place, mirrored about its middle
        Row {
            id: spectrum
            visible: !artFrame.showArt && Settings.vizShown && Visualizer.playing
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: caption.top
            anchors.bottomMargin: Theme.spaceS
            height: parent.height * 0.4
            spacing: Theme.spaceXs
            readonly property real band: Math.max(3, (parent.width * 0.7 - spacing * (Visualizer.barCount - 1)) / Visualizer.barCount)

            Repeater {
                model: Visualizer.barCount

                Item {
                    required property int index
                    readonly property real v: Math.max(0, Math.min(1, (Visualizer.bars[index] || 0) / 100))
                    width: spectrum.band
                    height: spectrum.height

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: Math.max(3, parent.height * parent.v)
                        radius: Math.min(Theme.radiusSmall, width / 2)
                        color: Theme.meterFill
                    }
                }
            }
        }

        Rectangle {
            id: caption
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: captionText.implicitHeight + Theme.spaceM * 2
            color: Theme.captionScrim

            Column {
                id: captionText
                x: Theme.spaceM
                width: parent.width - Theme.spaceM * 2
                anchors.verticalCenter: parent.verticalCenter

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
            }
        }
    }

    // progress, and click-to-seek where the player allows it
    Item {
        width: parent.width
        height: Theme.rowHeight
        visible: mediaFlyout.page === "" && mediaFlyout.player && mediaFlyout.player.lengthSupported && mediaFlyout.player.length > 0

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
        visible: mediaFlyout.page === "" && !!mediaFlyout.player
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

    // every player as a row: a click picks which the module follows
    Repeater {
        model: mediaFlyout.page === "" && Media.players.length > 1 ? Media.players : []

        FlyoutRow {
            required property var modelData
            leadingIcon: modelData.isPlaying ? "󰏤" : "󰝚"
            label: modelData.identity
            highlighted: modelData === Media.player
            onActivated: Media.pick(modelData)
        }
    }

    FlyoutDivider { visible: mediaFlyout.page === "" }

    FlyoutAction {
        visible: mediaFlyout.page === ""
        icon: "󰺢"
        label: "Visualizer"
        checked: Settings.vizShown
        onActivated: Settings.set("vizShown", !Settings.vizShown)
    }

    FlyoutAction {
        visible: mediaFlyout.page === ""
        icon: "󰊄"
        label: "Title on the bar"
        checked: Settings.musicTitle
        onActivated: Settings.set("musicTitle", !Settings.musicTitle)
    }

    FlyoutRow {
        visible: mediaFlyout.page === ""
        leadingIcon: "󰔎"
        label: "Visualizer look"
        trailing: "󰅂"
        onActivated: mediaFlyout.page = "look"
    }

    // --- the visualizer's look ---

    FlyoutStepper {
        visible: mediaFlyout.page === "look"
        label: "Style"
        wrap: true
        valueWidth: 84
        readonly property var order: Settings.choices.vizStyle
        displayValue: Settings.choiceLabel(Theme.vizStyle, "vizStyle")
        onStepped: d => Settings.set("vizStyle", order[(order.indexOf(Theme.vizStyle) + d + order.length) % order.length])
    }

    FlyoutStepper {
        visible: mediaFlyout.page === "look"
        label: "Bars"
        value: Settings.vizBars
        minimum: Settings.limits.vizBars.min
        maximum: Settings.limits.vizBars.max
        onStepped: d => Settings.set("vizBars", Settings.vizBars + d)
    }

    FlyoutAction {
        visible: mediaFlyout.page === "look"
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
