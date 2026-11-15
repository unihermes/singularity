// Shared detail pages. Pane keeps its navigation beside these; Glass opens
// them as focused sheets, and the dashboard returns through the breadcrumb.
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import QtQuick
import "../services"

Column {
    id: root
    required property var cc
    readonly property string page: cc.page
    readonly property var bar: cc.scope.barWindow
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: !!bar && bar.btAdapterOn(adapter)
    readonly property var saved: (adapter && adapter.devices ? adapter.devices.values : [])
        .filter(d => d.paired || d.connected)
        .sort((a, b) => a.connected !== b.connected ? (a.connected ? -1 : 1)
            : (a.deviceName || "").localeCompare(b.deviceName || ""))
    readonly property var nearby: (adapter && adapter.devices ? adapter.devices.values : [])
        .filter(d => !d.paired && !d.connected && d.name !== "")
    readonly property var sinks: Audio.sinks.filter(n => Audio.unplugged.indexOf(n.id) < 0 || n === Audio.sink)
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool sourceReady: !!source && source.ready && !!source.audio
    readonly property string output: cc.scope.modelData.name
    readonly property bool ddc: DdcBrightness.answered.indexOf(output) >= 0
    property string pendingSsid: ""
    property bool scanning: false
    property bool allNetworks: false
    width: parent.width
    spacing: Theme.flyoutSpacing

    Binding {
        target: Audio; property: "flyoutWatching"; value: true
        when: root.cc.open && root.page === "sound"
        restoreMode: Binding.RestoreBindingOrValue
    }
    PwObjectTracker { objects: root.cc.open && root.page === "sound" ? Audio.devices : [] }

    function stopScan() {
        if (scanning && adapter && btOn) adapter.discovering = false
        scanning = false
    }
    function clearPassphrase() { pendingSsid = ""; pass.text = "" }
    function connectTo(ssid, password) {
        Network.connect(ssid, password)
        clearPassphrase()
    }
    onBtOnChanged: if (!btOn) stopScan()
    onPageChanged: { allNetworks = false; clearPassphrase(); if (page !== "bluetooth") stopScan() }
    Component.onDestruction: stopScan()
    Connections {
        target: root.cc
        function onOpenChanged() { if (!root.cc.open) { root.clearPassphrase(); root.stopScan() } }
    }
    Connections {
        target: Network
        function onPoweredChanged() { if (!Network.powered) root.clearPassphrase() }
    }
    Timer {
        interval: Theme.durMedium + 100
        running: root.cc.open && root.page === "display"
        onTriggered: if (DdcBrightness.has(root.output)) DdcBrightness.refresh()
    }

    Column {
        visible: root.page === "network"
        width: parent.width
        spacing: Theme.glass ? Theme.spaceL : Theme.spaceS
        GlassPage {
            Column {
                width: parent.width
                spacing: Theme.spaceS
        ControlRow {
            visible: Network.device !== ""
            icon: "󰤨"; title: "Wi-Fi"
            caption: Network.powered ? Network.ssid || "Not connected" : "Off"
            checked: Network.powered
            onClicked: Network.setPowered(!Network.powered)
        }
        FlyoutRow {
            visible: Network.device === ""
            label: "No Wi-Fi adapter"; enabled: false
        }
        FlyoutRow {
            visible: root.pendingSsid !== ""
            label: root.pendingSsid; enabled: false
        }
        FlyoutInput {
            id: pass
            visible: root.pendingSsid !== ""
            placeholder: "Passphrase"
            echoPassword: true
            onAccepted: root.connectTo(root.pendingSsid, text)
            onEscapePressed: root.clearPassphrase()
        }
        Row {
            visible: root.pendingSsid !== ""
            spacing: Theme.spaceS
            FlyoutChip { text: "Connect"; onClicked: root.connectTo(root.pendingSsid, pass.text) }
            FlyoutChip { text: "Cancel"; onClicked: root.clearPassphrase() }
        }
        FlyoutHeading { visible: root.pendingSsid === "" && Network.device !== ""; text: "NETWORKS" }
        Repeater {
            model: ScriptModel { values: root.page === "network" && root.pendingSsid === "" && Network.powered ? (root.allNetworks ? Network.networks : Network.networks.slice(0, 8)) : [] }
            FlyoutRow {
                required property var modelData
                label: modelData.ssid
                highlighted: modelData.connected
                busy: Network.connecting === modelData.ssid
                trailing: Network.failedSsid === modelData.ssid ? "Failed" : ""
                trailingIcons: [Network.strengthGlyphs[Math.max(1, modelData.bars) - 1]]
                onActivated: {
                    if (modelData.connected || Network.connecting === modelData.ssid) return
                    if (modelData.known || modelData.security === "open") root.connectTo(modelData.ssid, "")
                    else { root.pendingSsid = modelData.ssid; pass.forceFocus() }
                }
            }
        }
        FlyoutRow {
            visible: root.pendingSsid === "" && Network.powered && Network.networks.length > 8
            label: root.allNetworks ? "Show fewer networks" : "Show all " + Network.networks.length + " networks"
            trailingIcons: [root.allNetworks ? "󰅃" : "󰅀"]
            onActivated: root.allNetworks = !root.allNetworks
        }
        FlyoutRow {
            visible: root.pendingSsid === "" && (!Network.powered || Network.networks.length === 0)
            label: !Network.powered ? "Wi-Fi is off" : Network.listError || (Network.scanning ? "Looking for networks…" : "No networks found")
            enabled: false
        }
        Row {
            visible: Network.device !== "" && root.pendingSsid === ""
            spacing: Theme.spaceS
            FlyoutChip { text: "Rescan"; enabled: Network.powered && !Network.scanning; onClicked: Network.scan() }
            FlyoutChip { visible: Network.ssid !== ""; text: "Disconnect"; onClicked: Network.disconnect() }
        }
            }
        }
        GlassPage {
            Column {
                width: parent.width
                spacing: Theme.spaceS
        FlyoutHeading { text: "CONNECTIONS" }
        FlyoutRow {
            visible: Network.wired
            label: "Ethernet"
            trailing: "Connected"
            enabled: false
        }
        ControlRow {
            visible: Vpn.servers.length > 0
            icon: "󰖂"; title: "VPN"
            caption: Vpn.busy ? "Connecting…" : Vpn.stalled ? "No answer" : Vpn.up ? Vpn.currentName : "Off"
            checked: Vpn.up; usable: Vpn.available
            onClicked: Vpn.toggle()
        }
        Repeater {
            model: root.page === "network" ? Vpn.servers : []
            FlyoutRow {
                required property var modelData
                label: modelData.country || modelData.name
                note: modelData.country ? modelData.name : ""
                highlighted: Vpn.up && Vpn.upServer === modelData.id
                busy: Vpn.busy && Settings.vpnServer === modelData.id
                onActivated: if (!(Vpn.up && Vpn.upServer === modelData.id)) Vpn.connect(modelData.id)
            }
        }
        FlyoutChip { text: "Network settings  󰁔"; onClicked: root.cc.scope.openSettings("network") }
            }
        }
    }

    Column {
        visible: root.page === "bluetooth"
        width: parent.width
        spacing: Theme.glass ? Theme.spaceL : Theme.spaceS
        GlassPage {
            Column {
                width: parent.width
                spacing: Theme.spaceS
        ControlRow {
            icon: "󰂯"; title: "Bluetooth"
            caption: !root.adapter ? "No adapter" : root.bar && root.bar.btAdapterBlocked(root.adapter) ? "Blocked" : root.btOn ? "On" : "Off"
            usable: !!root.adapter; checked: root.btOn
            onClicked: if (root.bar) root.bar.setBtPowered(root.adapter, !root.btOn)
        }
            }
        }
        GlassPage {
            Column {
                width: parent.width
                spacing: Theme.spaceS
        FlyoutHeading { text: "YOUR DEVICES" }
        Repeater {
            model: ScriptModel { values: root.page === "bluetooth" && root.btOn ? root.saved : [] }
            BtDeviceRow { required property var modelData; device: modelData }
        }
        FlyoutRow {
            visible: !root.btOn || root.saved.length === 0
            label: !root.btOn ? "Bluetooth is off" : "No paired devices"
            enabled: false
        }
        FlyoutChip {
            text: root.scanning ? "Stop scanning" : "Pair a device"
            enabled: root.btOn
            onClicked: {
                if (root.scanning) root.stopScan()
                else { root.adapter.discovering = true; root.scanning = true }
            }
        }
        FlyoutHeading { visible: root.scanning; text: "NEARBY" }
        Repeater {
            model: ScriptModel { values: root.page === "bluetooth" && root.btOn && root.scanning ? root.nearby : [] }
            BtDeviceRow { required property var modelData; device: modelData }
        }
        FlyoutRow {
            visible: root.scanning && root.nearby.length === 0
            label: "Looking for devices…"; enabled: false
        }
        FlyoutChip { text: "Bluetooth settings  󰁔"; onClicked: root.cc.scope.openSettings("bluetooth") }
            }
        }
    }

    Column {
        visible: root.page === "sound"
        width: parent.width
        spacing: Theme.glass ? Theme.spaceL : Theme.spaceS
        GlassPage {
            Column {
                width: parent.width
                spacing: Theme.spaceS
        FlyoutSliderRow { visible: !Theme.glass; label: "Volume"; suffix: "%"; value: Audio.percent; onMoved: v => Audio.setVolume(v) }
        GlassLevelHead { visible: Theme.glass; title: "Volume"; device: Audio.percent + "%" }
        GlassSlider {
            visible: Theme.glass
            width: parent.width
            icon: Audio.muted ? "󰖁" : "󰕾"
            value: Audio.percent
            dimmed: Audio.muted
            onMoved: v => Audio.setVolume(v)
        }
        ControlRow { icon: "󰖁"; title: "Mute"; checked: Audio.muted; onClicked: Audio.toggleMute() }
            }
        }
        GlassPage {
            Column {
                width: parent.width
                spacing: Theme.spaceS
        FlyoutHeading { text: "OUTPUT" }
        Repeater {
            model: ScriptModel { values: root.page === "sound" ? root.sinks : [] }
            FlyoutRow {
                required property var modelData
                leadingIcon: Audio.glyph(modelData); label: Audio.plainName(modelData)
                highlighted: modelData === Audio.sink
                onActivated: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
        FlyoutRow { visible: root.sinks.length === 0; label: "No output devices"; enabled: false }
            }
        }
        GlassPage {
            Column {
                width: parent.width
                spacing: Theme.spaceS
        FlyoutHeading { text: "INPUT" }
        Repeater {
            model: ScriptModel { values: root.page === "sound" ? Audio.sources : [] }
            FlyoutRow {
                required property var modelData
                leadingIcon: Audio.glyph(modelData); label: Audio.plainName(modelData)
                highlighted: modelData === root.source
                onActivated: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
        FlyoutRow { visible: Audio.sources.length === 0; label: "No input devices"; enabled: false }
        ControlRow {
            visible: root.sourceReady
            icon: "󰍬"; title: "Mute microphone"
            checked: root.sourceReady && root.source.audio.muted
            onClicked: if (root.sourceReady) root.source.audio.muted = !root.source.audio.muted
        }
        FlyoutChip { text: "Sound settings  󰁔"; onClicked: root.cc.scope.openSettings("audio") }
            }
        }
    }

    Column {
        visible: root.page === "display"
        width: parent.width
        spacing: Theme.glass ? Theme.spaceL : Theme.spaceS
        GlassPage {
            Column {
                width: parent.width
                spacing: Theme.spaceS
        FlyoutRow { label: root.output; trailing: "This display"; enabled: false }
        FlyoutSliderRow {
            visible: !Theme.glass && (root.ddc || Brightness.available)
            label: "Brightness"; suffix: "%"
            value: root.ddc ? DdcBrightness.level(root.output) : Brightness.level
            onMoved: v => root.ddc ? DdcBrightness.set(root.output, v) : Brightness.set(v)
        }
        GlassLevelHead { visible: Theme.glass && (root.ddc || Brightness.available); title: "Brightness" }
        GlassSlider {
            visible: Theme.glass && (root.ddc || Brightness.available)
            width: parent.width
            icon: "󰃠"
            value: root.ddc ? DdcBrightness.level(root.output) : Brightness.level
            onMoved: v => root.ddc ? DdcBrightness.set(root.output, v) : Brightness.set(v)
        }
        FlyoutRow {
            visible: !root.ddc && !Brightness.available
            label: "Brightness control unavailable"; enabled: false
        }
            }
        }
        GlassPage {
            Column {
                width: parent.width
                spacing: Theme.spaceS
        ControlRow {
            icon: "󰖔"; title: "Night Light"; checked: root.cc.shellRoot.nightLight
            usable: root.cc.shellRoot.hasHyprsunset
            caption: root.cc.shellRoot.hasHyprsunset ? "Warmer display colours" : "Hyprsunset unavailable"
            onClicked: root.cc.shellRoot.nightLight = !root.cc.shellRoot.nightLight
        }
        FlyoutSliderRow {
            visible: root.cc.shellRoot.nightLight
            label: "Warmth"; suffix: " K"; step: 250
            value: Settings.nightLightKelvin
            minimum: Settings.limits.nightLightKelvin.min; maximum: Settings.limits.nightLightKelvin.max
            onMoved: v => Settings.set("nightLightKelvin", v)
        }
        FlyoutChip { text: "Display settings  󰁔"; onClicked: root.cc.scope.openSettings("display") }
            }
        }
    }

    Column {
        visible: root.page === "focus"
        width: parent.width
        spacing: Theme.spaceS
        ControlRow {
            icon: "󰂚"; title: "Quiet"; caption: Notifications.dnd ? "Banners held" : "Allow notifications"
            checked: Notifications.dnd; onClicked: Notifications.toggleDnd()
        }
        ControlRow {
            icon: "󰅶"; title: "Keep Awake"; caption: root.cc.shellRoot.keepAwake ? "No sleep" : "Allow idle sleep"
            checked: root.cc.shellRoot.keepAwake
            onClicked: root.cc.shellRoot.keepAwake = !root.cc.shellRoot.keepAwake
        }
        ControlRow {
            icon: "󰊴"; title: "Game Mode"; caption: GameMode.active ? "On" : "Off"
            checked: GameMode.active; onClicked: GameMode.toggle()
        }
        FlyoutRow { label: "Quiet keeps notifications in history"; enabled: false }
    }

    Column {
        visible: root.page === "tools"
        width: parent.width
        Repeater {
            model: root.cc.toolActions
            FlyoutRow {
                required property var modelData
                leadingIcon: modelData.icon; label: modelData.name
                onActivated: root.cc.run(modelData.act)
            }
        }
    }
}
