// Singularity - Quickshell
// ~/.config/quickshell/flyouts/MediaFlyout.qml
//
// The Music module's flyout, one page. The art across the panel with the
// spectrum (the bar's style) rising from its foot while something sounds,
// then the title, artist and player; the progress (click to seek) and the
// transport. With several sources (players, and a browser's tabs each)
// the art flips between them (arrows at its sides, a dot each along its
// top, the wheel), picking which the module follows. A tab the browser's
// player has moved on from shows but takes no transport. Then Options, folded: Visualizer, with its
// Style and Bars under it while it's on, Title on the bar, Hide when
// silent. Self-contained: only needs the Media and Visualizer singletons.

import Quickshell.Widgets
import QtQuick
import "../services"

FlyoutPanel {
    id: mediaFlyout
    flyout: "media"
    menuWidth: Theme.flyoutMenuWidth

    readonly property var player: Media.player
    // the source `step` along from the shown one, round the ends
    function flip(step) {
        var ss = Media.sources, n = ss.length
        if (n < 2) return
        Media.pickSource(ss[(Math.max(0, ss.findIndex(s => Media.isShown(s))) + step + n) % n])
    }
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
        onSettingsClicked: mediaFlyout.scope.openSettings("appearance/bar")
    }

    // the art across the panel in its own shape (square to 16:9, a video's
    // thumbnail wider than a cover), or a music mark in a 16:9 frame
    ClippingRectangle {
        id: artFrame
        width: parent.width
        height: Math.round(width / (art.status === Image.Ready && art.implicitHeight > 0
            ? Math.max(1, Math.min(16 / 9, art.implicitWidth / art.implicitHeight)) : 16 / 9))
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

        // the spectrum in the bar's style, rising from the art's foot over
        // a fade, across its width; gone while silent
        Rectangle {
            visible: Settings.vizShown && Visualizer.playing
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: spectrum.bandH + Theme.spaceXl + Theme.spaceM
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Theme.captionScrim }
            }

            // bands no wider than a fifth of their height, so four dots
            // fit; spread so the row spans the art
            Spectrum {
                id: spectrum
                anchors.left: parent.left
                anchors.leftMargin: Theme.spaceM
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spaceM
                readonly property real span: parent.width - Theme.spaceM * 2
                bandW: Math.min(Theme.fit(6), span / (Visualizer.barCount * 2))
                bandH: Theme.fit(32)
                spacing: Visualizer.barCount > 1 ? (span - bandW * Visualizer.barCount) / (Visualizer.barCount - 1) : 0
                color: Theme.textStrong
            }
        }

        // with several players: the wheel flips between them, an arrow at
        // each side and a dot each along the top (the shown one long)
        MouseArea {
            anchors.fill: parent
            enabled: Media.sources.length > 1
            acceptedButtons: Qt.NoButton
            onWheel: wheel => mediaFlyout.flip(wheel.angleDelta.y > 0 ? -1 : 1)
        }

        Repeater {
            model: Media.sources.length > 1 ? [-1, 1] : []

            Rectangle {
                required property int modelData
                anchors.verticalCenter: parent.verticalCenter
                x: modelData < 0 ? Theme.spaceM : artFrame.width - width - Theme.spaceM
                width: Theme.controlSize
                height: width
                radius: width / 2
                color: flipMouse.containsMouse ? Theme.base : Theme.captionScrim

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData < 0 ? "󰅁" : "󰅂"
                    color: Theme.textStrong
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontIconSize
                }
                MouseArea {
                    id: flipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mediaFlyout.flip(parent.modelData)
                }
            }
        }

        Rectangle {
            visible: Media.sources.length > 1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.spaceM
            width: dots.width + Theme.spaceM * 2
            height: dots.height + Theme.spaceS * 2
            radius: height / 2
            color: Theme.captionScrim

            Row {
                id: dots
                anchors.centerIn: parent
                spacing: Theme.spaceS

                Repeater {
                    model: Media.sources.length > 1 ? Media.sources : []

                    Rectangle {
                        required property var modelData
                        readonly property bool shown: Media.isShown(modelData)
                        width: shown ? Theme.spaceL * 2 : Theme.spaceS * 2
                        height: Theme.spaceS * 2
                        radius: height / 2
                        color: shown || dotMouse.containsMouse ? Theme.textStrong : Theme.muted
                        Behavior on width { NumberAnimation { duration: Theme.durMedium } }

                        MouseArea {
                            id: dotMouse
                            anchors.fill: parent
                            anchors.margins: -Theme.spaceXs
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Media.pickSource(parent.modelData)
                        }
                    }
                }
            }
        }
    }

    // the track
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

    Row {
        visible: !!mediaFlyout.player
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spaceL

        FlyoutChip {
            width: Theme.fit(56)
            glyph: true
            text: "󰒮"
            enabled: Media.controllable(mediaFlyout.player) && mediaFlyout.player.canGoPrevious
            onClicked: mediaFlyout.player.previous()
        }
        FlyoutChip {
            width: Theme.fit(56)
            glyph: true
            text: Media.shownPlaying ? "󰏤" : "󰐊"
            enabled: Media.controllable(mediaFlyout.player) && mediaFlyout.player.canTogglePlaying
            onClicked: mediaFlyout.player.togglePlaying()
        }
        FlyoutChip {
            width: Theme.fit(56)
            glyph: true
            text: "󰒭"
            enabled: Media.controllable(mediaFlyout.player) && mediaFlyout.player.canGoNext
            onClicked: mediaFlyout.player.next()
        }
    }

    FlyoutDivider {}

    FlyoutRow {
        leadingIcon: "󰔎"
        label: "Options"
        trailing: mediaFlyout.showOptions ? "󰅀" : "󰅂"
        onActivated: mediaFlyout.showOptions = !mediaFlyout.showOptions
    }

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

    FlyoutDivider {}
}
