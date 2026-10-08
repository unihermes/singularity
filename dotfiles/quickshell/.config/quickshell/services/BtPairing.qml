// Singularity - Quickshell
// ~/.config/quickshell/services/BtPairing.qml
//
// Pairing started from the shell, and what follows it: the new device is
// trusted and connected once the bond exists. Done here, once per device,
// rather than in each row showing it -- the flyout and the Settings page
// can both be open, and each would connect it again.

pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // devices a pair() is running for
    property var pending: []

    // Native pair() works because bt-agent.service keeps a pairing agent
    // registered -- without one BlueZ fails this with "No agent available
    // for request type 2" and the row silently reverts to its previous state.
    function pair(device) {
        if (pending.indexOf(device) === -1) pending = pending.concat([device])
        device.pair()
    }

    function drop(device) {
        pending = pending.filter(d => d !== device)
    }

    Instantiator {
        model: ScriptModel { values: root.pending }

        Connections {
            required property var modelData
            target: modelData

            function onPairedChanged() {
                if (!modelData.paired) return
                // a device that isn't trusted is not allowed to reconnect
                // itself when you power it back on
                modelData.trusted = true
                // pair() returns once the bond exists, which is not the same
                // as the device being usable -- headphones bond and then sit
                // idle until something connects them
                if (!modelData.connected) modelData.connect()
                root.drop(modelData)
            }

            // a pairing that ended without a bond: refused, or timed out
            function onPairingChanged() {
                if (!modelData.pairing && !modelData.paired) root.drop(modelData)
            }
        }
    }
}
