// Singularity - Quickshell
// ~/.config/quickshell/desktop/MusicWidget.qml
//
// What the bar's Music module follows: the art beside the title, artist
// and album, the progress (click to seek) and the transport; the art dims
// while paused. With no player open it says so and offers to open the
// last one that played this session.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../services"
import "../flyouts"

WidgetFrame {
    id: root

    readonly property var player: Media.player

    // the last player seen, to open again once it's closed
    property string lastEntry: ""
    property string lastName: ""
    onPlayerChanged: if (player && player.desktopEntry) {
        lastEntry = player.desktopEntry
        lastName = player.identity
    }

    // MPRIS position isn't pushed while playing, only on seeks and track
    // changes, so it's nudged each second
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && !!root.player && root.player.isPlaying
        onTriggered: root.player.positionChanged()
    }

    FlyoutHeading {
        text: "NOW PLAYING"
        hints: root.player ? [root.player.identity] : []
    }

    Row {
        width: parent.width
        spacing: Theme.spaceL

        ClippingRectangle {
            id: artFrame
            width: Theme.fit(64)
            height: width
            radius: Theme.radiusInner
            color: Theme.meterTrack
            border.width: Theme.borderWidth
            border.color: Theme.stroke

            Image {
                id: art
                // Media.artUrls in turn, the next when one fails to load
                readonly property var urls: Media.artUrls(root.player)
                property int attempt: 0
                onUrlsChanged: attempt = 0
                onStatusChanged: if (status === Image.Error && attempt < urls.length - 1) attempt++
                anchors.fill: parent
                source: urls[attempt] || ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: artFrame.width * 2
                asynchronous: true
                visible: status === Image.Ready
                opacity: root.player && !root.player.isPlaying ? 0.45 : 1
            }

            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "󰝚"
                color: Theme.muted
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize * 1.5
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - artFrame.width - parent.spacing
            spacing: 1

            Text {
                width: parent.width
                text: root.player ? (root.player.trackTitle || "Nothing playing") : "Nothing playing"
                elide: Text.ElideRight
                color: root.player ? Theme.textStrong : Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: Theme.fontBody
            }
            Repeater {
                model: root.player ? [root.player.trackArtist, root.player.trackAlbum].filter(t => !!t)
                    : root.lastName !== "" ? [root.lastName + " played last"] : []
                Text {
                    required property string modelData
                    width: parent.width
                    text: modelData
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
        visible: !!root.player && root.player.lengthSupported && root.player.length > 0

        Meter {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Theme.spaceS
            fraction: root.player && root.player.length > 0
                ? Math.max(0, Math.min(1, root.player.position / root.player.length)) : 0
            // position ticks once a second; easing each step reads as lag
            animated: false

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -Theme.spaceM
                anchors.bottomMargin: -Theme.spaceM
                enabled: !!root.player && root.player.canSeek
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: mouse => root.player.position =
                    root.player.length * Math.max(0, Math.min(1, mouse.x / width))
            }
        }

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            text: root.player ? Media.fmtTime(root.player.position) : ""
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: root.player ? Media.fmtTime(root.player.length) : ""
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    Row {
        visible: !!root.player
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spaceL

        FlyoutChip {
            width: Theme.fit(56)
            glyph: true
            text: "󰒮"
            enabled: !!root.player && root.player.canGoPrevious
            onClicked: root.player.previous()
        }
        FlyoutChip {
            width: Theme.fit(56)
            glyph: true
            text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
            enabled: !!root.player && root.player.canTogglePlaying
            onClicked: root.player.togglePlaying()
        }
        FlyoutChip {
            width: Theme.fit(56)
            glyph: true
            text: "󰒭"
            enabled: !!root.player && root.player.canGoNext
            onClicked: root.player.next()
        }
    }

    FlyoutChip {
        readonly property var entry: root.lastEntry !== "" ? DesktopEntries.byId(root.lastEntry) : null
        visible: !root.player && entry !== null
        icon: "󰐊"
        text: "Open " + root.lastName
        onClicked: entry.execute()
    }
}
