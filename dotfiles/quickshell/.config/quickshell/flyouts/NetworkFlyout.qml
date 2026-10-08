// Singularity - Quickshell
// ~/.config/quickshell/flyouts/NetworkFlyout.qml
//
// The iwd network list and passphrase prompt. The state and the iwctl
// calls live in services/Network.qml.

import QtQuick
import "../services"

FlyoutPanel {
    id: netFlyout
    flyout: "network"
    menuWidth: 280

    required property var bar

    // "" when browsing the list; an SSID while its passphrase is
    // being typed. Only then does the panel take keyboard focus.
    property string pendingSsid: ""
    wantsKeyboard: pendingSsid !== ""
    onOpenChanged: if (!open) { pendingSsid = ""; pass.text = "" }

    function connectTo(ssid, passphrase) {
        Network.connect(ssid, passphrase)
        pendingSsid = ""
        pass.text = ""
        // stays open so the row can show it connecting
    }

    FlyoutHeading {
        text: netFlyout.pendingSsid !== ""
            ? "PASSPHRASE"
            : (Network.ssid !== "" ? "NETWORK  " + Network.ssid : "NETWORK  offline")
    }

    // --- passphrase prompt ---
    FlyoutRow {
        visible: netFlyout.pendingSsid !== ""
        label: netFlyout.pendingSsid
        enabled: false
    }

    FlyoutInput {
        id: pass
        bleed: true
        visible: netFlyout.pendingSsid !== ""
        placeholder: "passphrase"
        onAccepted: netFlyout.connectTo(netFlyout.pendingSsid, text)
        onEscapePressed: { netFlyout.pendingSsid = ""; text = "" }
    }

    FlyoutRow {
        visible: netFlyout.pendingSsid !== ""
        label: "Connect"
        trailing: ""
        onActivated: netFlyout.connectTo(netFlyout.pendingSsid, pass.text)
    }

    FlyoutRow {
        visible: netFlyout.pendingSsid !== ""
        label: "Cancel"
        onActivated: { netFlyout.pendingSsid = ""; pass.text = "" }
    }

    // --- network list ---
    // the radio, as a switch like the Settings page's
    FlyoutAction {
        visible: netFlyout.pendingSsid === ""
        icon: Network.powered ? "󰖩" : "󰖪"
        label: "Wi-Fi"
        status: Network.device === "" ? "No wireless device" : ""
        enabled: Network.device !== ""
        checked: Network.powered
        onActivated: Network.setPowered(!Network.powered)
    }

    FlyoutRow {
        visible: netFlyout.pendingSsid === "" && Network.powered
        label: Network.scanning ? "Scanning…" : "Rescan"
        trailing: Network.device
        busy: Network.scanning
        onActivated: Network.scan()
    }

    Repeater {
        // iwctl already orders by signal, so the cap keeps the ten
        // strongest rather than an arbitrary ten
        model: netFlyout.pendingSsid === "" && Network.powered ? Network.networks.slice(0, 10) : []

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
            highlighted: modelData.connected
            // only a saved network has anything to forget
            actionIcon: modelData.known ? "󰆴" : ""
            actionHint: "Forget " + modelData.ssid + "?"
            onAction: Network.forget(modelData.ssid)
            onActivated: {
                if (modelData.connected || connecting) return
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
            : Network.scanning ? "Looking for networks…" : "No networks found"
        enabled: false
        visible: netFlyout.pendingSsid === "" && Network.powered && Network.device !== ""
            && Network.networks.length === 0
    }

    FlyoutRow {
        label: "+ " + (Network.networks.length - 10) + " weaker"
        enabled: false
        visible: netFlyout.pendingSsid === "" && Network.powered && Network.networks.length > 10
    }

    FlyoutDivider { visible: netFlyout.pendingSsid === "" }

    FlyoutRow {
        visible: netFlyout.pendingSsid === ""
        label: "More in Settings"
        trailing: "󰁔"
        onActivated: scope.openSettings("network")
    }
}
