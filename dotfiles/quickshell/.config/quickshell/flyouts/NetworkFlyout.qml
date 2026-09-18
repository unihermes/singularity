// Neutrino - Quickshell
// ~/.config/quickshell/NetworkFlyout.qml
//
// The iwd network list and passphrase prompt, split out of shell.qml.
// Connecting runs through bar.connectNetwork(), since the Process that
// actually runs iwctl is owned by the bar (it also drives the post-connect
// status refresh other bar state depends on).

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
        // --passphrase rather than iwd's interactive prompt, which
        // needs a tty. It does put the passphrase in this process's
        // argv for the lifetime of the call, where anything running
        // as this user could read it out of ps.
        var cmd = ["iwctl"]
        if (passphrase !== "") cmd.push("--passphrase", passphrase)
        cmd.push("station", bar.netDevice, "connect", ssid)
        bar.connectNetwork(cmd)
        pendingSsid = ""
        pass.text = ""
        scope.openFlyout = ""
    }

    FlyoutHeading {
        text: netFlyout.pendingSsid !== ""
            ? "PASSPHRASE"
            : (bar.netSsid !== "" ? "NETWORK  " + bar.netSsid : "NETWORK  offline")
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
        trailing: bar.netDevice
        onActivated: bar.scanNetworks()
    }

    Repeater {
        // iwctl already orders by signal, so the cap keeps the ten
        // strongest rather than an arbitrary ten
        model: netFlyout.pendingSsid === "" ? bar.netList.slice(0, 10) : []

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
        label: bar.netDevice === "" ? "No wifi device"
            : bar.netListError !== "" ? bar.netListError : "No networks found"
        enabled: false
        visible: netFlyout.pendingSsid === "" && bar.netList.length === 0
    }

    FlyoutRow {
        label: "+ " + (bar.netList.length - 10) + " weaker"
        enabled: false
        visible: netFlyout.pendingSsid === "" && bar.netList.length > 10
    }
}
