// Singularity - Quickshell
// ~/.config/quickshell/windows/system/ProcessTable.qml
//
// The heaviest processes, with a two-step kill on your own. Shared by the
// Overview (a five-row summary, no sort buttons) and the Processes page
// (the full table, sortable, with the pid and owner shown).
//
// How many rows arrive is SystemStats.procLimit's business, not this
// file's -- the window sets it from the current page, so the summary isn't
// paying `top` for rows it won't draw.

import QtQuick
import "../../services"
import "../../services/Format.js" as Format
import "../../flyouts"

Column {
    id: root

    // the CPU / MEM toggles and the pid+user columns: the full table on the
    // Processes page, off for the Overview's summary
    property bool detailed: false
    // the CPU / MEM toggles on their own, for a page that cares about the
    // ranking but not about pids and owners (Memory)
    property bool showSort: detailed
    // reserve space for this many rows, so the column doesn't jump while a
    // sort change is loading
    property int reserveRows: 5

    width: parent ? parent.width : 0
    spacing: Theme.spaceM

    readonly property int pidW:  Theme.fs(52)
    readonly property int userW: Theme.fs(74)
    readonly property int cpuW:  Theme.fs(52)
    readonly property int memW:  Theme.fs(62)
    readonly property int killW: Theme.fs(22)
    // where the name column has to stop, counting back from the right edge
    readonly property int tailW: cpuW + memW + killW + Theme.spaceL * 3
        + (detailed ? userW + Theme.spaceL : 0)

    Item {
        width: parent.width
        height: Theme.controlSize
        visible: root.showSort

        FlyoutHeading {
            anchors.left: parent.left
            anchors.right: sortRow.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            text: "SORT BY"
        }

        Row {
            id: sortRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceS
            SortButton { label: "CPU"; on: SystemStats.procSort === "cpu"; onClicked: SystemStats.procSort = "cpu" }
            SortButton { label: "MEM"; on: SystemStats.procSort === "mem"; onClicked: SystemStats.procSort = "mem" }
        }
    }

    // column headings
    Item {
        width: parent.width
        height: Theme.headingHeight

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.detailed ? "PID   Process" : "Process"
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
        Text {
            visible: root.detailed
            anchors.right: parent.right
            anchors.rightMargin: root.killW + Theme.spaceL + root.memW + Theme.spaceL
                + root.cpuW + Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            width: root.userW
            text: "User"
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: root.killW + Theme.spaceL + root.memW + Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            width: root.cpuW
            horizontalAlignment: Text.AlignRight
            text: "CPU"
            color: SystemStats.procSort === "cpu" ? Theme.text : Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: root.killW + Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            width: root.memW
            horizontalAlignment: Text.AlignRight
            text: "MEM"
            color: SystemStats.procSort === "mem" ? Theme.text : Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
    }

    Column {
        id: procList
        width: parent.width
        spacing: Theme.spaceXs
        height: root.reserveRows * Theme.rowHeight + (root.reserveRows - 1) * spacing

        HoverHandler { id: procHover }
        Binding { target: SystemStats; property: "holdProcs"; value: procHover.hovered }

        Repeater {
            model: SystemStats.procs

            Item {
                id: pr
                required property var modelData
                readonly property bool mine: modelData.user === SystemStats.me
                readonly property bool armed: SystemStats.killPid === modelData.pid

                width: procList.width
                height: Theme.rowHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: -Theme.spaceS
                    anchors.rightMargin: -Theme.spaceS
                    radius: Theme.radiusInner
                    color: prHover.hovered ? Theme.hoverFill : "transparent"
                }
                HoverHandler { id: prHover }

                Text {
                    id: pidText
                    visible: root.detailed
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.pidW
                    text: pr.modelData.pid
                    color: Theme.muted
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontBody
                }

                Text {
                    anchors.left: root.detailed ? pidText.right : parent.left
                    anchors.right: userText.left
                    anchors.rightMargin: Theme.spaceL
                    anchors.verticalCenter: parent.verticalCenter
                    text: pr.modelData.name
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontBody
                }

                Text {
                    id: userText
                    visible: root.detailed
                    // zero-width when hidden, so the name column runs on
                    width: root.detailed ? root.userW : 0
                    anchors.right: cpuText.left
                    anchors.rightMargin: root.detailed ? Theme.spaceL : 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: pr.modelData.user
                    elide: Text.ElideRight
                    color: pr.mine ? Theme.subtext : Theme.muted
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                }

                Text {
                    id: cpuText
                    anchors.right: memText.left
                    anchors.rightMargin: Theme.spaceL
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.cpuW
                    horizontalAlignment: Text.AlignRight
                    text: pr.modelData.cpu.toFixed(1) + "%"
                    color: SystemStats.procSort === "cpu" ? Theme.textStrong : Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontBody
                }

                Text {
                    id: memText
                    anchors.right: killBtn.left
                    anchors.rightMargin: Theme.spaceL
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.memW
                    horizontalAlignment: Text.AlignRight
                    text: Format.kib(pr.modelData.memKb)
                    color: SystemStats.procSort === "mem" ? Theme.textStrong : Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontBody
                }

                // Only on your own processes: kill as a user can't touch
                // root's, and a button that silently fails is worse than none.
                Rectangle {
                    id: killBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.killW
                    height: Theme.chipHeight
                    radius: Theme.radiusInner
                    visible: pr.mine
                    color: pr.armed ? Theme.alert
                        : killMouse.containsMouse ? Theme.hoverFillSoft : "transparent"
                    border.width: Theme.borderWidth
                    border.color: pr.armed ? Theme.alert
                        : killMouse.containsMouse ? Theme.strokeHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        // a check to confirm once armed, an x before
                        text: pr.armed ? "󰄬" : "󰅖"
                        color: pr.armed ? Theme.base
                            : killMouse.containsMouse ? Theme.textStrong : Theme.muted
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontIconSize
                    }

                    MouseArea {
                        id: killMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SystemStats.requestKill(pr.modelData.pid)
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        height: Theme.fs(12)
        text: SystemStats.killPid > 0 ? "Click again to end that process"
            : SystemStats.procs.length === 0 ? "Sampling…" : ""
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }
}
