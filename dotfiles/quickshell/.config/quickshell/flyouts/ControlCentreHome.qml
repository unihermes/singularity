// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ControlCentreHome.qml
//
// The Control Centre's home under every style but Glass, under the header
// card and search: Sound (volume, whose chevron picks the output, and this
// screen's brightness), Connectivity (Wi-Fi, Bluetooth, VPN, Airplane),
// Quick settings, a now-playing line while something plays, then the tools
// and the two pages as one strip. Each group is a section of its own. The
// rows say their state in words before the style's switch; a split row's
// chevron lists its networks, devices, servers or setting in place, one at
// a time (cc.expanded).

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import QtQuick
import "../services"

Column {
    id: root

    required property var cc
    readonly property var bar: cc.scope.barWindow
    readonly property string open: cc.expanded

    // its children get sections as if they sat in the panel
    readonly property bool isSectionGroup: true
    readonly property bool sectioned: true

    width: parent.width
    spacing: Theme.flyoutSpacing

    // opens a module's own flyout in place of this one
    function details(name) {
        var item = bar ? bar.widgetItem(name) : null
        if (item) cc.scope.toggleFlyout(name, item)
    }

    // details in place: indented under a rule, as the Settings pages do
    component Drawer: Item {
        default property alias rows: list.data
        width: parent ? parent.width : 0
        height: list.height + Theme.spaceXs * 2

        Rectangle {
            x: Theme.spaceM
            width: 2
            height: parent.height
            color: Theme.stroke
        }
        Column {
            id: list
            x: Theme.spaceM + 2 + Theme.spaceL
            y: Theme.spaceXs
            width: parent.width - x
        }
    }

    // a level row: glyph button, slider, value, and an end that is either
    // a chevron or the room one would take, so the sliders line up
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
        height: Theme.rowHeightTall
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

    // --- Sound ------------------------------------------------

    readonly property var sinks: Audio.sinks.filter(n => Audio.unplugged.indexOf(n.id) < 0 || n === Audio.sink)

    Level {
        icon: Audio.muted ? "󰖁" : "󰕾"
        warn: Audio.muted
        value: Audio.percent
        valueText: Audio.muted ? "Muted" : Audio.percent + "%"
        chevron: root.sinks.length > 1
        expanded: root.open === "output"
        onIconClicked: Audio.toggleMute()
        onMoved: v => Audio.setVolume(v)
        onMoreClicked: root.cc.expand("output")
    }

    Drawer {
        visible: root.open === "output"
        Repeater {
            model: ScriptModel { values: root.open === "output" ? root.sinks : [] }
            FlyoutRow {
                required property var modelData
                leadingIcon: Audio.glyph(modelData)
                label: Audio.plainName(modelData)
                highlighted: modelData === Audio.sink
                onActivated: {
                    Pipewire.preferredDefaultAudioSink = modelData
                    root.cc.expanded = ""
                }
            }
        }
    }

    // this screen's brightness: its DDC monitor, else the backlight
    readonly property string output: cc.scope.modelData.name
    readonly property bool ddc: DdcBrightness.answered.indexOf(output) >= 0
    readonly property int brightness: ddc ? DdcBrightness.level(output) : Brightness.level

    Level {
        visible: root.ddc || Brightness.available
        icon: "󰃠"
        value: root.brightness
        onIconClicked: root.details("brightness")
        onMoved: v => root.ddc ? DdcBrightness.set(root.output, v) : Brightness.set(v)
    }

    // The monitor's own buttons may have moved it since the last look. Read
    // once the box is up: a DDC read on the wire holds up the first frame.
    Timer {
        id: ddcRead
        interval: Theme.durMedium + 100
        onTriggered: if (DdcBrightness.has(root.output)) DdcBrightness.refresh()
    }
    Connections {
        target: root.cc
        function onOpenChanged() { if (root.cc.open) ddcRead.restart(); else ddcRead.stop() }
    }

    FlyoutDivider {}

    // --- Connectivity -----------------------------------------

    ControlRow {
        visible: Network.device !== ""
        icon: !Network.powered ? "󰤭" : Network.ssid !== "" ? "󰤨" : "󰤯"
        title: "Wi-Fi"
        caption: !Network.powered ? "Off"
            : Network.connecting !== "" ? "Connecting…"
            : Network.ssid !== "" ? Network.ssid : "Not connected"
        checked: Network.powered
        split: true
        expanded: root.open === "wifi"
        onClicked: Network.setPowered(!Network.powered)
        onMoreClicked: {
            root.cc.expand("wifi")
            if (root.open === "wifi") Network.refreshList()
        }
    }

    Drawer {
        visible: root.open === "wifi"
        Repeater {
            model: ScriptModel { values: root.open === "wifi" && Network.powered ? Network.networks.slice(0, 6) : [] }
            FlyoutRow {
                required property var modelData
                readonly property bool connecting: Network.connecting === modelData.ssid
                label: modelData.ssid
                highlighted: modelData.connected
                busy: connecting
                trailing: connecting ? "connecting" : Network.failedSsid === modelData.ssid ? "failed" : ""
                trailingIcons: [
                    !modelData.known && modelData.security !== "open" ? "󰌾" : "",
                    Network.strengthGlyphs[Math.max(1, modelData.bars) - 1]
                ]
                // one that needs a passphrase asks for it in the Network flyout
                onActivated: {
                    if (modelData.connected || connecting) return
                    if (modelData.known || modelData.security === "open") Network.connect(modelData.ssid, "")
                    else root.details("network")
                }
            }
        }
        FlyoutRow {
            visible: !Network.powered || Network.networks.length === 0
            enabled: false
            label: !Network.powered ? "Wi-Fi is off"
                : Network.listError !== "" ? Network.listError
                : Network.scanning ? "Looking for networks…" : "No networks"
        }
        FlyoutRow {
            leadingIcon: "󰒓"
            label: "More in Network"
            trailingIcons: ["󰅂"]
            onActivated: root.details("network")
        }
    }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: !!bar && bar.btAdapterOn(adapter)
    // things paired before, connected first
    readonly property var btSaved: (adapter && adapter.devices ? adapter.devices.values : [])
        .filter(d => d.paired || d.connected)
        .sort((x, y) => x.connected !== y.connected ? (x.connected ? -1 : 1)
            : (x.deviceName || "").localeCompare(y.deviceName || ""))
    readonly property var btConnected: btSaved.filter(d => d.connected)

    ControlRow {
        visible: !!root.adapter
        icon: !root.btOn ? "󰂲" : root.btConnected.length > 0 ? "󰂱" : "󰂯"
        title: "Bluetooth"
        caption: !root.btOn ? (root.bar && root.bar.btAdapterBlocked(root.adapter) ? "Blocked" : "Off")
            : root.btConnected.length === 1 ? root.btConnected[0].deviceName || root.btConnected[0].name
            : root.btConnected.length > 1 ? root.btConnected.length + " connected"
            : root.btSaved.length + " paired"
        checked: root.btOn
        split: true
        expanded: root.open === "bluetooth"
        onClicked: if (root.bar) root.bar.setBtPowered(root.adapter, !root.btOn)
        onMoreClicked: root.cc.expand("bluetooth")
    }

    Drawer {
        visible: root.open === "bluetooth"
        Repeater {
            model: ScriptModel { values: root.open === "bluetooth" && root.btOn ? root.btSaved : [] }
            BtDeviceRow { required property var modelData; device: modelData }
        }
        FlyoutRow {
            visible: !root.btOn
            enabled: false
            label: "Bluetooth is off"
        }
        FlyoutRow {
            leadingIcon: "󰐕"
            label: "Pair a device"
            trailingIcons: ["󰅂"]
            onActivated: root.details("bluetooth")
        }
    }

    ControlRow {
        visible: Vpn.servers.length > 0
        icon: Vpn.up ? "󰦝" : "󰖂"
        title: "VPN"
        caption: Vpn.busy ? "…" : Vpn.stalled ? "No answer"
            : Vpn.up ? Vpn.currentName : "Off"
        checked: Vpn.up
        usable: Vpn.available
        split: true
        expanded: root.open === "vpn"
        onClicked: Vpn.toggle()
        onMoreClicked: root.cc.expand("vpn")
    }

    Drawer {
        visible: root.open === "vpn"
        Repeater {
            model: ScriptModel { values: root.open === "vpn" ? Vpn.servers.slice(0, 6) : [] }
            FlyoutRow {
                required property var modelData
                readonly property bool on: Vpn.up && Vpn.upServer === modelData.id
                label: modelData.country || modelData.name
                note: modelData.country ? modelData.name : ""
                highlighted: on
                busy: Vpn.busy && Settings.vpnServer === modelData.id
                trailingIcons: [modelData.pf ? "󰓢" : ""]
                onActivated: if (!on) Vpn.connect(modelData.id)
            }
        }
        FlyoutRow {
            leadingIcon: "󰒓"
            label: "More in VPN"
            trailingIcons: ["󰅂"]
            onActivated: root.details("vpn")
        }
    }

    ControlRow {
        icon: root.cc.airplane ? "󰀝" : "󰀞"
        title: "Airplane"
        caption: root.cc.airplane ? "Radios off" : "Off"
        checked: root.cc.airplane
        onClicked: root.cc.setAirplane(!root.cc.airplane)
    }

    FlyoutDivider {}

    // --- Quick settings ---------------------------------------

    ControlRow {
        icon: Notifications.dnd ? "󰂛" : "󰂚"
        title: "Quiet"
        caption: Notifications.dnd ? "Banners held" : "Off"
        checked: Notifications.dnd
        onClicked: Notifications.toggleDnd()
    }

    ControlRow {
        icon: root.cc.shellRoot.nightLight ? "󰖔" : "󰖙"
        title: "Night Light"
        caption: root.cc.shellRoot.nightLight ? Settings.nightLightKelvin + " K" : "Off"
        checked: root.cc.shellRoot.nightLight
        usable: root.cc.shellRoot.hasHyprsunset
        split: true
        expanded: root.open === "night"
        onClicked: root.cc.shellRoot.nightLight = !root.cc.shellRoot.nightLight
        onMoreClicked: root.cc.expand("night")
    }

    FlyoutSliderRow {
        visible: root.open === "night"
        label: "Warmth"
        suffix: "K"
        step: 250
        value: Settings.nightLightKelvin
        minimum: Settings.limits.nightLightKelvin.min
        maximum: Settings.limits.nightLightKelvin.max
        onMoved: v => Settings.set("nightLightKelvin", v)
    }

    ControlRow {
        icon: root.cc.shellRoot.keepAwake ? "󰅶" : "󰾪"
        title: "Keep Awake"
        caption: root.cc.shellRoot.keepAwake ? "No sleep" : "Off"
        checked: root.cc.shellRoot.keepAwake
        onClicked: root.cc.shellRoot.keepAwake = !root.cc.shellRoot.keepAwake
    }

    ControlRow {
        icon: "󰊴"
        title: "Game Mode"
        caption: GameMode.active ? "On" : "Off"
        checked: GameMode.active
        onClicked: GameMode.toggle()
    }

    // a click steps the profile; the chevron shows all three
    ControlRow {
        visible: PpdProfile.profile !== ""
        icon: "󰓅"
        title: "Power"
        caption: (PpdProfile.choices.find(c => c.value === PpdProfile.profile) || { text: "" }).text
        checkable: false
        split: true
        expanded: root.open === "profile"
        onClicked: PpdProfile.set(root.cc.nextOf(PpdProfile.choices.map(c => c.value), PpdProfile.profile))
        onMoreClicked: root.cc.expand("profile")
    }

    FlyoutSegmented {
        visible: root.open === "profile" && PpdProfile.profile !== ""
        model: PpdProfile.choices
        current: PpdProfile.profile
        onPicked: v => PpdProfile.set(v)
    }

    // --- Now playing ------------------------------------------

    readonly property bool playing: !!Media.player && Media.titleOf(Media.player) !== ""
    function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;") }

    FlyoutDivider { visible: root.playing }

    Item {
        visible: root.playing
        width: parent.width
        height: Theme.rowHeightTall

        Text {
            id: noteGlyph
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconCell
            horizontalAlignment: Text.AlignHCenter
            text: "󰎆"
            color: Theme.accent
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
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
                onClicked: root.details("media")
            }
        }
        Row {
            id: transport
            anchors.right: parent.right
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

    FlyoutDivider {}

    // --- Tools and pages --------------------------------------

    // the hovered button's name, shown in the header card
    readonly property var stripActs: cc.toolActions.concat([
        { icon: "󰏘", page: "appearance", name: "Appearance" },
        { icon: "󰕮", page: "widgets", name: "Bar Widgets" },
    ])

    Row {
        id: strip
        width: parent.width
        spacing: Theme.spaceS

        Repeater {
            model: root.stripActs

            FlyoutChip {
                required property var modelData
                width: (strip.width - strip.spacing * (root.stripActs.length - 1)) / root.stripActs.length
                height: Theme.fieldHeight + Theme.spaceS
                glyph: true
                text: modelData.icon
                onClicked: modelData.page ? root.cc.page = modelData.page : root.cc.run(modelData.act)

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) root.cc.toolHover = parent.modelData.name
                        else if (root.cc.toolHover === parent.modelData.name) root.cc.toolHover = ""
                    }
                }
            }
        }
    }
}
