// Dashboard home. Device controls open dedicated pages in the same flyout.
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import "../services"

Column {
    id: root
    required property var cc
    width: parent.width
    spacing: Theme.flyoutSpacing
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var bar: cc.scope.barWindow
    readonly property bool btOn: !!bar && bar.btAdapterOn(adapter)
    readonly property bool pane: Theme.style === "pane"
    readonly property string output: cc.scope.modelData.name
    readonly property bool ddc: DdcBrightness.answered.indexOf(output) >= 0
    Timer {
        id: ddcRead
        interval: Theme.durMedium + 100
        onTriggered: if (DdcBrightness.has(root.output)) DdcBrightness.refresh()
    }
    Connections {
        target: root.cc
        function onOpenChanged() { if (root.cc.open) ddcRead.restart(); else ddcRead.stop() }
    }
    component Level: Row {
        id: level
        property string icon: ""
        property bool warn: false
        property real value: 0
        property string valueText: Math.round(value) + "%"
        property bool chevron: false
        property bool expanded: false
        signal iconClicked()
        signal moved(real v)
        signal moreClicked()

        width: parent ? parent.width : 0
        height: Theme.rowHeightTall + 8
        spacing: Theme.spaceS

        IconButton {
            id: glyphBtn
            anchors.verticalCenter: parent.verticalCenter
            icon: level.icon
            warn: level.warn
            onClicked: level.iconClicked()
        }
        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: level.width - glyphBtn.width - valueLabel.width - endBtn.width - level.spacing * 3
            value: level.value
            opacity: level.warn ? 0.5 : 1
            onMoved: v => level.moved(v)
        }
        Text {
            id: valueLabel
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fs(44)
            horizontalAlignment: Text.AlignRight
            text: level.valueText
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
        IconButton {
            id: endBtn
            anchors.verticalCenter: parent.verticalCenter
            opacity: level.chevron ? 1 : 0
            enabled: level.chevron
            icon: level.expanded ? "󰅀" : "󰅂"
            onClicked: level.moreClicked()
        }
    }

    TileGrid {
        visible: !root.pane
        columns: 2
        QuickTile {
            width: parent.cell
            icon: Network.powered ? "󰤨" : "󰤭"
            title: "Network"
            caption: Network.wired ? "Wired" : Network.device === "" ? "No Wi-Fi adapter"
                : !Network.powered ? "Wi-Fi off" : Network.ssid || "Not connected"
            goes: true
            onClicked: root.cc.page = "network"
        }
        QuickTile {
            width: parent.cell
            icon: "󰂯"
            title: "Bluetooth"
            caption: !root.adapter ? "No adapter" : root.btOn ? "On" : "Off"
            goes: true
            onClicked: root.cc.page = "bluetooth"
        }
    }
    FlyoutHeading { visible: root.pane; text: "QUICK CONTROLS" }
    Level {
        icon: Audio.muted ? "󰖁" : "󰕾"
        warn: Audio.muted
        value: Audio.percent
        valueText: Audio.muted ? "Muted" : Audio.percent + "%"
        chevron: true
        onIconClicked: Audio.toggleMute()
        onMoved: v => Audio.setVolume(v)
        onMoreClicked: root.cc.page = "sound"
    }
    Level {
        visible: root.ddc || Brightness.available
        icon: "󰃠"
        value: root.ddc ? DdcBrightness.level(root.output) : Brightness.level
        chevron: true
        onIconClicked: root.cc.page = "display"
        onMoved: v => root.ddc ? DdcBrightness.set(root.output, v) : Brightness.set(v)
        onMoreClicked: root.cc.page = "display"
    }
    FlyoutHeading { text: "SESSION" }
    ControlRow {
        icon: "󰂚"; title: "Quiet"
        caption: Notifications.dnd ? "Banners held" : "Off"
        checked: Notifications.dnd
        onClicked: Notifications.toggleDnd()
    }
    ControlRow {
        icon: "󰖔"; title: "Night Light"
        caption: root.cc.shellRoot.nightLight ? Settings.nightLightKelvin + " K" : "Off"
        checked: root.cc.shellRoot.nightLight
        usable: root.cc.shellRoot.hasHyprsunset
        split: true
        onClicked: root.cc.shellRoot.nightLight = !root.cc.shellRoot.nightLight
        onMoreClicked: root.cc.page = "display"
    }
    ControlRow {
        icon: "󰅶"; title: "Keep Awake"
        caption: root.cc.shellRoot.keepAwake ? "No sleep" : "Off"
        checked: root.cc.shellRoot.keepAwake
        onClicked: root.cc.shellRoot.keepAwake = !root.cc.shellRoot.keepAwake
    }
    ControlRow {
        visible: !root.pane
        icon: "󰂚"; title: "Focus"; caption: "Notifications and game mode"
        checkable: false; goes: true
        onClicked: root.cc.page = "focus"
    }
    readonly property bool playing: !!Media.player && Media.titleOf(Media.player) !== ""
    function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;") }

    Item {
        visible: root.playing
        width: parent.width
        height: Theme.rowHeightTall + Theme.spaceM + 4

        // the player's own outline
        Rectangle {
            id: outline
            anchors.fill: parent
            radius: Theme.radiusInner
            color: Theme.frameCustom && Theme.frameStyle === "notch" ? "transparent" : Theme.controlFill("transparent")
            border.width: Theme.controlBorder(Theme.stroke)
            border.color: Theme.controlStroke(Theme.stroke)

            ControlEdge {
                visible: Theme.controlStyle === "channel" || Theme.controlStyle === "double" || Theme.frameCustom
                ground: Theme.frameStyle === "notch" ? outline.color : "transparent"
                stroke: Theme.stroke; radius: outline.radius
                lit: false
            }
        }

        // a small thumbnail of the track's art, the note glyph while it has none
        Rectangle {
            id: noteGlyph
            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceS + 2
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.rowHeightTall
            height: width
            radius: Theme.radiusSmall
            color: Theme.washHover
            clip: true

            Image {
                id: thumb
                readonly property var urls: Media.artUrls(Media.player)
                property int attempt: 0
                onUrlsChanged: attempt = 0
                onStatusChanged: if (status === Image.Error && attempt < urls.length - 1) attempt++
                anchors.fill: parent
                source: urls[attempt] || ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: parent.width * 2
                asynchronous: true
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: thumb.status !== Image.Ready
                text: "󰎆"
                color: Theme.accent
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize
            }
        }
        Text {
            anchors.left: noteGlyph.right
            anchors.leftMargin: Theme.spaceL
            anchors.right: transport.left
            anchors.rightMargin: Theme.spaceM
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            textFormat: Text.StyledText
            text: root.esc(Media.titleOf(Media.player))
                + (Media.artistOf(Media.player) !== ""
                    ? "<font color='" + Theme.subtext + "'> · " + root.esc(Media.artistOf(Media.player)) + "</font>" : "")
            color: trackMouse.containsMouse ? Theme.textStrong : Theme.text
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody

            MouseArea {
                id: trackMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cc.openModule("media")
            }
        }
        Row {
            id: transport
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceXs
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: [
                    { glyph: "󰒮", act: "previous" },
                    { glyph: Media.shownPlaying ? "󰏤" : "󰐊", act: "toggle" },
                    { glyph: "󰒭", act: "next" },
                ]
                IconButton {
                    required property var modelData
                    icon: modelData.glyph
                    onClicked: Media[modelData.act]()
                }
            }
        }
    }

    FlyoutDivider { visible: !root.playing }

    TileGrid {
        visible: !root.pane
        columns: 2
        QuickTile { width: parent.cell; icon: "󰏘"; title: "Appearance"; goes: true; onClicked: root.cc.page = "appearance" }
        QuickTile { width: parent.cell; icon: "󰕮"; title: "Bar Widgets"; goes: true; onClicked: root.cc.page = "widgets" }
    }
    // the screen tools, last on the page
    FlyoutChipLine {
        onPicked: act => root.cc.run(act)
        chips: root.cc.toolActions
            .filter(t => ["screenshot", "colourpick", "copytext", "record"].indexOf(t.act) >= 0)
            .map(t => ({ icon: t.icon, text: { screenshot: "Capture", colourpick: "Colour", copytext: "Text" }[t.act] || t.name, act: t.act }))
    }
}
