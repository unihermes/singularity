// The connection first, as a card: the cable when it's up, else the joined
// network. Under it tabs: Wired (only while the cable is up, and then first: its traffic),
// Wi-Fi (the five strongest other networks, with Rescan and the radio switch
// on its heading, and the passphrase prompt opening under the network
// picked) and Details (the connection's facts, what's moving now, down and
// up, and the last minute of it). The state
// and the iwctl calls live in services/Network.qml, the rates in
// SystemStats (sampled while this is open).

import QtQuick
import "../services"
import "../services/Format.js" as Format

FlyoutPanel {
    id: netFlyout
    flyout: "network"
    menuWidth: Theme.flyoutMenuWidth

    Binding { when: netFlyout.open; target: SystemStats; property: "flyoutActive"; value: true }

    required property var bar

    // "" when none; an SSID while its passphrase is being typed
    property string pendingSsid: ""
    // Wired only while the cable is up, then first; the tab picked, else the first
    readonly property var tabs: (Network.wired ? [{ value: "wired", text: "Wired" }] : [])
        .concat(Network.device !== "" ? [{ value: "wifi", text: "Wi-Fi" }] : [])
        .concat([{ value: "details", text: "Details" }])
    property string picked: ""
    readonly property string tab: tabs.some(t => t.value === picked) ? picked : tabs[0].value
    // the joined network's own entry in the scan, for its security and bars
    readonly property var joined: Network.networks.find(n => n.connected) || null
    readonly property var others: Network.networks.filter(n => !n.connected)
    onOpenChanged: if (!open) { pendingSsid = ""; picked = "" }

    function connectTo(ssid, passphrase) {
        Network.connect(ssid, passphrase)
        pendingSsid = ""
        // stays open so the row can show it connecting
    }

    FlyoutHeading {
        text: "NETWORK"
        settingsIcon: true
        onSettingsClicked: scope.openSettings("network")
    }

    // --- the connection ---
    // the cable while it's up (nothing to switch: a click there goes to its
    // details in Settings), else the joined network or why there isn't one,
    // Disconnect while pointed at
    Item {
        width: parent ? parent.width : 0
        implicitHeight: card.implicitHeight

        HeadCard {
            id: card
            readonly property bool cable: Network.wired
            glyph: cable ? "󰛳"
                : Network.ssid !== "" && netFlyout.joined ? Network.strengthGlyphs[Math.max(1, netFlyout.joined.bars) - 1]
                : Network.powered ? "󰤮" : "󰤭"
            glyphColor: cable || Network.ssid !== "" ? Theme.textStrong : Theme.muted
            title: cable ? "Wired"
                : Network.device === "" ? "No network device"
                : !Network.powered ? "Wi-Fi is off"
                : Network.ssid !== "" ? Network.ssid
                : "Not connected"
            lines: {
                var ip = SystemStats.ipAddr !== "" ? SystemStats.ipAddr : ""
                if (cable) return [Network.wiredDevice, ip]
                if (Network.device === "" || !Network.powered) return []
                if (Network.ssid === "") return ["Pick a network below"]
                var j = netFlyout.joined
                if (!j) return [ip]
                return [(j.security === "open" ? "Open" : j.security === "8021x" ? "Enterprise" : "Secured")
                    + "  ·  " + ["", "Weak", "Fair", "Good", "Strong"][Math.max(1, j.bars)], ip]
            }

            FlyoutChip {
                visible: !card.cable && Network.ssid !== "" && cardHover.hovered
                text: "Disconnect"
                onClicked: Network.disconnect()
            }
            FlyoutChip {
                visible: card.cable && cardHover.hovered
                text: "Details  󰁔"
                onClicked: scope.openSettings("network")
            }
        }

        HoverHandler { id: cardHover }
    }

    FlyoutSegmented {
        model: netFlyout.tabs
        current: netFlyout.tab
        onPicked: v => netFlyout.picked = v
    }

    // --- Wired: its traffic below (shared with Details), and a way to its settings ---
    FlyoutRow {
        visible: netFlyout.tab === "wired"
        label: "Network settings"
        trailing: "󰁔"
        onActivated: scope.openSettings("network")
    }

    // --- Details: what's moving now, and the last minute of it ---
    FlyoutRow {
        visible: netFlyout.tab === "details" && !!netFlyout.joined && Network.ssid !== ""
        leadingIcon: "󰖩"
        label: "Wi-Fi"
        trailing: Network.ssid
        trailingIsValue: true
        enabled: false
    }
    FlyoutRow {
        visible: netFlyout.tab === "details" && SystemStats.ipAddr !== ""
        leadingIcon: "󰩟"
        label: "Address"
        trailing: SystemStats.ipAddr
        trailingIsValue: true
        enabled: false
    }
    TileGrid {
        visible: (netFlyout.tab === "details" || netFlyout.tab === "wired") && (Network.wired || Network.ssid !== "")
        columns: 2
        FlyoutTile {
            width: parent.cell
            glyph: "󰇚"
            title: Format.rate(SystemStats.rxRate)
            big: true
            caption: "Down"
        }
        FlyoutTile {
            width: parent.cell
            glyph: "󰕒"
            title: Format.rate(SystemStats.txRate)
            big: true
            caption: "Up"
        }
    }

    Spark {
        visible: (netFlyout.tab === "details" || netFlyout.tab === "wired") && SystemStats.rxHistory.length > 1
        height: Theme.row(40)
        readonly property real peak: Math.max(65536,
            Math.max.apply(null, SystemStats.rxHistory.concat(SystemStats.txHistory, [0])))
        series: [
            { values: SystemStats.rxHistory, color: Theme.accent, fill: true },
            { values: SystemStats.txHistory, color: Theme.subtext, fill: false },
        ]
        ceiling: peak * 1.15
    }

    // --- the others ---
    FlyoutHeading {
        visible: netFlyout.tab === "wifi"
        text: "WI-FI" + (Network.powered && netFlyout.others.length > 0 ? "  " + netFlyout.others.length : "")
        control: headingControls
    }

    // Rescan, while the radio is on, then the radio switch
    Component {
        id: headingControls
        Row {
            spacing: Theme.spaceM
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Network.powered
                icon: "󰑐"
                spinning: Network.scanning
                onClicked: Network.scan()
            }
            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Network.powered
                onToggled: Network.setPowered(!Network.powered)
            }
        }
    }

    // the joined network, when the cable's card is the one on top
    FlyoutRow {
        visible: netFlyout.tab === "wifi" && Network.powered && Network.wired && Network.ssid !== ""
        label: Network.ssid
        highlighted: true
        trailing: "connected"
        trailingIsValue: true
        onActivated: Network.disconnect()
    }

    Repeater {
        // iwctl already orders by signal, so these are the five strongest
        model: netFlyout.tab === "wifi" && Network.powered ? netFlyout.others.slice(0, 5) : []

        Column {
            id: net
            required property var modelData
            readonly property bool connecting: Network.connecting === modelData.ssid
            readonly property bool prompting: netFlyout.pendingSsid === modelData.ssid
            width: parent ? parent.width : 0
            spacing: Theme.flyoutSpacing
            onPromptingChanged: if (prompting) pass.forceFocus(); else pass.text = ""

            FlyoutRow {
                width: parent.width
                label: net.modelData.ssid
                busy: net.connecting
                trailing: net.connecting ? "connecting"
                    : Network.failedSsid === net.modelData.ssid ? "failed" : ""
                // the lock marks the ones that will ask for a passphrase rather
                // than connecting straight away
                trailingIcons: [
                    !net.modelData.known && net.modelData.security !== "open" ? "󰌾" : "",
                    Network.strengthGlyphs[Math.max(1, net.modelData.bars) - 1]
                ]
                onActivated: {
                    if (net.connecting) return
                    // a known or open network needs no passphrase: iwd
                    // either has the key already or there is none
                    if (net.modelData.known || net.modelData.security === "open") {
                        netFlyout.connectTo(net.modelData.ssid, "")
                    } else {
                        netFlyout.pendingSsid = net.prompting ? "" : net.modelData.ssid
                    }
                }
            }

            // the passphrase, under the network it's for
            FlyoutInput {
                id: pass
                width: parent.width
                visible: net.prompting
                placeholder: "passphrase"
                onAccepted: netFlyout.connectTo(net.modelData.ssid, text)
                onEscapePressed: netFlyout.pendingSsid = ""
            }
            FlyoutChipLine {
                visible: net.prompting
                chips: [{ icon: "󰄬", text: "Connect", act: "connect" }, { icon: "󰅖", text: "Cancel", act: "cancel" }]
                onPicked: act => act === "connect" ? netFlyout.connectTo(net.modelData.ssid, pass.text)
                                                   : netFlyout.pendingSsid = ""
            }
        }
    }

    FlyoutRow {
        label: Network.listError !== "" ? Network.listError
            : Network.scanning ? "Looking for networks…" : "No other networks"
        enabled: false
        visible: netFlyout.tab === "wifi" && Network.powered && netFlyout.others.length === 0
    }

    FlyoutRow {
        label: "Show all " + netFlyout.others.length
        trailing: "󰁔"
        visible: netFlyout.tab === "wifi" && Network.powered && netFlyout.others.length > 5
        onActivated: scope.openSettings("network")
    }

}
