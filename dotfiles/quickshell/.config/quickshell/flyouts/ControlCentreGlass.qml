// Glass home: compact connectivity mosaic, capsule levels and media.
// Labels open focused detail sheets in the same flyout.

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick
import "../services"

Column {
    id: root

    required property var cc
    readonly property var bar: cc.scope.barWindow
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: !!bar && bar.btAdapterOn(adapter)
    readonly property real cell: (width - spacing) / 2
    readonly property int tileH: Theme.fs(60)

    width: parent.width
    spacing: Theme.spaceL

    // --- Toggles ----------------------------------------------

    Row {
        width: parent.width
        spacing: root.spacing

        GlassCard {
            width: root.cell
            height: root.tileH * 2 + root.spacing

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spaceL
                // the rows spread down the card
                spacing: Math.max(Theme.spaceS, (height - visibleChildren.length * Theme.fs(34)) / Math.max(1, visibleChildren.length - 1))

                GlassLink {
                    height: Theme.fs(34)
                    visible: Network.device !== ""
                    icon: Network.powered ? "󰤨" : "󰤭"
                    title: "Wi-Fi"
                    caption: !Network.powered ? "Off" : Network.ssid !== "" ? Network.ssid
                        : Network.wired ? "Wired" : "Not connected"
                    lit: Network.powered
                    onToggled: Network.setPowered(!Network.powered)
                    onOpened: {
                        root.cc.page = "network"
                    }
                }
                GlassLink {
                    height: Theme.fs(34)
                    visible: !!root.adapter
                    icon: "󰂯"
                    title: "Bluetooth"
                    caption: !root.btOn ? "Off" : root.btConnected.length === 1
                        ? root.btConnected[0].deviceName || root.btConnected[0].name
                        : root.btConnected.length > 1 ? root.btConnected.length + " connected" : "On"
                    lit: root.btOn
                    onToggled: if (root.bar) root.bar.setBtPowered(root.adapter, !root.btOn)
                    onOpened: root.cc.page = "bluetooth"
                }
                GlassLink {
                    height: Theme.fs(34)
                    icon: Vpn.servers.length > 0 ? "󰖂" : "󰀝"
                    title: Vpn.servers.length > 0 ? "VPN" : "Airplane"
                    caption: Vpn.servers.length > 0 ? (Vpn.busy ? "Connecting…" : Vpn.up ? Vpn.currentName : "Off")
                        : root.cc.airplane ? "Radios off" : "Off"
                    lit: Vpn.servers.length > 0 ? Vpn.up : root.cc.airplane
                    usable: Vpn.servers.length === 0 || Vpn.available
                    onToggled: Vpn.servers.length > 0 ? Vpn.toggle() : root.cc.setAirplane(!root.cc.airplane)
                    onOpened: root.cc.page = "network"
                }
            }
        }

        Column {
            width: root.cell
            spacing: root.spacing
            GlassLinkTile {
                width: parent.width
                icon: Notifications.dnd ? "󰂛" : "󰂚"
                title: "Focus"
                caption: Notifications.dnd ? "Banners held" : "Off"
                lit: Notifications.dnd
                onToggled: Notifications.toggleDnd()
                onOpened: root.cc.page = "focus"
            }
            GlassLinkTile {
                width: parent.width
                icon: root.cc.shellRoot.nightLight ? "󰖔" : "󰖙"
                title: "Night Light"
                caption: root.cc.shellRoot.nightLight ? Settings.nightLightKelvin + " K" : "Off"
                lit: root.cc.shellRoot.nightLight
                usable: root.cc.shellRoot.hasHyprsunset
                onToggled: root.cc.shellRoot.nightLight = !root.cc.shellRoot.nightLight
                onOpened: root.cc.page = "display"
            }
        }
    }

    // things paired before, connected first
    readonly property var btSaved: (adapter && adapter.devices ? adapter.devices.values : [])
        .filter(d => d.paired || d.connected)
        .sort((x, y) => x.connected !== y.connected ? (x.connected ? -1 : 1)
            : (x.deviceName || "").localeCompare(y.deviceName || ""))
    readonly property var btConnected: btSaved.filter(d => d.connected)

    Row {
        width: parent.width
        spacing: root.spacing
        GlassLinkTile {
            width: root.cell
            icon: root.cc.shellRoot.keepAwake ? "󰅶" : "󰾪"
            title: "Keep Awake"
            caption: root.cc.shellRoot.keepAwake ? "No sleep" : "Off"
            lit: root.cc.shellRoot.keepAwake
            onToggled: root.cc.shellRoot.keepAwake = !root.cc.shellRoot.keepAwake
            onOpened: root.cc.shellRoot.keepAwake = !root.cc.shellRoot.keepAwake
        }
        GlassLinkTile {
            width: root.cell
            icon: "󰹑"
            title: "Capture"
            caption: "Screen tools"
            onToggled: root.cc.page = "tools"
            onOpened: root.cc.page = "tools"
        }
    }

    // --- Display and Sound ------------------------------------

    // this screen's brightness: its DDC monitor, else the backlight
    readonly property string output: cc.scope.modelData.name
    readonly property bool ddc: DdcBrightness.answered.indexOf(output) >= 0
    readonly property var ddcDisplay: DdcBrightness.find(output)

    Timer {
        id: ddcRead
        interval: Theme.durMedium + 100
        onTriggered: if (DdcBrightness.has(root.output)) DdcBrightness.refresh()
    }
    Connections {
        target: root.cc
        function onOpenChanged() { if (root.cc.open) ddcRead.restart(); else ddcRead.stop() }
    }

    GlassCard {
        visible: root.ddc || Brightness.available
        width: parent.width
        height: displayCol.height + Theme.spaceL * 2
        Column {
            id: displayCol
            x: Theme.spaceL
            y: Theme.spaceL
            width: parent.width - Theme.spaceL * 2
            spacing: Theme.spaceM
            GlassLevelHead {
                title: "Display"
                device: root.ddc ? ((root.ddcDisplay && root.ddcDisplay.model) || root.output) : "Built-in display"
                chevron: true
                onDeviceClicked: root.cc.page = "display"
            }
            GlassSlider {
                width: parent.width
                icon: "󰃠"
                value: root.ddc ? DdcBrightness.level(root.output) : Brightness.level
                onMoved: v => root.ddc ? DdcBrightness.set(root.output, v) : Brightness.set(v)
            }
        }
    }

    GlassCard {
        width: parent.width
        height: soundCol.height + Theme.spaceL * 2
        Column {
            id: soundCol
            x: Theme.spaceL
            y: Theme.spaceL
            width: parent.width - Theme.spaceL * 2
            spacing: Theme.spaceM
            GlassLevelHead {
                title: "Sound"
                device: Audio.sink ? Audio.plainName(Audio.sink) : ""
                chevron: true
                onDeviceClicked: root.cc.page = "sound"
            }
            GlassSlider {
                width: parent.width
                icon: Audio.muted ? "󰖁" : "󰕾"
                value: Audio.percent
                dimmed: Audio.muted
                onMoved: v => Audio.setVolume(v)
            }

        }
    }

    // --- Now playing ------------------------------------------

    GlassCard {
        visible: !!Media.player && Media.titleOf(Media.player) !== ""
        width: parent.width
        height: Theme.fs(40) + Theme.spaceL * 2
        readonly property string art: (Media.artUrls(Media.player) || [])[0] || ""

        Rectangle {
            id: artBox
            x: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fs(40)
            height: width
            radius: Theme.fs(8)
            color: Theme.surface
            clip: true
            Text {
                anchors.centerIn: parent
                visible: artImage.status !== Image.Ready
                text: "󰎆"
                color: Theme.subtext
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize
            }
            Image {
                id: artImage
                anchors.fill: parent
                source: parent.parent.art
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width * 2
                asynchronous: true
            }
        }
        Text {
            anchors.left: artBox.right
            anchors.leftMargin: Theme.spaceL
            anchors.right: transport.left
            anchors.rightMargin: Theme.spaceM
            anchors.verticalCenter: parent.verticalCenter
            text: Media.titleOf(Media.player)
            elide: Text.ElideRight
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightStrong
            font.pixelSize: Theme.fontBody
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cc.openModule("media")
            }
        }
        Row {
            id: transport
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceM
            Repeater {
                model: [
                    { glyph: "󰒮", act: "previous" },
                    { glyph: Media.shownPlaying ? "󰏤" : "󰐊", act: "toggle" },
                    { glyph: "󰒭", act: "next" },
                ]
                Text {
                    required property var modelData
                    text: modelData.glyph
                    color: Theme.textStrong
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontIconSize + Theme.spaceS
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Theme.spaceXs
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media[parent.modelData.act]()
                    }
                }
            }
        }
    }

    Row {
        width: parent.width
        spacing: Theme.spaceS
        Text {
            width: parent.width - appearanceButton.width - powerButton.width - parent.spacing * 2
            anchors.verticalCenter: parent.verticalCenter
            text: Battery.present ? "Battery · " + Battery.percent + "%" : "Control Centre"
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontCaption
        }
        FlyoutChip {
            id: appearanceButton
            text: "Appearance"
            onClicked: root.cc.page = "appearance"
        }
        IconButton {
            id: powerButton
            icon: "󰐥"
            onClicked: root.cc.page = "power"
        }
    }
}
