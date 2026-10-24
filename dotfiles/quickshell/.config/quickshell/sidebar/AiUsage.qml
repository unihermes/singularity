// Singularity - Quickshell
// ~/.config/quickshell/sidebar/AiUsage.qml
//
// The plans' limits under the sidebar's heading: Claude's five-hour and
// weekly windows and Codex's own, each a meter with how much is used and
// when it resets. A limit with no reading is left out.

import QtQuick
import "../services"
import "../flyouts"

Column {
    id: root

    width: parent ? parent.width : 0
    spacing: Theme.spaceXs

    // when a window resets: the time today, the weekday this week, else
    // the date
    function when(t) {
        if (!(t > 0)) return ""
        var d = new Date(t * 1000), now = new Date()
        var days = (d - now) / 86400000
        if (d.toDateString() === now.toDateString()) return Qt.formatTime(d, Theme.timeFormat)
        if (days < 6) return Qt.formatDate(d, "ddd") + " " + Qt.formatTime(d, Theme.timeFormat)
        return Qt.formatDate(d, "d MMM")
    }

    Repeater {
        model: [
            { label: "5 hours", used: Ai.fiveHour, resets: Ai.fiveHourResets },
            { label: "Week", used: Ai.sevenDay, resets: Ai.sevenDayResets },
            { label: "Codex", used: Ai.codexUsage ? Ai.codexUsage.used : -1,
              resets: Ai.codexUsage ? Ai.codexUsage.resets : 0 }
        ]

        Item {
            required property var modelData
            visible: modelData.used >= 0
            width: root.width
            height: Theme.rowHeightDense

            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(64)
                text: modelData.label
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
            Meter {
                anchors.left: label.right
                anchors.right: value.left
                anchors.rightMargin: Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                fraction: modelData.used
                fillColor: modelData.used >= 0.9 ? Theme.alert : Theme.meterFill
            }
            Text {
                id: value
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(120)
                horizontalAlignment: Text.AlignRight
                text: Math.round(modelData.used * 100) + "%"
                    + (modelData.resets > 0 ? "  ·  " + root.when(modelData.resets) : "")
                color: Theme.text
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }
    }
}
