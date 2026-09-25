// Singularity - Quickshell
// ~/.config/quickshell/flyouts/WeatherFlyout.qml
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
        height: Theme.row(46)

        Text {
            id: bigIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.iconFor(Weather.code, Weather.isNight)
            color: Theme.textStrong
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontHero
        }

        Column {
            anchors.left: bigIcon.right
            anchors.leftMargin: Theme.spaceXl
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: Weather.temp(Weather.tempF, Weather.tempC)
                color: Theme.textStrong
                font.family: Theme.fontText
                font.pixelSize: Theme.fontTitle
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
            height: Theme.rowHeight

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fs(56)
                text: index === 0 ? "Today"
                    : Qt.formatDate(new Date(modelData.date + "T12:00:00"), "ddd")
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }
            Text {
                x: Theme.fs(60)

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
                color: Theme.textStrong
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }
        }
    }

    FlyoutDivider {}

    Item {
        width: parent.width
        height: Theme.row(22)

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.failed ? "Last update failed"
                : Weather.updated ? "Updated " + Qt.formatTime(Weather.updated, Theme.timeFormat) : ""
            color: Weather.failed ? Theme.alert : Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceS
            FlyoutSegmented {
                fill: false
                anchors.verticalCenter: parent.verticalCenter
                model: [{ value: false, text: "°F" }, { value: true, text: "°C" }]
                current: Weather.metric
                onPicked: v => Settings.setWeatherUnits(v ? "C" : "F")
            }
            FlyoutChip { glyph: true; text: "󰑐"; onClicked: Weather.refresh() }
        }
    }
}
