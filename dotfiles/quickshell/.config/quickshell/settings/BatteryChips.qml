// Singularity - Quickshell
// ~/.config/quickshell/settings/BatteryChips.qml
//
// A Bluetooth device's battery as small level chips on one line: one for
// most devices, Left, Right and Case for earbuds (BtBattery.parts). Empty
// while it reports nothing.

import QtQuick
import "../services"
import "../flyouts"

Row {
    id: root

    required property var device

    readonly property var parts: device.connected && !device.batteryAvailable ? (BtBattery.parts[device.address] || null) : null
    readonly property var chips: {
        if (!device.connected) return []
        if (parts) return ["L", "R", "Case"].map((n, i) => ({ text: n + " " + parts[i] + "%", level: parts[i] }))
            .filter(c => c.level >= 0)
        var lv = BtBattery.level(device)
        return lv >= 0 ? [{ text: lv + "%", level: lv }] : []
    }

    spacing: Theme.spaceS

    Repeater {
        model: root.chips

        Meter {
            required property var modelData
            width: Math.max(Theme.fit(56), label.implicitWidth + Theme.spaceM * 2)
            height: Theme.chipHeight
            fraction: modelData.level / 100
            fillColor: modelData.level <= 20 ? Theme.alert : Theme.good

            Text {
                id: label
                anchors.centerIn: parent
                text: parent.modelData.text
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontCaption
            }
        }
    }
}
