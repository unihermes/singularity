// Singularity - Quickshell
// ~/.config/quickshell/flyouts/WeatherFlyout.qml
//
// Now, large (sky, temperature, what it feels like, where), the next hours,
// humidity, wind and rain as tiles, then the days ahead. Self-contained:
// only needs the Weather singleton.

import QtQuick
import "../services"

FlyoutPanel {
    id: weatherFlyout
    flyout: "weather"
    menuWidth: Theme.flyoutMenuWidth

    FlyoutHeading { text: "WEATHER" }

    // now, large: the sky, the temperature, and what it's like
    Item {
        width: parent.width
        implicitHeight: Math.max(bigTemp.implicitHeight, nowText.implicitHeight)

        Text {
            id: bigIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.iconFor(Weather.code, Weather.isNight)
            color: Theme.textStrong
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontHero
        }
        Text {
            id: bigTemp
            anchors.left: bigIcon.right
            anchors.leftMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.temp(Weather.tempF, Weather.tempC)
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightStrong
            font.pixelSize: Theme.fontHero
        }
        Column {
            id: nowText
            anchors.left: bigTemp.right
            anchors.leftMargin: Theme.spaceXl
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Weather.condition
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: "Feels " + Weather.temp(Weather.feelsF, Weather.feelsC)
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
            Text {
                width: parent.width
                visible: Weather.area !== ""
                elide: Text.ElideRight
                text: Weather.area
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    // the next hours, three at a step
    Row {
        visible: Weather.hourly.length > 0
        width: parent.width
        Repeater {
            model: Weather.hourly
            Column {
                required property var modelData
                width: parent.width / Math.max(1, Weather.hourly.length)
                spacing: Theme.spaceXs
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatTime(modelData.at, Theme.hours("HH"))
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    readonly property int h: modelData.at.getHours() * 60
                    text: Weather.iconFor(modelData.code, Weather.sunriseMin >= 0 && (h < Weather.sunriseMin || h >= Weather.sunsetMin))
                    color: Theme.text
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontIconSize
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Weather.temp(modelData.tempF, modelData.tempC)
                    color: Theme.textStrong
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }
            }
        }
    }

    TileGrid {
        columns: 3
        FlyoutTile { width: parent.cell; glyph: "󰖎"; title: Weather.humidity + "%"; caption: "Humidity" }
        FlyoutTile {
            width: parent.cell
            glyph: "󰖝"
            title: Weather.ready ? (Weather.metric ? Weather.windKmph + " km/h" : Weather.windMph + " mph") : ""
            caption: "Wind " + Weather.windDir
        }
        FlyoutTile { width: parent.cell; glyph: "󰖗"; title: Weather.rainChance + "%"; caption: "Rain today" }
    }

    FlyoutHeading { text: "FORECAST" }

    // hi and lo each get a column as wide as the widest reading, so the
    // figures line up down the list whatever their digit count
    TextMetrics {
        id: tempMetrics
        font.family: Theme.fontText
        font.weight: Theme.weightBody
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
                font.weight: Theme.weightBody
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
                anchors.left: parent.left
                anchors.leftMargin: Theme.fit(48) + Theme.iconCell + Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                visible: modelData.rain >= 20
                text: modelData.rain + "%"
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
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
                font.weight: Theme.weightBody
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
                font.weight: Theme.weightBody
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
        label: Weather.fetching ? "Refreshing…"
            : Weather.failed ? "Update failed, try again" : "Refresh"
        trailing: Weather.updated ? "Updated " + Qt.formatTime(Weather.updated, Theme.timeFormat) : ""
        busy: Weather.fetching
        alert: Weather.failed && !Weather.fetching
        onActivated: Weather.refresh()
    }
}
