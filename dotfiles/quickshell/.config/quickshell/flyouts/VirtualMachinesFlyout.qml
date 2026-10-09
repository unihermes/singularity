// Singularity - Quickshell
// ~/.config/quickshell/flyouts/VirtualMachinesFlyout.qml
//
// Each running VM under its own heading: open its window, shut it down,
// or force it off (two clicks).

import QtQuick
import "../services"

FlyoutPanel {
    flyout: "vms"
    menuWidth: 240

    FlyoutHeading {
        text: "VIRTUAL MACHINES  " + VirtualMachines.running.length
    }

    FlyoutRow {
        visible: !VirtualMachines.active
        label: "No virtual machine is running"
        enabled: false
    }

    Repeater {
        model: VirtualMachines.running

        Column {
            id: vm
            required property string modelData
            required property int index
            width: parent ? parent.width : 0
            spacing: 0
            // its heading and rows get sections as if they sat in the panel
            readonly property bool isSectionGroup: true
            readonly property bool sectioned: true

            FlyoutHeading {
                visible: VirtualMachines.running.length > 1
                text: vm.modelData.toUpperCase()
            }

            FlyoutRow {
                leadingIcon: "󰍹"
                label: VirtualMachines.running.length > 1 ? "Open window" : vm.modelData
                note: VirtualMachines.running.length > 1 ? "" : "Open window"
                trailing: "󰁔"
                onActivated: {
                    scope.openFlyout = ""
                    VirtualMachines.open(vm.modelData)
                }
            }
            FlyoutRow {
                leadingIcon: "󰐥"
                label: VirtualMachines.stopping[vm.modelData] ? "Shutting down…" : "Shut down"
                busy: !!VirtualMachines.stopping[vm.modelData]
                onActivated: VirtualMachines.shutdown(vm.modelData)
            }
            FlyoutRow {
                leadingIcon: "󰚌"
                label: "Force off"
                confirmText: "Force off " + vm.modelData + "?"
                onActivated: VirtualMachines.forceOff(vm.modelData)
            }
        }
    }
}
