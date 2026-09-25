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

    // hi and lo each get a column as wide as the widest reading, so the
    // figures line up down the list whatever their digit count
    TextMetrics {
        id: tempMetrics
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
        text: "-00°"
    }

    Repeater {
        model: Weather.forecast

        Item {
            required property var modelData
            required property int index
            width: parent ? parent.width : 0
            height: Theme.rowHeight

            Text {
                id: day
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(48)
                text: index === 0 ? "Today"
                    : Qt.formatDate(new Date(modelData.date + "T12:00:00"), "ddd")
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }

            // fixed-width cell, as in FlyoutAction: glyph advances vary
            Item {
                anchors.left: day.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconCell
                height: parent.height

                Text {
                    anchors.centerIn: parent
                    text: Weather.iconFor(modelData.code, false)
                    color: Theme.text
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontIconSize
                }
            }

            Text {
                anchors.right: lo.left
                anchors.rightMargin: Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                width: Math.ceil(tempMetrics.advanceWidth)
                horizontalAlignment: Text.AlignRight
                text: Weather.temp(modelData.hiF, modelData.hiC)
                color: Theme.textStrong
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }
            Text {
                id: lo
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.ceil(tempMetrics.advanceWidth)
                horizontalAlignment: Text.AlignRight
                text: Weather.temp(modelData.loF, modelData.loC)
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }
        }
    }

    FlyoutDivider {}

    FlyoutSegmented {
        label: "Units"
        model: [{ value: false, text: "°F" }, { value: true, text: "°C" }]
        current: Weather.metric
        onPicked: v => Settings.setWeatherUnits(v ? "C" : "F")
    }

    FlyoutRow {
        label: Weather.fetching ? "Refreshing..."
            : Weather.failed ? "Update failed, try again" : "Refresh"
        trailing: Weather.updated ? Qt.formatTime(Weather.updated, Theme.timeFormat) : ""
        busy: Weather.fetching
        alert: Weather.failed && !Weather.fetching
        onActivated: Weather.refresh()
    }
}
