// Singularity - Quickshell
// ~/.config/quickshell/flyouts/NetworkFlyout.qml
//
// The radio switch on the heading, the joined network as a card (as on the
// Settings page), the five strongest others under NEARBY with Rescan on
// that heading, and the passphrase prompt. The state and the iwctl calls
// live in services/Network.qml.

import QtQuick
import "../services"

FlyoutPanel {
    id: netFlyout
    flyout: "network"
    menuWidth: 280

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

    FlyoutHeading {
        text: netFlyout.browsing ? "NETWORK" : "PASSPHRASE"
        // the radio, as a switch like the Settings page's
        control: netFlyout.browsing && Network.device !== "" ? radioSwitch : null
    }

    Component {
        id: radioSwitch
        Switch {
            checked: Network.powered
            onToggled: Network.setPowered(!Network.powered)
        }
    }

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

    // --- the link ---
    // the cable, on a machine that has a port; nothing to switch, so a click
    // goes to its details in Settings
    FlyoutAction {
        visible: netFlyout.browsing && Network.wiredDevice !== ""
        icon: "󰛳"
        label: "Ethernet"
        status: (Network.wired ? "Connected"
            : Network.wiredState === "no-carrier" || Network.wiredState === "off" ? "Unplugged"
            : "No address yet") + "  ·  " + Network.wiredDevice
        checkable: false
        onActivated: scope.openSettings("network")
    }

    // the joined network, or why there isn't one; Disconnect while pointed at
    Item {
        visible: netFlyout.browsing
        width: parent ? parent.width : 0
        implicitHeight: card.implicitHeight

        HeadCard {
            id: card
            glyph: Network.ssid !== "" && netFlyout.joined ? Network.strengthGlyphs[Math.max(1, netFlyout.joined.bars) - 1]
                : Network.powered ? "󰤮" : "󰤭"
            glyphColor: Network.ssid !== "" ? Theme.textStrong : Theme.muted
            title: Network.device === "" ? "No wireless device"
                : !Network.powered ? "Wi-Fi is off"
                : Network.ssid !== "" ? Network.ssid
                : "Not connected"
            lines: {
                if (Network.device === "" || !Network.powered) return []
                if (Network.ssid === "") return ["Pick a network below"]
                var j = netFlyout.joined
                if (!j) return []
                return [(j.security === "open" ? "Open" : j.security === "8021x" ? "Enterprise" : "Secured")
                    + "  ·  " + ["", "Weak", "Fair", "Good", "Strong"][Math.max(1, j.bars)]]
            }

            FlyoutChip {
                visible: Network.ssid !== "" && cardHover.hovered
                text: "Disconnect"
                onClicked: Network.disconnect()
            }
        }

        HoverHandler { id: cardHover }
    }

    // --- the others ---
    FlyoutHeading {
        visible: netFlyout.browsing && Network.powered && Network.device !== ""
        text: "NEARBY" + (netFlyout.others.length > 0 ? "  " + netFlyout.others.length : "")
        control: scanButton
    }

    Component {
        id: scanButton
        IconButton {
            icon: "󰑐"
            spinning: Network.scanning
            onClicked: Network.scan()
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

    FlyoutRow {
        visible: netFlyout.browsing
        label: "More in Settings"
        trailing: "󰁔"
        onActivated: scope.openSettings("network")
    }
}
