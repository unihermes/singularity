// Singularity - Quickshell
// ~/.config/quickshell/desktop/MusicWidget.qml
//
// What the bar's Music module follows. Small: the art with play/pause
// beside it, the title and artist under. Medium: the art down the left,
// the player, track, progress and transport beside it. Large: the art
// across the top, the rest under it. The art dims while paused; with no
// player open it says so and offers the last one this session.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../services"

WidgetCard {
    id: root

    readonly property var player: Media.player
    readonly property bool playing: !!player && player.isPlaying
    readonly property real length: Media.lengthOf(player)
    readonly property real frac: length > 0 ? Math.max(0, Math.min(1, player.position / length)) : 0
    readonly property bool hasLength: length > 0

    // the last player seen, to open again once it's closed
    property string lastEntry: ""
    property string lastName: ""
    onPlayerChanged: if (player && player.desktopEntry) {
        lastEntry = player.desktopEntry
        lastName = player.identity
    }
    readonly property var lastApp: lastEntry !== "" ? DesktopEntries.byId(lastEntry) : null

    // MPRIS position isn't pushed while playing, only on seeks and track
    // changes, so it's nudged each second
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.playing
        onTriggered: root.player.positionChanged()
    }

    ClippingRectangle {
        id: art
        width: root.large ? parent.width : root.small ? Theme.fit(64) : parent.height
        height: root.large ? Math.round(parent.height * 0.52) : width
        radius: Theme.fit(12)
        color: root.track

        Image {
            id: img
            readonly property var urls: Media.artUrls(root.player)
            property int attempt: 0
            onUrlsChanged: attempt = 0
            onStatusChanged: if (status === Image.Error && attempt < urls.length - 1) attempt++
            anchors.fill: parent
            source: urls[attempt] || ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: art.width * 2
            asynchronous: true
            visible: status === Image.Ready
            opacity: root.playing ? 1 : 0.45
        }
        WidgetText {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready
            card: root
            text: "󰝚"
            font.family: Theme.fontIcon
            px: Math.round(art.height * 0.36)
            color: root.fgFaint
        }
    }

    // small: play/pause in the top right corner
    WidgetGlyph {
        card: root
        visible: root.small && !!root.player
        anchors.right: parent.right
        px: Theme.fit(26)
        text: root.playing ? "󰏤" : "󰐊"
        active: !!root.player && root.player.canTogglePlaying
        onClicked: root.player.togglePlaying()
    }

    Item {
        x: root.large || root.small ? 0 : art.width + Theme.fit(14)
        y: root.large ? art.height + Theme.fit(12) : root.small ? art.height + Theme.fit(8) : 0
        width: parent.width - x
        height: parent.height - y

        Column {
            width: parent.width

            WidgetCaption {
                visible: !root.small
                width: parent.width
                card: root
                text: root.player ? root.player.identity : root.lastName
            }
            WidgetText {
                width: parent.width
                card: root
                px: root.large ? Theme.fit(18) : root.textTitle
                text: root.player ? (root.player.trackTitle || "Nothing playing") : "Nothing playing"
                color: root.player ? root.fg : root.fgDim
                font.weight: root.weightStrong
            }
            WidgetText {
                width: parent.width
                visible: text !== ""
                card: root
                px: root.textCaption
                text: root.player ? (root.player.trackArtist || "") : root.lastName !== "" ? root.lastName + " played last" : ""
                color: root.fgDim
            }
        }

        // progress and transport, at the foot
        Column {
            visible: !root.small && !!root.player
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: Theme.fit(6)

            Rectangle {
                visible: root.hasLength
                width: parent.width
                height: Theme.fit(4)
                radius: height / 2
                color: root.track
                Rectangle {
                    width: parent.width * root.frac
                    height: parent.height
                    radius: parent.radius
                    color: root.fg
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Theme.fit(6)
                    enabled: !!root.player && root.player.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: mouse => root.player.position =
                        root.length * Math.max(0, Math.min(1, (mouse.x - Theme.fit(6)) / parent.width))
                }
            }
            Item {
                visible: root.hasLength && root.large
                width: parent.width
                height: pos.height
                WidgetText { id: pos; card: root; px: root.textCaption; color: root.fgDim; text: root.player ? Media.fmtTime(root.player.position) : "" }
                WidgetText { anchors.right: parent.right; card: root; px: root.textCaption; color: root.fgDim; text: Media.fmtTime(root.length) }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.fit(root.large ? 40 : 28)
                WidgetGlyph {
                    card: root
                    px: Theme.fit(root.large ? 26 : 20)
                    text: "󰒮"
                    active: !!root.player && root.player.canGoPrevious
                    onClicked: root.player.previous()
                }
                WidgetGlyph {
                    card: root
                    px: Theme.fit(root.large ? 34 : 26)
                    text: root.playing ? "󰏤" : "󰐊"
                    active: !!root.player && root.player.canTogglePlaying
                    onClicked: root.player.togglePlaying()
                }
                WidgetGlyph {
                    card: root
                    px: Theme.fit(root.large ? 26 : 20)
                    text: "󰒭"
                    active: !!root.player && root.player.canGoNext
                    onClicked: root.player.next()
                }
            }
        }

        // no player: open the last one
        WidgetText {
            visible: !root.player && root.lastApp !== null && !root.small
            anchors.bottom: parent.bottom
            card: root
            px: root.textCaption
            text: "󰐊  Open " + root.lastName
            color: root.accent
            font.weight: root.weightStrong
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.lastApp.execute()
            }
        }
    }
}
