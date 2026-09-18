// Singularity - Quickshell
// ~/.config/quickshell/flyouts/MediaFlyout.qml
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
        height: artFrame.height

        Rectangle {
            id: artFrame
            width: Theme.fs(64)
            height: width
            radius: Theme.radiusInner
            color: Theme.meterTrack
            border.width: Theme.borderWidth
            border.color: Theme.stroke
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
                font.pixelSize: Theme.fontDisplay

            }
        }

        Column {
            anchors.left: artFrame.right
            anchors.leftMargin: Theme.sp(10)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXs

            Text {
                width: parent.width
                text: mediaFlyout.player ? (mediaFlyout.player.trackTitle || "Nothing playing") : ""
                elide: Text.ElideRight
                color: Theme.textStrong
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
        spacing: Theme.spaceL

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
