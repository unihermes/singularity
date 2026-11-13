// Glass's Control Centre home, Apple's way, under the profile card and the
// search: a connectivity card (Wi-Fi, Bluetooth, Airplane as round
// switches; a row's name opens its details here) beside Quiet and Night
// Light, Keep Awake and Game Mode under them, the power profiles, then
// Display and Sound cards (the device named at the end; Sound's picks the
// output), a now-playing chip while a track is up, the tools as round
// buttons and the two pages as capsules.

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
    // the one card whose details are open, "" for none
    readonly property string open: cc.expanded

    width: parent.width
    spacing: Theme.spaceL

    // opens a module's own flyout in place of this one
    function details(name) {
        var item = bar ? bar.widgetItem(name) : null
        if (item) cc.scope.toggleFlyout(name, item)
    }

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
                spacing: Math.max(Theme.spaceS, (height - visibleChildren.length * Theme.fs(38)) / Math.max(1, visibleChildren.length - 1))

                GlassLink {
                    visible: Network.device !== ""
                    icon: Network.powered ? "󰤨" : "󰤭"
                    title: "Wi-Fi"
                    caption: !Network.powered ? "Off" : Network.ssid !== "" ? Network.ssid
                        : Network.wired ? "Wired" : "Not connected"
                    lit: Network.powered
                    onToggled: Network.setPowered(!Network.powered)
                    onOpened: {
                        root.cc.expand("wifi")
                        if (root.open === "wifi") Network.refreshList()
                    }
                }
                GlassLink {
                    visible: !!root.adapter
                    icon: "󰂯"
                    title: "Bluetooth"
                    caption: !root.btOn ? "Off" : root.btConnected.length === 1
                        ? root.btConnected[0].deviceName || root.btConnected[0].name
                        : root.btConnected.length > 1 ? root.btConnected.length + " connected" : "On"
                    lit: root.btOn
                    onToggled: if (root.bar) root.bar.setBtPowered(root.adapter, !root.btOn)
                    onOpened: root.cc.expand("bluetooth")
                }
                GlassLink {
                    icon: "󰀝"
                    title: "Airplane"
                    caption: root.cc.airplane ? "Radios off" : "Off"
                    lit: root.cc.airplane
                    onToggled: root.cc.setAirplane(!root.cc.airplane)
                    onOpened: root.cc.setAirplane(!root.cc.airplane)
                }
            }
        }

        Column {
            width: root.cell
            spacing: root.spacing
            GlassLinkTile {
                width: parent.width
                icon: Notifications.dnd ? "󰂛" : "󰂚"
                title: "Quiet"
                caption: Notifications.dnd ? "Banners held" : "Off"
                lit: Notifications.dnd
                onToggled: Notifications.toggleDnd()
                onOpened: Notifications.toggleDnd()
            }
            GlassLinkTile {
                width: parent.width
                icon: root.cc.shellRoot.nightLight ? "󰖔" : "󰖙"
                title: "Night Light"
                caption: root.cc.shellRoot.nightLight ? Settings.nightLightKelvin + " K" : "Off"
                lit: root.cc.shellRoot.nightLight
                usable: root.cc.shellRoot.hasHyprsunset
                onToggled: root.cc.shellRoot.nightLight = !root.cc.shellRoot.nightLight
                onOpened: root.cc.expand("night")
            }
        }
    }

    // things paired before, connected first
    readonly property var btSaved: (adapter && adapter.devices ? adapter.devices.values : [])
        .filter(d => d.paired || d.connected)
        .sort((x, y) => x.connected !== y.connected ? (x.connected ? -1 : 1)
            : (x.deviceName || "").localeCompare(y.deviceName || ""))
    readonly property var btConnected: btSaved.filter(d => d.connected)

    // the open card's details
    GlassCard {
        visible: root.open === "wifi" || root.open === "bluetooth" || root.open === "night"
        width: parent.width
        height: detailCol.height + Theme.spaceM * 2

        Column {
            id: detailCol
            x: Theme.spaceS
            y: Theme.spaceM
            width: parent.width - Theme.spaceS * 2

            GlassDetailHead {
                visible: root.open === "wifi"
                text: "Networks"
                more: "Wi-Fi Settings…"
                onMoreClicked: root.details("network")
            }
            Repeater {
                model: ScriptModel { values: root.open === "wifi" && Network.powered ? Network.networks.slice(0, 5) : [] }
                GlassDetailRow {
                    required property var modelData
                    icon: Network.strengthGlyphs[Math.max(1, modelData.bars) - 1]
                    label: modelData.ssid
                    current: modelData.connected
                    trailing: Network.connecting === modelData.ssid ? "connecting"
                        : !modelData.known && modelData.security !== "open" ? "󰌾" : ""
                    // one that needs a passphrase asks for it in the Network flyout
                    onActivated: {
                        if (modelData.connected) return
                        if (modelData.known || modelData.security === "open") Network.connect(modelData.ssid, "")
                        else root.details("network")
                    }
                }
            }

            GlassDetailHead {
                visible: root.open === "bluetooth"
                text: "Devices"
                more: "Bluetooth Settings…"
                onMoreClicked: root.details("bluetooth")
            }
            Repeater {
                model: ScriptModel { values: root.open === "bluetooth" && root.btOn ? root.btSaved : [] }
                GlassDetailRow {
                    required property var modelData
                    icon: "󰂯"
                    label: modelData.deviceName || modelData.name
                    trailing: modelData.connected ? "Connected" : "Not connected"
                    onActivated: modelData.connected ? modelData.disconnect() : modelData.connect()
                }
            }

            GlassDetailHead {
                visible: root.open === "night"
                text: "Warmth"
                more: Settings.nightLightKelvin + " K"
            }
            GlassSlider {
                readonly property var lim: Settings.limits.nightLightKelvin
                visible: root.open === "night"
                x: Theme.spaceS
                width: parent.width - Theme.spaceS * 2
                icon: "󰔏"
                // warmer to the right: the fill grows as the kelvins drop
                value: Math.round((lim.max - Settings.nightLightKelvin) / (lim.max - lim.min) * 100)
                onMoved: v => Settings.set("nightLightKelvin", Math.round((lim.max - v / 100 * (lim.max - lim.min)) / 250) * 250)
            }
        }
    }

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
            icon: "󰊴"
            title: "Game Mode"
            caption: GameMode.active ? "On" : "Off"
            lit: GameMode.active
            onToggled: GameMode.toggle()
            onOpened: GameMode.toggle()
        }
    }

    // the power profiles, one lit
    Row {
        id: profiles
        visible: PpdProfile.profile !== ""
        width: parent.width
        spacing: Theme.spaceM
        Repeater {
            model: PpdProfile.choices
            Rectangle {
                required property var modelData
                readonly property bool on: PpdProfile.profile === modelData.value
                width: (profiles.width - profiles.spacing * (PpdProfile.choices.length - 1)) / Math.max(1, PpdProfile.choices.length)
                height: Theme.fs(32)
                radius: height / 2
                color: on ? Theme.accent : profMouse.containsMouse ? Theme.washActive : Theme.washHover
                border.width: on ? 0 : 1
                border.color: Theme.stroke
                Text {
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - Theme.spaceL * 2)
                    elide: Text.ElideRight
                    text: parent.modelData.text
                    color: parent.on ? Theme.textOnAccent : Theme.textStrong
                    font.family: Theme.fontText
                    font.weight: Theme.weightStrong
                    font.pixelSize: Theme.fontCaption
                }
                MouseArea {
                    id: profMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PpdProfile.set(parent.modelData.value)
                }
            }
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
            }
            GlassSlider {
                width: parent.width
                icon: "󰃠"
                value: root.ddc ? DdcBrightness.level(root.output) : Brightness.level
                onMoved: v => root.ddc ? DdcBrightness.set(root.output, v) : Brightness.set(v)
            }
        }
    }

    readonly property var sinks: Audio.sinks.filter(n => Audio.unplugged.indexOf(n.id) < 0 || n === Audio.sink)

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
                chevron: root.sinks.length > 1
                expanded: root.open === "output"
                onDeviceClicked: root.cc.expand("output")
            }
            GlassSlider {
                width: parent.width
                icon: Audio.muted ? "󰖁" : "󰕾"
                value: Audio.percent
                dimmed: Audio.muted
                onMoved: v => Audio.setVolume(v)
            }
            Repeater {
                model: ScriptModel { values: root.open === "output" ? root.sinks : [] }
                GlassDetailRow {
                    required property var modelData
                    icon: Audio.glyph(modelData)
                    label: Audio.plainName(modelData)
                    current: modelData === Audio.sink
                    onActivated: {
                        Pipewire.preferredDefaultAudioSink = modelData
                        root.cc.expanded = ""
                    }
                }
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
                onClicked: root.details("media")
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

    // --- Tools and pages --------------------------------------

    Row {
        width: parent.width
        readonly property var acts: root.cc.toolActions
        spacing: (width - acts.length * Theme.fs(34)) / Math.max(1, acts.length - 1)
        Repeater {
            model: parent.acts
            GlassDot {
                required property var modelData
                icon: modelData.icon
                lit: modelData.act === "record" && Recorder.recording
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cc.run(parent.modelData.act)
                }
            }
        }
    }

    Row {
        id: pages
        width: parent.width
        spacing: Theme.spaceM
        Repeater {
            model: [
                { icon: "󰏘", text: "Appearance", page: "appearance" },
                { icon: "󰕮", text: "Bar Widgets", page: "widgets" },
            ]
            Rectangle {
                required property var modelData
                width: (pages.width - pages.spacing) / 2
                height: Theme.fs(32)
                radius: height / 2
                color: pillMouse.containsMouse ? Theme.washActive : Theme.washHover
                border.width: 1
                border.color: Theme.stroke
                Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spaceS
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.parent.modelData.icon
                        color: Theme.textStrong
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontIconSize
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.parent.modelData.text
                        color: Theme.textStrong
                        font.family: Theme.fontText
                        font.weight: Theme.weightStrong
                        font.pixelSize: Theme.fontCaption
                    }
                }
                MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cc.page = parent.modelData.page
                }
            }
        }
    }
}
