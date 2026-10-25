// Singularity - Quickshell
// ~/.config/quickshell/flyouts/PeripheralsFlyout.qml
//
// A tile per peripheral with a battery (Peripherals): its glyph (a bolt
// beside it while charging), level and name, its charge as a meter; dimmed
// while it's off. Self-contained: only needs Peripherals.

import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "peripherals"
    menuWidth: Theme.flyoutMenuWidth

    FlyoutHeading { text: "PERIPHERALS" }

    FlyoutRow {
        visible: Peripherals.devices.length === 0
        label: "No peripherals with a battery"
        enabled: false
    }

    TileGrid {
        visible: Peripherals.devices.length > 0
        columns: Math.max(1, Math.min(2, Peripherals.devices.length))
        Repeater {
            model: Peripherals.devices
            FlyoutTile {
                id: tile
                required property var modelData
                readonly property bool on: modelData.level >= 0
                width: parent.cell
                big: true
                glyph: modelData.glyph + (modelData.charging ? " 󱐋" : "")
                title: on ? modelData.level + "%" : "Off"
                caption: modelData.name
                dimmed: !on

                Meter {
                    visible: tile.on
                    width: tile.width - Theme.spaceL * 2
                    fraction: tile.modelData.level / 100
                    fillColor: tile.modelData.charging ? Theme.good
                        : tile.modelData.level <= 20 ? Theme.alert : Theme.meterFill
                }
            }
        }
    }
}
