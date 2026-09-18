// Neutrino - Quickshell
// ~/.config/quickshell/WeatherFlyout.qml
//
// Split out of shell.qml. Self-contained: only needs the Weather singleton.

import QtQuick
import "../services"

FlyoutPanel {
    id: weatherFlyout
    flyout: "weather"
    menuWidth: 250

    FlyoutHeading { text: Weather.area !== "" ? Weather.area.toUpperCase() : "WEATHER" }

    Item {
        width: parent.width
        height: 46

        Text {
            id: bigIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.iconFor(Weather.code, Weather.isNight)
            color: Theme.bright
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fs(34)
        }

        Column {
            anchors.left: bigIcon.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: Weather.temp(Weather.tempF, Weather.tempC)
                color: Theme.bright
                font.family: Theme.fontText
                font.pixelSize: Theme.fs(22)
                font.bold: true
            }
            Text {
                text: Weather.condition
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    FlyoutRow { label: "Feels like"; trailing: Weather.temp(Weather.feelsF, Weather.feelsC); enabled: false }
    FlyoutRow { label: "Humidity";   trailing: Weather.humidity + "%"; enabled: false }
    FlyoutRow { label: "Wind";       trailing: Weather.wind; enabled: false }

    FlyoutHeading { text: "FORECAST" }

    Repeater {
        model: Weather.forecast

        Item {
            required property var modelData
            required property int index
            width: parent ? parent.width : 0
            height: 24

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 56
                text: index === 0 ? "Today"
                    : Qt.formatDate(new Date(modelData.date + "T12:00:00"), "ddd")
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }
            Text {
                x: 60
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.iconFor(modelData.code, false)
                color: Theme.text
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.temp(modelData.hiF, modelData.hiC) + "  /  " + Weather.temp(modelData.loF, modelData.loC)
                color: Theme.bright
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }
        }
    }

    FlyoutDivider {}

    Item {
        width: parent.width
        height: 22

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.failed ? "Last update failed"
                : Weather.updated ? "Updated " + Qt.formatTime(Weather.updated, "HH:mm") : ""
            color: Weather.failed ? Theme.alert : Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            FlyoutChip { text: "°F"; selected: !Weather.metric; onClicked: Settings.setWeatherUnits("F") }
            FlyoutChip { text: "°C"; selected: Weather.metric;  onClicked: Settings.setWeatherUnits("C") }
            FlyoutChip { glyph: true; text: "󰑐"; onClicked: Weather.refresh() }
        }
    }
}
