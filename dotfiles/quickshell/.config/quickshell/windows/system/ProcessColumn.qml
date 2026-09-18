// Singularity - Quickshell
// ~/.config/quickshell/system/ProcessColumn.qml
//
// The System window's middle column: the heaviest processes with a
// two-step kill, battery and systemd health, and quick actions.

import Quickshell
import Quickshell.Io
import QtQuick
import "../../services"
import "../../services/Format.js" as Format
import "../../flyouts"

Column {
    id: column

    required property var stats

    spacing: 6

    Item {
        width: parent.width
        height: 18

        FlyoutHeading {
            anchors.left: parent.left
            anchors.right: sortRow.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "PROCESSES"
        }

        Row {
            id: sortRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            SortButton { label: "CPU"; on: column.stats.procSort === "cpu"; onClicked: column.stats.procSort = "cpu" }
            SortButton { label: "MEM"; on: column.stats.procSort === "mem"; onClicked: column.stats.procSort = "mem" }
        }
    }

    // column headings
    Item {
        width: parent.width
        height: 16

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Name"
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 22 + 8 + 60 + 8
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            horizontalAlignment: Text.AlignRight
            text: "CPU"
            color: column.stats.procSort === "cpu" ? Theme.text : Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 22 + 8
            anchors.verticalCenter: parent.verticalCenter
            width: 60
            horizontalAlignment: Text.AlignRight
            text: "MEM"
            color: column.stats.procSort === "mem" ? Theme.text : Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
    }

    Column {
        id: procList
        width: parent.width
        spacing: 2
        // five rows' worth, so the column doesn't jump while a sort
        // change is loading
        height: 5 * 24 + 4 * spacing

        HoverHandler { id: procHover }
        Binding { target: column.stats; property: "holdProcs"; value: procHover.hovered }

        Repeater {
            model: column.stats.procs

            Item {
                id: pr
                required property var modelData
                readonly property bool mine: modelData.user === column.stats.me
                readonly property bool armed: column.stats.killPid === modelData.pid

                width: procList.width
                height: 24

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: -4
                    anchors.rightMargin: -4
                    radius: Theme.radiusInner
                    color: prHover.hovered ? Theme.overlay : "transparent"
                }
                HoverHandler { id: prHover }

                Text {
                    anchors.left: parent.left
                    anchors.right: cpuText.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: pr.modelData.name
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontBody
                }

                Text {
                    id: cpuText
                    anchors.right: memText.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    horizontalAlignment: Text.AlignRight
                    text: pr.modelData.cpu.toFixed(1) + "%"
                    color: column.stats.procSort === "cpu" ? Theme.bright : Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontBody
                }

                Text {
                    id: memText
                    anchors.right: killBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    horizontalAlignment: Text.AlignRight
                    text: Format.kib(pr.modelData.memKb)
                    color: column.stats.procSort === "mem" ? Theme.bright : Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontBody
                }

                // Only on your own processes: kill as a user can't
                // touch root's, and a button that silently fails is
                // worse than none.
                Rectangle {
                    id: killBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 20
                    radius: Theme.radiusInner
                    visible: pr.mine
                    color: pr.armed ? Theme.alert
                        : killMouse.containsMouse ? Theme.surface : "transparent"
                    border.width: 1
                    border.color: pr.armed ? Theme.alert
                        : killMouse.containsMouse ? Theme.muted : "transparent"

                    Text {
                        anchors.centerIn: parent
                        // a check to confirm once armed, an x before
                        text: pr.armed ? "󰄬" : "󰅖"
                        color: pr.armed ? Theme.base
                            : killMouse.containsMouse ? Theme.bright : Theme.muted
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontIconSize
                    }

                    MouseArea {
                        id: killMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: column.stats.requestKill(pr.modelData.pid)
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        text: column.stats.killPid > 0 ? "Click again to end that process" : ""
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
        height: 12
    }

    Item { width: 1; height: 4 }
    FlyoutHeading { text: "HEALTH" }

    InfoRow {
        label: "Battery"
        visible: column.stats.hasBattery
        value: column.stats.batt.healthSupported
            ? Math.round(column.stats.batt.healthPercentage) + "% health" : "n/a"
    }
    InfoRow { visible: !column.stats.hasBattery; label: "Battery"; value: "no battery" }

    InfoRow {
        label: "Failed units"
        value: FailedUnits.count === 0 ? "none"
            : FailedUnits.units.map(u => u.name).join(", ")
        valueColor: FailedUnits.count === 0 ? undefined : Theme.alert
    }

    Item { width: 1; height: 4 }
    FlyoutHeading { text: "QUICK ACTIONS" }

    Row {
        width: parent.width
        spacing: 6

        FlyoutChip {
            text: "Restart Audio"
            onClicked: audioRestartProc.running = true
        }
        FlyoutChip {
            text: Updates.checking ? "Checking…" : "Check Updates"
            enabled: !Updates.checking
            onClicked: Updates.refresh()
        }
    }

    Process {
        id: audioRestartProc
        command: ["systemctl", "--user", "restart", "wireplumber", "pipewire", "pipewire-pulse"]
    }
}
