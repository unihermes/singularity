// The Music module's flyout, one page. A square of art with the title,
// artist and player beside it and the transport under them; the progress
// (click to seek). With several sources (players, and a browser's tabs
// each) a row each, picking which the module follows. A tab the browser's
// player has moved on from shows but takes no transport. The heading's gear
// opens the options: Visualizer, with its Style and Bars under it while
// it's on, Title on the bar, Hide when silent, and a way to Settings. Self-contained: only needs the Media and Visualizer singletons.

import Quickshell.Widgets
import QtQuick
import "../services"

FlyoutPanel {
    id: mediaFlyout
    flyout: "media"
    menuWidth: Theme.flyoutMenuWidth

    readonly property var player: Media.player
    // the switches under Options, folded each time this opens
    property bool showOptions: false
    onOpenChanged: if (!open) showOptions = false

    // MPRIS position isn't pushed while playing, only on seeks and
    // track changes, so it's nudged each second while this is open
    Timer {
        interval: 1000
        repeat: true
        running: mediaFlyout.open && mediaFlyout.player && mediaFlyout.player.isPlaying
        onTriggered: if (mediaFlyout.player) mediaFlyout.player.positionChanged()
    }

    FlyoutHeading {
        text: "NOW PLAYING"
        settingsIcon: true
        onSettingsClicked: mediaFlyout.showOptions = !mediaFlyout.showOptions
    }

    // the art as a square beside the track and its transport
    Row {
        width: parent.width
        spacing: Theme.spaceL

        ClippingRectangle {
            id: artFrame
            width: Theme.fit(104)
            height: width
            radius: Theme.radiusInner
            color: Theme.meterTrack
            border.width: Theme.borderWidth
            border.color: Theme.stroke

            Image {
                id: art
                // Media.artUrls in turn, the next when one fails to load
                readonly property var urls: Media.artUrls(mediaFlyout.player)
                property int attempt: 0
                onUrlsChanged: attempt = 0
                onStatusChanged: if (status === Image.Error && attempt < urls.length - 1) attempt++
                anchors.fill: parent
                source: urls[attempt] || ""
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

        // the track at the top, the transport at the foot
        Item {
            width: parent.width - artFrame.width - parent.spacing
            height: artFrame.height

            Column {
                width: parent.width
                spacing: 1

                Text {
                    width: parent.width
                    text: mediaFlyout.player ? (Media.titleOf(mediaFlyout.player) || "Nothing playing") : "No player open"
                    elide: Text.ElideRight
                    color: Theme.textStrong
                    font.family: Theme.fontText
                    font.weight: Theme.weightStrong
                    font.pixelSize: Theme.fontBody
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: mediaFlyout.player ? [Media.artistOf(mediaFlyout.player), mediaFlyout.player.identity]
                        .filter(t => !!t).join(" · ") : ""
                    elide: Text.ElideRight
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }

            }

            Row {
                visible: !!mediaFlyout.player
                anchors.bottom: parent.bottom
                spacing: Theme.spaceS

                FlyoutChip {
                    width: Theme.fit(40)
                    glyph: true
                    text: "󰒮"
                    enabled: Media.controllable(mediaFlyout.player) && mediaFlyout.player.canGoPrevious
                    onClicked: mediaFlyout.player.previous()
                }
                FlyoutChip {
                    width: Theme.fit(40)
                    glyph: true
                    text: Media.shownPlaying ? "󰏤" : "󰐊"
                    enabled: Media.controllable(mediaFlyout.player) && mediaFlyout.player.canTogglePlaying
                    onClicked: mediaFlyout.player.togglePlaying()
                }
                FlyoutChip {
                    width: Theme.fit(40)
                    glyph: true
                    text: "󰒭"
                    enabled: Media.controllable(mediaFlyout.player) && mediaFlyout.player.canGoNext
                    onClicked: mediaFlyout.player.next()
                }
            }
        }
    }

    // progress, and click-to-seek where the player allows it
    Item {
        id: progress
        width: parent.width
        height: Theme.rowHeight
        readonly property real length: Media.lengthOf(mediaFlyout.player)
        visible: length > 0

        readonly property real frac: length > 0 ? Math.max(0, Math.min(1, Media.positionOf(mediaFlyout.player) / length)) : 0

        Meter {
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
                enabled: Media.controllable(mediaFlyout.player) && mediaFlyout.player.canSeek
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: mouse => mediaFlyout.player.position =
                    progress.length * Math.max(0, Math.min(1, mouse.x / width))
            }
        }

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            text: mediaFlyout.player ? Media.fmtTime(Media.positionOf(mediaFlyout.player)) : ""
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: Media.fmtTime(progress.length)
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    // with several sources: a row each, the shown one marked; a click picks which the module follows
    function sourceLabel(src) {
        var tab = src.tab === -1 ? null : Media.tabsOf(src.player).find(t => t.id === src.tab)
        return src.player.identity + (tab ? " · " + tab.name : "")
    }
    Repeater {
        model: Media.sources.length > 1 ? Media.sources : []

        FlyoutRow {
            required property var modelData
            readonly property bool shown: Media.isShown(modelData)
            leadingIcon: shown ? "󰐊" : "󰝚"
            label: mediaFlyout.sourceLabel(modelData)
            trailing: shown ? "Following" : ""
            trailingIsValue: shown
            onActivated: Media.pickSource(modelData)
        }
    }

    FlyoutDivider { visible: mediaFlyout.showOptions }

    FlyoutAction {
        visible: mediaFlyout.showOptions
        icon: "󰺢"
        label: "Visualizer"
        checked: Settings.vizShown
        onActivated: Settings.set("vizShown", !Settings.vizShown)
    }

    // the visualizer's look, under its switch while it's on
    Column {
        visible: mediaFlyout.showOptions && Settings.vizShown
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
        visible: mediaFlyout.showOptions
        icon: "󰊄"
        label: "Title on the bar"
        checked: Settings.musicTitle
        onActivated: Settings.set("musicTitle", !Settings.musicTitle)
    }

    FlyoutAction {
        visible: mediaFlyout.showOptions
        icon: "󰖁"
        label: "Hide when silent"
        checked: Settings.vizHideSilent
        onActivated: Settings.set("vizHideSilent", !Settings.vizHideSilent)
    }

    FlyoutRow {
        visible: mediaFlyout.showOptions
        leadingIcon: "󰒓"
        label: "More in Settings"
        onActivated: mediaFlyout.scope.openSettings("appearance/bar")
    }
}
