// Neutrino - Quickshell
// ~/.config/quickshell/NetworkFlyout.qml
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
        scope.openFlyout = ""
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
        visible: netFlyout.pendingSsid !== ""
        placeholder: "passphrase"
        onAccepted: netFlyout.connectTo(netFlyout.pendingSsid, text)
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
    FlyoutRow {
        visible: netFlyout.pendingSsid === ""
        label: "Rescan"
        trailing: Network.device
        onActivated: Network.scan()
    }

    Repeater {
        // iwctl already orders by signal, so the cap keeps the ten
        // strongest rather than an arbitrary ten
        model: netFlyout.pendingSsid === "" ? Network.networks.slice(0, 10) : []

        FlyoutRow {
            required property var modelData
            label: modelData.ssid
            // "key" marks the ones that will ask for a passphrase
            // rather than connecting straight away
            trailing: {
                if (modelData.connected) return ""
                if (!modelData.known && modelData.security !== "open") return "key"
                return "•".repeat(Math.max(1, modelData.bars))
            }
            highlighted: modelData.connected
            // only a saved network has anything to forget
            actionIcon: modelData.known ? "󰆴" : ""
            actionHint: "Forget " + modelData.ssid + "?"
            onAction: Network.forget(modelData.ssid)
            onActivated: {
                if (modelData.connected) return
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
        label: Network.device === "" ? "No wifi device"
            : Network.listError !== "" ? Network.listError : "No networks found"
        enabled: false
        visible: netFlyout.pendingSsid === "" && Network.networks.length === 0
    }

    FlyoutRow {
        label: "+ " + (Network.networks.length - 10) + " weaker"
        enabled: false
        visible: netFlyout.pendingSsid === "" && Network.networks.length > 10
    }
}
