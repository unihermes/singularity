// Neutrino - Quickshell
// ~/.config/quickshell/MediaFlyout.qml
//
// Split out of shell.qml. Self-contained: only needs the Media singleton.

import QtQuick
import "../services"

FlyoutPanel {
    id: mediaFlyout
    flyout: "media"
    menuWidth: 280

    readonly property var player: Media.player

    // MPRIS position isn't pushed while playing, only on seeks and
    // track changes, so it's nudged each second while this is open
    Timer {
        interval: 1000
        repeat: true
        running: mediaFlyout.open && mediaFlyout.player && mediaFlyout.player.isPlaying
        onTriggered: if (mediaFlyout.player) mediaFlyout.player.positionChanged()
    }

    FlyoutHeading {
        text: mediaFlyout.player ? mediaFlyout.player.identity.toUpperCase() : "MEDIA"
    }

    Item {
        width: parent.width
        height: 64

        Rectangle {
            id: artFrame
            width: 64
            height: 64
            radius: Theme.radiusInner
            color: Theme.base
            border.width: 1
            border.color: Theme.border
            clip: true

            Image {
                id: art
                anchors.fill: parent
                anchors.margins: 1
                source: mediaFlyout.player ? mediaFlyout.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "󰝚"
                color: Theme.muted
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fs(26)
            }
        }

        Column {
            anchors.left: artFrame.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: mediaFlyout.player ? (mediaFlyout.player.trackTitle || "Nothing playing") : ""
                elide: Text.ElideRight
                color: Theme.bright
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
                font.bold: true
            }
            Text {
                width: parent.width
                text: mediaFlyout.player ? mediaFlyout.player.trackArtist : ""
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: mediaFlyout.player ? mediaFlyout.player.trackAlbum : ""
                elide: Text.ElideRight
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    // progress, and click-to-seek where the player allows it
    Item {
        width: parent.width
        height: 24
        visible: mediaFlyout.player && mediaFlyout.player.lengthSupported && mediaFlyout.player.length > 0

        readonly property real frac: mediaFlyout.player && mediaFlyout.player.length > 0
            ? Math.max(0, Math.min(1, mediaFlyout.player.position / mediaFlyout.player.length)) : 0

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 4
            height: 6
            radius: 3
            color: Theme.base
            border.width: 1
            border.color: Theme.surface

            Rectangle {
                height: parent.height
                radius: 3
                width: Math.max(parent.frac > 0 ? height : 0, parent.width * parent.parent.frac)
                color: Theme.text
            }

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -6
                anchors.bottomMargin: -6
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
            font.pixelSize: Theme.fontSmall
        }
        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: mediaFlyout.player ? Media.fmtTime(mediaFlyout.player.length) : ""
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        FlyoutChip {
            glyph: true
            text: "󰒮"
            enabled: mediaFlyout.player && mediaFlyout.player.canGoPrevious
            onClicked: mediaFlyout.player.previous()
        }
        FlyoutChip {
            glyph: true
            text: mediaFlyout.player && mediaFlyout.player.isPlaying ? "󰏤" : "󰐊"
            enabled: mediaFlyout.player && mediaFlyout.player.canTogglePlaying
            onClicked: mediaFlyout.player.togglePlaying()
        }
        FlyoutChip {
            glyph: true
            text: "󰒭"
            enabled: mediaFlyout.player && mediaFlyout.player.canGoNext
            onClicked: mediaFlyout.player.next()
        }
    }

    // more than one player: pick which the module follows
    FlyoutHeading {
        visible: Media.players.length > 1
        text: "PLAYERS"
    }

    Repeater {
        model: Media.players.length > 1 ? Media.players : []

        FlyoutRow {
            required property var modelData
            label: modelData.identity + (modelData.trackTitle ? "  ·  " + modelData.trackTitle : "")
            highlighted: modelData === Media.player
            trailing: modelData.isPlaying ? "󰐊" : ""
            onActivated: Media.lastPlaying = modelData
        }
    }
}
