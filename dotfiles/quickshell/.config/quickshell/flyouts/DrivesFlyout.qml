// Singularity - Quickshell
// ~/.config/quickshell/flyouts/DrivesFlyout.qml
//
// Each removable drive as a heading, its filesystems as rows: a click
// mounts one and opens it, or opens one already mounted. Eject after each
// drive's rows unmounts it all and powers it off. Self-contained: only
// needs Drives.

import QtQuick
import "../services"
import "../services/Format.js" as Format

FlyoutPanel {
    id: root
    flyout: "drives"
    menuWidth: Theme.flyoutMenuWidth

    FlyoutHeading {
        visible: Drives.count === 0
        text: "DRIVES"
    }
    FlyoutRow {
        visible: Drives.count === 0
        label: "No removable drives"
        enabled: false
    }

    Repeater {
        model: Drives.drives

        Column {
            id: drive
            required property var modelData
            required property int index
            readonly property bool isSectionGroup: true
            // the first drive's heading opens the flyout
            readonly property bool opensPage: index === 0
            width: parent ? parent.width : 0
            spacing: Theme.flyoutSpacing

            FlyoutHeading {
                text: "DRIVE"
                asWritten: drive.modelData.name
                hints: [Format.bytes(drive.modelData.size)]
            }

            FlyoutRow {
                visible: drive.modelData.parts.length === 0
                width: parent.width
                label: "No volumes available"
                enabled: false
            }

            Repeater {
                model: drive.modelData.parts

                FlyoutRow {
                    required property var modelData
                    readonly property bool mounted: modelData.mountpoint !== ""
                    width: drive.width
                    leadingIcon: "󰋊"
                    label: modelData.label !== "" ? modelData.label : modelData.fstype.toUpperCase()
                    note: mounted && modelData.used > 0
                        ? Format.bytes(modelData.used) + " of " + Format.bytes(modelData.size)
                        : Format.bytes(modelData.size)
                    trailing: Drives.busyPath === modelData.path ? "" : mounted ? "Open" : "Mount"
                    trailingIsValue: true
                    busy: Drives.busyPath === modelData.path
                    onActivated: mounted ? Drives.open(modelData) : Drives.mount(modelData)
                }
            }

            FlyoutChipLine {
                chips: [{ icon: "󰕓", text: Drives.busyPath === drive.modelData.path ? "Ejecting…" : "Eject",
                          act: "eject" }]
                onPicked: Drives.eject(drive.modelData)
            }
        }
    }

    FlyoutRow {
        visible: Drives.error !== ""
        label: Drives.error
        alert: true
        enabled: false
    }
}
