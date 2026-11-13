// What the bar's Music module follows. Small: the art with play/pause
// on its corner, the title and artist under; the progress bar and transport
// are the media flyout's (the shell's Meter and chips). Medium: the art down the left,
// the player, track, progress and transport beside it. Large: the art
// across the top, the rest under it. The art dims while nothing's heard (a browser's
// paused tab stays lit while another tab plays); with no
// player open it says so and offers the last one this session.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../services"
import "../flyouts"

WidgetCard {
    id: root

    readonly property var player: Media.player
    readonly property bool playing: Media.shownPlaying
    readonly property real length: Media.lengthOf(player)
    readonly property real frac: length > 0 ? Math.max(0, Math.min(1, Media.positionOf(player) / length)) : 0
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
        // medium: a square down the left; otherwise all the height the
        // words and controls under it leave
        width: foot.beside ? parent.height : parent.width
        height: foot.beside ? width : parent.height - foot.height - foot.gap
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
            opacity: Media.shownPlaying ? 1 : 0.45
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

    // small: play/pause on the art's top right corner
    FlyoutChip {
        visible: root.small && !!root.player
        anchors.right: parent.right
        glyph: true
        text: root.playing ? "󰏤" : "󰐊"
        enabled: Media.controllable(root.player) && root.player.canTogglePlaying
        onClicked: root.player.togglePlaying()
    }

    Item {
        id: foot
        readonly property bool beside: !root.large && !root.small
        readonly property int gap: Theme.fit(root.large ? 12 : 8)
        readonly property Item low: controls.visible ? controls : openLast.visible ? openLast : null
        x: beside ? art.width + Theme.fit(14) : 0
        y: parent.height - height
        width: parent.width - x
        height: beside ? parent.height : info.height + (low ? gap + low.height : 0)

        Column {
            id: info
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
                px: root.textTitle
                text: root.player ? (Media.titleOf(root.player) || "Nothing playing") : "Nothing playing"
                color: root.player ? root.fg : root.fgDim
                font.weight: root.weightStrong
            }
            WidgetText {
                width: parent.width
                visible: text !== ""
                card: root
                text: root.player ? Media.artistOf(root.player) : root.lastName !== "" ? root.lastName + " played last" : ""
                color: root.fgDim
            }
        }

        // progress and transport, at the foot
        Column {
            id: controls
            visible: !root.small && !!root.player
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: Theme.fit(6)

            // position ticks once a second; easing each step reads as lag
            Meter {
                visible: root.hasLength
                width: parent.width
                fraction: root.frac
                animated: false
                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -Theme.fit(6)
                    anchors.bottomMargin: -Theme.fit(6)
                    enabled: Media.controllable(root.player) && root.player.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: mouse => root.player.position =
                        root.length * Math.max(0, Math.min(1, mouse.x / width))
                }
            }
            Item {
                visible: root.hasLength && root.large
                width: parent.width
                height: pos.height
                WidgetText { id: pos; card: root; color: root.fgDim; text: root.player ? Media.fmtTime(Media.positionOf(root.player)) : "" }
                WidgetText { anchors.right: parent.right; card: root; color: root.fgDim; text: Media.fmtTime(root.length) }
            }
            // the media flyout's transport
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spaceM
                FlyoutChip {
                    transparent: true
                    width: Theme.fit(root.large ? 56 : 44)
                    glyph: true
                    text: "󰒮"
                    enabled: Media.controllable(root.player) && root.player.canGoPrevious
                    onClicked: root.player.previous()
                }
                FlyoutChip {
                    transparent: true
                    width: Theme.fit(root.large ? 56 : 44)
                    glyph: true
                    text: root.playing ? "󰏤" : "󰐊"
                    enabled: Media.controllable(root.player) && root.player.canTogglePlaying
                    onClicked: root.player.togglePlaying()
                }
                FlyoutChip {
                    transparent: true
                    width: Theme.fit(root.large ? 56 : 44)
                    glyph: true
                    text: "󰒭"
                    enabled: Media.controllable(root.player) && root.player.canGoNext
                    onClicked: root.player.next()
                }
            }
        }

        // no player: open the last one
        WidgetText {
            id: openLast
            visible: !root.player && root.lastApp !== null && !root.small
            anchors.bottom: parent.bottom
            card: root
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
