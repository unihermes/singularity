// Singularity - Quickshell
// ~/.config/quickshell/desktop/WeatherWidget.qml
//
// The sky's glyph and the temperature large, the conditions and the feel
// beside them, then five days as columns: the day, its glyph, the high
// and the low.

import QtQuick
import "../services"
import "../flyouts"

WidgetFrame {
    id: root

    FlyoutHeading { text: "WEATHER" }

    Row {
        spacing: Theme.spaceL

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.ready ? Weather.iconFor(Weather.code, Weather.isNight) : "󰖐"
            color: Theme.accent
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontHero
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: Weather.ready ? Weather.temp(Weather.tempF, Weather.tempC) : "--"
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: Theme.fs(40)
            }
            Text {
                visible: Weather.ready
                text: Weather.condition + " · feels " + Weather.temp(Weather.feelsF, Weather.feelsC)
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    Row {
        visible: Weather.forecast.length > 0
        width: parent.width

        Repeater {
            model: Weather.forecast.slice(0, 5)

            Column {
                required property var modelData
                required property int index
                width: parent.width / Math.min(5, Weather.forecast.length)
                spacing: Theme.spaceXs

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: index === 0 ? "Today" : Qt.formatDate(new Date(modelData.date + "T12:00:00"), "ddd")
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.iconFor(modelData.code, false)
                    color: Theme.text
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontIconSize
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.temp(modelData.hiF, modelData.hiC)
                    color: Theme.textStrong
                    font.family: Theme.fontText
                    font.weight: Theme.weightStrong
                    font.pixelSize: Theme.fontBody
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.temp(modelData.loF, modelData.loC)
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }
            }
        }
    }
}
