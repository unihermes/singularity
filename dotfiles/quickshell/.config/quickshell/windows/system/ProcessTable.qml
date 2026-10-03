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
    // the section heading, with the sort toggles on its line
    property string heading: "PROCESSES"
    // CPU as a share of the whole machine (top's per-core figure over the
    // thread count), with a small level beside it, rather than per core,
    // where one busy browser reads 170%
    property bool machineShare: false
    readonly property int threads: Math.max(1, SystemStats.cores.length)

    width: parent ? parent.width : 0
    spacing: Theme.spaceM
    // sectioned as if its rows sat in the page, under its own heading
    readonly property bool isSectionGroup: true
    readonly property bool sectioned: true

    readonly property int pidW:  Theme.fs(64)
    readonly property int userW: Theme.fs(74)
    readonly property int cpuW:  Theme.fs(52)
    // the CPU level's room, beside the figure
    readonly property int levelW: machineShare ? Theme.fs(80) + Theme.spaceM : 0
    readonly property int memW:  Theme.fs(62)
    readonly property int killW: Theme.fs(22)

    Item {
        readonly property bool isSectionBreak: true
        readonly property bool sectioned: root.sectioned
        width: parent.width
        height: Math.max(tableHeading.implicitHeight, root.showSort ? sortRow.height : 0)

        FlyoutHeading {
            id: tableHeading
            firstInColumn: !!root.parent && root.parent.children[0] === root
            anchors.left: parent.left
            anchors.right: root.showSort ? sortRow.left : parent.right
            anchors.rightMargin: root.showSort ? Theme.spaceL : 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.heading
        }

        FlyoutSegmented {
            id: sortRow
            visible: root.showSort
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: tableHeading.lift
            fill: false
            model: [{ value: "cpu", text: "CPU" }, { value: "mem", text: "MEM" }]
            current: SystemStats.procSort
            onPicked: v => SystemStats.procSort = v
        }
    }

    // column headings
    Item {
        width: parent.width
        height: Theme.headingHeight

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: root.detailed
            text: "PID"
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
        Text {
            x: root.detailed ? root.pidW : 0
            anchors.verticalCenter: parent.verticalCenter
            text: "Process"
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
        Text {
            visible: root.detailed
            anchors.right: parent.right
            anchors.rightMargin: root.killW + Theme.spaceL + root.memW + Theme.spaceL
                + root.cpuW + Theme.spaceL + root.levelW
            anchors.verticalCenter: parent.verticalCenter
            width: root.userW
            text: "User"
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
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
            font.weight: Theme.weightBody
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
            font.weight: Theme.weightBody
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
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }

                // armed, the name asks
                Text {
                    anchors.left: root.detailed ? pidText.right : parent.left
                    anchors.right: userText.left
                    anchors.rightMargin: Theme.spaceL
                    anchors.verticalCenter: parent.verticalCenter
                    text: pr.armed ? "End " + pr.modelData.name + "?" : pr.modelData.name
                    elide: Text.ElideRight
                    color: pr.armed ? Theme.alert : Theme.text
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }

                Text {
                    id: userText
                    visible: root.detailed
                    // zero-width when hidden, so the name column runs on
                    width: root.detailed ? root.userW : 0
                    anchors.right: cpuLevel.left
                    anchors.rightMargin: root.detailed ? Theme.spaceL : 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: pr.modelData.user
                    elide: Text.ElideRight
                    color: pr.mine ? Theme.subtext : Theme.muted
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }

                Item {
                    id: cpuLevel
                    anchors.right: cpuText.left
                    anchors.rightMargin: root.machineShare ? Theme.spaceM : 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.machineShare ? Theme.fs(80) : 0
                    height: lvl.height
                    visible: root.machineShare

                    Slider {
                        id: lvl
                        width: parent.width
                        interactive: false
                        value: Math.min(100, pr.modelData.cpu / root.threads)
                    }
                }

                Text {
                    id: cpuText
                    anchors.right: memText.left
                    anchors.rightMargin: Theme.spaceL
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.cpuW
                    horizontalAlignment: Text.AlignRight
                    text: (root.machineShare ? pr.modelData.cpu / root.threads : pr.modelData.cpu).toFixed(1) + "%"
                    color: SystemStats.procSort === "cpu" ? Theme.textStrong : Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
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
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }

                // Only on your own processes: kill as a user can't touch
                // root's, and a button that silently fails is worse than none.
                IconButton {
                    id: killBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.killW
                    visible: pr.mine
                    icon: "󰅖"
                    armed: pr.armed
                    onClicked: SystemStats.requestKill(pr.modelData.pid)
                }
            }
        }
    }

    Text {
        width: parent.width
        height: Theme.fs(12)
        text: SystemStats.procs.length === 0 ? "Sampling…" : ""
        color: Theme.subtext
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontSmall
    }
}
