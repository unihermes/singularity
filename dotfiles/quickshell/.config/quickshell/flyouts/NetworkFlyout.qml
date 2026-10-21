// Singularity - Quickshell
// ~/.config/quickshell/flyouts/NetworkFlyout.qml
//
// The connection first, as a card: the cable when it's up, else the joined
// network. Under it what's moving now, down and up, and the last minute of
// it; then the five strongest other networks under WI-FI, with Rescan and
// the radio switch on that heading, and the passphrase prompt. The state
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

    // "" when browsing the list; an SSID while its passphrase is
    // being typed
    property string pendingSsid: ""
    readonly property bool browsing: pendingSsid === ""
    // the joined network's own entry in the scan, for its security and bars
    readonly property var joined: Network.networks.find(n => n.connected) || null
    readonly property var others: Network.networks.filter(n => !n.connected)
    onOpenChanged: if (!open) { pendingSsid = ""; pass.text = "" }

    function connectTo(ssid, passphrase) {
        Network.connect(ssid, passphrase)
        pendingSsid = ""
        pass.text = ""
        // stays open so the row can show it connecting
    }

    FlyoutHeading { text: netFlyout.browsing ? "NETWORK" : "PASSPHRASE" }

    // --- passphrase prompt ---
    FlyoutRow {
        visible: !netFlyout.browsing
        label: netFlyout.pendingSsid
        enabled: false
    }

    FlyoutInput {
        id: pass
        bleed: true
        visible: !netFlyout.browsing
        placeholder: "passphrase"
        onAccepted: netFlyout.connectTo(netFlyout.pendingSsid, text)
        onEscapePressed: { netFlyout.pendingSsid = ""; text = "" }
    }

    FlyoutRow {
        visible: !netFlyout.browsing
        label: "Connect"
        trailing: ""
        onActivated: netFlyout.connectTo(netFlyout.pendingSsid, pass.text)
    }

    FlyoutRow {
        visible: !netFlyout.browsing
        label: "Cancel"
        onActivated: { netFlyout.pendingSsid = ""; pass.text = "" }
    }

    // --- the connection ---
    // the cable while it's up (nothing to switch: a click there goes to its
    // details in Settings), else the joined network or why there isn't one,
    // Disconnect while pointed at
    Item {
        visible: netFlyout.browsing
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
                : Network.device === "" ? (Network.wiredDevice !== "" ? "Cable unplugged" : "No network device")
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

    // what's moving now, and the last minute of it
    TileGrid {
        visible: netFlyout.browsing && (Network.wired || Network.ssid !== "")
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
        visible: netFlyout.browsing && SystemStats.rxHistory.length > 1
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
        visible: netFlyout.browsing && Network.device !== ""
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

    Repeater {
        // iwctl already orders by signal, so these are the five strongest
        model: netFlyout.browsing && Network.powered ? netFlyout.others.slice(0, 5) : []

        FlyoutRow {
            required property var modelData
            label: modelData.ssid
            readonly property bool connecting: Network.connecting === modelData.ssid
            busy: connecting
            trailing: connecting ? "connecting"
                : Network.failedSsid === modelData.ssid ? "failed" : ""
            // the lock marks the ones that will ask for a passphrase rather
            // than connecting straight away
            trailingIcons: [
                !modelData.known && modelData.security !== "open" ? "󰌾" : "",
                Network.strengthGlyphs[Math.max(1, modelData.bars) - 1]
            ]
            onActivated: {
                if (connecting) return
                // a known or open network needs no passphrase: iwd
                // either has the key already or there is none
                if (modelData.known || modelData.security === "open") {
                    netFlyout.connectTo(modelData.ssid, "")
                } else {
                    netFlyout.pendingSsid = modelData.ssid
                    pass.text = ""
                    pass.forceFocus()
                }
            }
        }
    }

    FlyoutRow {
        label: Network.listError !== "" ? Network.listError
            : Network.scanning ? "Looking for networks…" : "No other networks"
        enabled: false
        visible: netFlyout.browsing && Network.powered && Network.device !== ""
            && netFlyout.others.length === 0
    }

    FlyoutRow {
        label: "Show all " + netFlyout.others.length
        trailing: "󰁔"
        visible: netFlyout.browsing && Network.powered && netFlyout.others.length > 5
        onActivated: scope.openSettings("network")
    }

    FlyoutDivider { visible: netFlyout.browsing }

    FlyoutChipLine {
        visible: netFlyout.browsing
        chips: [{ icon: "󰒓", text: "Settings", act: "settings" }]
        onPicked: scope.openSettings("network")
    }
}
