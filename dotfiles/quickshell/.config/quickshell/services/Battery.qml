// Singularity - Quickshell
// ~/.config/quickshell/services/Battery.qml
//
// The machine's battery, shared by the bar, its flyout and the System
// window so they all agree on which device that is.

pragma Singleton

import Quickshell
import Quickshell.Services.UPower
import QtQuick

Singleton {
    // UPower's DisplayDevice is a synthetic aggregate: it reports a
    // percentage but not necessarily powerSupply, so isLaptopBattery is
    // false on it and it can't be used to decide whether this machine even
    // has a battery. Prefer the real one, fall back to the aggregate.
    readonly property UPowerDevice device: {
        var ds = UPower.devices ? UPower.devices.values : []
        for (var i = 0; i < ds.length; i++) {
            if (ds[i].isLaptopBattery) return ds[i]
        }
        return UPower.displayDevice
    }
    readonly property bool present: !!device && device.ready && device.isPresent
    readonly property int percent: device && device.ready ? Math.round(device.percentage * 100) : 0
}
