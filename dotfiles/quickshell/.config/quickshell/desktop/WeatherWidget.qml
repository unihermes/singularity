// Singularity - Quickshell
// ~/.config/quickshell/desktop/WeatherWidget.qml
//
// Where, the temperature large, and the sky with today's high and low.
// Medium adds five days as columns; large the next hours, then five days
// as rows with their range drawn against the week's.

import QtQuick
import "../services"

WidgetCard {
    id: root

    readonly property var today: Weather.forecast.length > 0 ? Weather.forecast[0] : null
    readonly property string hiLo: today
        ? "H:" + Weather.temp(today.hiF, today.hiC) + "  L:" + Weather.temp(today.loF, today.loC) : ""
    readonly property real weekLo: Weather.forecast.reduce((m, d) => Math.min(m, Weather.metric ? d.loC : d.loF), Infinity)
    readonly property real weekHi: Weather.forecast.reduce((m, d) => Math.max(m, Weather.metric ? d.hiC : d.hiF), -Infinity)

    function dayName(d, i) { return i === 0 ? "Today" : Qt.formatDate(new Date(d.date + "T12:00:00"), "ddd") }

    // where and how warm, top left
    Column {
        id: now
        width: root.small ? parent.width : parent.width * 0.55

        WidgetText {
            width: parent.width
            card: root
            px: Theme.fit(14)
            text: Weather.area !== "" ? Weather.area.split(",")[0] : "Weather"
            font.weight: Font.Bold
        }
        WidgetText {
            card: root
            px: root.large ? Theme.fit(52) : Theme.fit(42)
            text: Weather.ready ? Weather.temp(Weather.tempF, Weather.tempC) : "--"
            font.weight: Font.Normal
        }
    }

    // the sky: top right, or at the foot when small
    Column {
        y: root.small ? parent.height - height : 0
        width: root.small ? parent.width : parent.width * 0.45
        x: parent.width - width

        Repeater {
            model: [
                { text: Weather.ready ? Weather.iconFor(Weather.code, Weather.isNight) : "", icon: true },
                { text: Weather.condition, strong: true },
                { text: root.hiLo, dim: true }
            ]
            WidgetText {
                required property var modelData
                width: parent.width
                horizontalAlignment: root.small ? Text.AlignLeft : Text.AlignRight
                card: root
                text: modelData.text
                px: modelData.icon ? Theme.fit(root.small ? 18 : 22) : Theme.fit(13)
                font.family: modelData.icon ? Theme.fontIcon : root.font
                font.weight: modelData.strong ? Font.DemiBold : Font.Medium
                color: modelData.dim ? root.fgDim : root.fg
            }
        }
    }

    // the next hours (large), across
    Row {
        visible: root.large && Weather.hourly.length > 0
        y: Theme.fit(96)
        width: parent.width

        Repeater {
            model: root.large ? Weather.hourly.slice(0, 6) : []
            Column {
                required property var modelData
                width: parent.width / 6
                spacing: Theme.fit(4)
                WidgetText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    card: root
                    px: Theme.fit(12)
                    text: Qt.formatTime(modelData.at, Theme.hours("HH"))
                    color: root.fgDim
                }
                WidgetText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    card: root
                    font.family: Theme.fontIcon
                    px: Theme.fit(18)
                    text: Weather.iconFor(modelData.code, false)
                }
                WidgetText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    card: root
                    px: Theme.fit(13)
                    text: Weather.temp(modelData.tempF, modelData.tempC)
                }
            }
        }
    }

    // five days: columns (medium), rows with their range (large)
    Row {
        visible: !root.small && !root.large
        anchors.bottom: parent.bottom
        width: parent.width

        Repeater {
            model: !root.small && !root.large ? Weather.forecast.slice(0, 5) : []
            Column {
                required property var modelData
                required property int index
                width: parent.width / 5
                spacing: Theme.fit(2)
                WidgetText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    card: root
                    px: Theme.fit(12)
                    text: root.dayName(modelData, index)
                    color: root.fgDim
                }
                WidgetText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    card: root
                    font.family: Theme.fontIcon
                    px: Theme.fit(18)
                    text: Weather.iconFor(modelData.code, false)
                }
                WidgetText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    card: root
                    px: Theme.fit(13)
                    text: Weather.temp(modelData.hiF, modelData.hiC)
                }
            }
        }
    }

    Column {
        visible: root.large
        anchors.bottom: parent.bottom
        width: parent.width

        Repeater {
            model: root.large ? Weather.forecast.slice(0, 5) : []
            Item {
                required property var modelData
                required property int index
                readonly property real lo: Weather.metric ? modelData.loC : modelData.loF
                readonly property real hi: Weather.metric ? modelData.hiC : modelData.hiF
                width: parent.width
                height: Theme.fit(28)

                WidgetText {
                    id: dname
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fit(56)
                    card: root
                    text: root.dayName(modelData, index)
                }
                WidgetText {
                    id: dicon
                    anchors.left: dname.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fit(30)
                    card: root
                    font.family: Theme.fontIcon
                    px: Theme.fit(16)
                    text: Weather.iconFor(modelData.code, false)
                }
                WidgetText {
                    id: dlo
                    anchors.left: dicon.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fit(36)
                    horizontalAlignment: Text.AlignRight
                    card: root
                    text: Weather.temp(modelData.loF, modelData.loC)
                    color: root.fgDim
                }
                WidgetText {
                    id: dhi
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fit(36)
                    horizontalAlignment: Text.AlignRight
                    card: root
                    text: Weather.temp(modelData.hiF, modelData.hiC)
                }
                // the day's range against the week's
                Rectangle {
                    id: bar
                    anchors.left: dlo.right
                    anchors.right: dhi.left
                    anchors.leftMargin: Theme.fit(10)
                    anchors.rightMargin: Theme.fit(4)
                    anchors.verticalCenter: parent.verticalCenter
                    height: Theme.fit(5)
                    radius: height / 2
                    color: root.track
                    readonly property real span: Math.max(1, root.weekHi - root.weekLo)

                    Rectangle {
                        x: (parent.parent.lo - root.weekLo) / parent.span * parent.width
                        width: Math.max(parent.height, (parent.parent.hi - parent.parent.lo) / parent.span * parent.width)
                        height: parent.height
                        radius: parent.radius
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#7fb0e8" }
                            GradientStop { position: 1; color: "#f2c14e" }
                        }
                    }
                }
            }
        }
    }
}
