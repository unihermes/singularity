// A Bluetooth device's battery as level bars, one a line: Battery for most
// devices, L, R and Case for earbuds (BtBattery.parts), each with its
// percent; alert-red at 20% and under. Empty while it reports nothing.

import QtQuick
import "../services"
import "../flyouts"

Column {
    id: root

    required property var device

    readonly property var parts: device.connected && !device.batteryAvailable ? (BtBattery.parts[device.address] || null) : null
    readonly property var bars: {
        if (!device.connected) return []
        if (parts) return ["L", "R", "Case"].map((n, i) => ({ name: n, level: parts[i] }))
            .filter(b => b.level >= 0)
        var lv = BtBattery.level(device)
        return lv >= 0 ? [{ name: "Battery", level: lv }] : []
    }

    spacing: Theme.spaceS

    Repeater {
        model: root.bars

        Item {
            id: bar
            required property var modelData
            width: root.width
            height: Math.max(name.implicitHeight, pct.implicitHeight)

            Text {
                id: name
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(64)
                text: bar.modelData.name
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontCaption
            }
            Meter {
                anchors.left: name.right
                anchors.right: pct.left
                anchors.rightMargin: Theme.spaceM
                anchors.verticalCenter: parent.verticalCenter
                fraction: bar.modelData.level / 100
                fillColor: bar.modelData.level <= 20 ? Theme.alert : Theme.meterFill
            }
            Text {
                id: pct
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(40)
                horizontalAlignment: Text.AlignRight
                text: bar.modelData.level + "%"
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontCaption
            }
        }
    }
}
