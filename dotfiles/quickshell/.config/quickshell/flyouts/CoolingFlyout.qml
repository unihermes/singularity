// Singularity - Quickshell
// ~/.config/quickshell/flyouts/CoolingFlyout.qml
//
// Temperatures and fans, from the Cooling singleton: the last three
// minutes of CPU and GPU as one graph on a °C scale under a key with
// their readings (and the drive's), the fans as rows with their level and
// speed, then CoolerControl's modes while it has any, then CoolerControl
// and System as chips.

import QtQuick
import "../services"

FlyoutPanel {
    id: coolingFlyout
    flyout: "cooling"
    menuWidth: Theme.flyoutMenuWidth

    // the System window, for its Hardware page
    required property var systemWin

    onOpenChanged: if (open) Cooling.refreshModes()

    function degrees(c) { return c < 0 ? "—" : Math.round(c) + "°C" }

    FlyoutHeading { text: "COOLING  " + coolingFlyout.degrees(Cooling.hottest) }

    Item {
        width: parent.width
        implicitHeight: keys.implicitHeight

        // the key: each line's colour, name and reading
        Row {
            id: keys
            spacing: Theme.spaceXl

            Repeater {
                model: [{ colour: Theme.accent, name: "CPU", reading: Cooling.cpuC },
                        { colour: Theme.text, name: "GPU", reading: Cooling.gpuC }].filter(k => k.reading >= 0)

                Row {
                    required property var modelData
                    spacing: Theme.spaceS
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.fs(8); height: width; radius: width / 2
                        color: modelData.colour
                    }
                    Text {
                        text: modelData.name + "  " + coolingFlyout.degrees(modelData.reading)
                        color: modelData.reading >= Cooling.hotC ? Theme.alert : Theme.textStrong
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontBody
                    }
                }
            }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: keys.verticalCenter
            visible: Cooling.driveC >= 0
            text: "Drive " + coolingFlyout.degrees(Cooling.driveC)
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    Spark {
        height: Theme.row(70)
        floor: 30
        ceiling: 100
        gridLines: [40, 60, 80]
        gridSuffix: "°"
        historyLength: Cooling.historyLength
        series: [
            { values: Cooling.gpuHistory, color: Theme.text, fill: false },
            { values: Cooling.cpuHistory, color: Theme.accent, fill: true },
        ]
    }

    // the time axis, with the GPU's load and draw in the middle
    Item {
        width: parent.width
        implicitHeight: axisLeft.implicitHeight
        Text {
            id: axisLeft
            anchors.left: parent.left
            text: "3 min ago"
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ["GPU", Cooling.gpuLoad >= 0 ? Cooling.gpuLoad + "%" : "",
                   Cooling.gpuWatts >= 0 ? Math.round(Cooling.gpuWatts) + " W" : ""]
                .filter(s => s !== "").join(" · ")
            visible: Cooling.gpuLoad >= 0 || Cooling.gpuWatts >= 0
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
        Text {
            anchors.right: parent.right
            text: "now"
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    FlyoutDivider { visible: fanRows.count > 0 }

    // every fan as a row: its name (Auto when the board drives it, not
    // CoolerControl), its duty as a level, its speed; the card's own fans
    // last, which stop below about 60 °C
    Column {
        visible: fanRows.count > 0
        width: parent.width

        Repeater {
            id: fanRows
            model: Cooling.fans.concat(Cooling.gpuFan >= 0 ? [{ name: "GPU", rpm: -1, duty: Cooling.gpuFan, auto: true }] : [])

            Item {
                id: fanRow
                required property var modelData
                readonly property bool stopped: modelData.rpm === 0 || (modelData.rpm < 0 && modelData.duty <= 0)
                width: parent.width
                implicitHeight: Theme.rowHeight

                Text {
                    id: fanIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconCell
                    horizontalAlignment: Text.AlignHCenter
                    text: "󰈐"
                    color: fanName.color
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontBody
                }
                Text {
                    id: fanName
                    anchors.left: fanIcon.right
                    anchors.leftMargin: Theme.spaceM
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fs(56)
                    elide: Text.ElideRight
                    text: fanRow.modelData.name
                    color: fanRow.stopped ? Theme.subtext : Theme.text
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }
                Text {
                    id: fanNote
                    anchors.left: fanName.right
                    anchors.baseline: fanName.baseline
                    width: Theme.fs(36)
                    text: fanRow.modelData.auto ? "Auto" : ""
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontCaption
                }
                Meter {
                    anchors.left: fanNote.right
                    anchors.right: fanSpeed.left
                    anchors.rightMargin: Theme.spaceL
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: fanRow.modelData.duty >= 0 ? 1 : 0
                    fraction: fanRow.modelData.duty / 100
                }
                Text {
                    id: fanSpeed
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fs(72)
                    horizontalAlignment: Text.AlignRight
                    text: fanRow.modelData.rpm > 0 ? fanRow.modelData.rpm + " rpm"
                        : !fanRow.stopped ? fanRow.modelData.duty + "%" : "Stopped"
                    color: fanRow.stopped ? Theme.subtext : Theme.textStrong
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }
            }
        }
    }

    // CoolerControl's modes, while it has any
    FlyoutHeading {
        visible: Cooling.modes.length > 0
        text: "PROFILE"
        hints: ["CoolerControl"]
    }

    FlyoutSegmented {
        visible: Cooling.modes.length > 0
        model: Cooling.modes.map(m => ({ value: m.uid, text: m.name }))
        current: Cooling.activeMode
        onPicked: v => Cooling.setMode(v)
    }

    FlyoutDivider {}

    FlyoutChipLine {
        chips: (Cooling.coolerControl ? [{ icon: "󰒓", text: "CoolerControl", act: "cc" }] : [])
            .concat([{ icon: "󰍛", text: "System", act: "system" }])
        onPicked: act => {
            scope.openFlyout = ""
            if (act === "cc") Cooling.openCoolerControl()
            else coolingFlyout.systemWin.open("hardware")
        }
    }
}
