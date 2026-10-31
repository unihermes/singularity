// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FailedFlyout.qml
//
// A row per failed unit (system or user, and when it failed); a click
// opens it in place with its last log lines and Full log, Restart and
// Clear. Clear all (two clicks) after them. Self-contained: only needs
// FailedUnits.

import Quickshell.Io
import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "failed"
    menuWidth: Theme.flyoutMenuWidth

    // the unit open in place, "u:" or "s:" then its name; "" for none
    property string opened: ""
    property var logLines: []
    onOpenChanged: if (!open) opened = ""

    function keyOf(u) { return (u.user ? "u:" : "s:") + u.name }
    function toggle(u) {
        opened = opened === keyOf(u) ? "" : keyOf(u)
        logLines = []
        if (opened !== "") {
            logProc.command = ["journalctl"].concat(u.user ? ["--user"] : [])
                .concat(["-u", u.name, "-n", "3", "--no-pager", "-o", "cat"])
            logProc.running = true
        }
    }

    Process {
        id: logProc
        stdout: StdioCollector {
            onStreamFinished: root.logLines = text.trim().split("\n").filter(l => l !== "")
        }
    }

    FlyoutHeading {
        text: "FAILED SERVICES"
        hints: FailedUnits.count > 0 ? [String(FailedUnits.count)] : []
    }

    FlyoutRow {
        visible: FailedUnits.count === 0
        label: "No failed services"
        enabled: false
    }

    Repeater {
        model: FailedUnits.units

        Column {
            id: unit
            required property var modelData
            readonly property bool isOpen: root.opened === root.keyOf(modelData)
            width: parent ? parent.width : 0
            spacing: Theme.spaceXs

            FlyoutRow {
                width: parent.width
                leadingIcon: "󰀦"
                label: unit.modelData.name
                note: unit.modelData.user ? "user" : "system"
                trailing: unit.isOpen ? "󰅀" : "󰅂"
                onActivated: root.toggle(unit.modelData)
            }

            // its last log lines and what can be done
            Column {
                visible: unit.isOpen
                x: Theme.iconCell
                width: parent.width - x
                spacing: Theme.spaceS
                bottomPadding: Theme.spaceS

                Rectangle {
                    width: parent.width
                    height: logCol.implicitHeight + Theme.spaceS * 2
                    radius: Theme.radiusSmall
                    color: Theme.base
                    border.width: Theme.borderWidth
                    border.color: Theme.stroke

                    Column {
                        id: logCol
                        x: Theme.spaceS
                        y: Theme.spaceS
                        width: parent.width - Theme.spaceS * 2

                        Repeater {
                            model: unit.isOpen ? (root.logLines.length > 0 ? root.logLines : ["Reading the log…"]) : []
                            Text {
                                required property string modelData
                                width: logCol.width
                                elide: Text.ElideRight
                                text: modelData
                                color: Theme.subtext
                                font.family: Theme.fontText
                                font.pixelSize: Theme.fontCaption
                            }
                        }
                    }
                }

                FlyoutChipLine {
                    chips: [
                        { icon: "󰦨", text: "Full log", act: "log" },
                        { icon: "󰑐", text: "Restart", act: "restart" },
                        { icon: "󰅖", text: "Clear", act: "clear" },
                    ]
                    onPicked: act => {
                        if (act === "log") {
                            FailedUnits.showLog(unit.modelData)
                            scope.openFlyout = ""
                        } else if (act === "restart") FailedUnits.restart(unit.modelData)
                        else FailedUnits.clear(unit.modelData)
                    }
                }
            }
        }
    }

    FlyoutDivider { visible: FailedUnits.count > 0 }

    FlyoutChip {
        visible: FailedUnits.count > 0
        width: parent.width
        icon: "󰅖"
        text: "Clear all"
        confirmText: "Clear " + FailedUnits.count + "?"
        onClicked: FailedUnits.units.slice().forEach(u => FailedUnits.clear(u))
    }
}
