// Singularity - Quickshell
// ~/.config/quickshell/flyouts/WeatherFlyout.qml
//
// Three tabs. Now: the sky, the temperature large, what it feels like and
// where, the next hours in 3-hour steps, then humidity, wind and rain as
// tiles. Hours: every hour of the next day with its chance of rain. Week:
// each day's low and high, drawn as a range on the week's one scale. Then
// Refresh and the units. Self-contained: only needs the Weather singleton.

import QtQuick
import "../services"

FlyoutPanel {
    id: weatherFlyout
    flyout: "weather"
    menuWidth: Theme.flyoutMenuWidth

    property string tab: "now"
    onOpenChanged: if (!open) tab = "now"

    FlyoutHeading {
        text: "WEATHER"
        hints: Weather.updated ? ["Updated " + Qt.formatTime(Weather.updated, Theme.timeFormat)] : []
    }

    FlyoutSegmented {
        model: [{ value: "now", text: "Now" }, { value: "hours", text: "Hours" }, { value: "week", text: "Week" }]
        current: weatherFlyout.tab
        onPicked: v => weatherFlyout.tab = v
    }

    FlyoutDivider {}

    // now, large: the sky, the temperature, and what it's like
    Item {
        visible: weatherFlyout.tab === "now"
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
        visible: weatherFlyout.tab === "now" && Weather.hourly.length > 0
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

    FlyoutDivider { visible: weatherFlyout.tab === "now" }

    TileGrid {
        visible: weatherFlyout.tab === "now"
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

    // --- Hours: the next day, an hour a row ---

    ListView {
        id: hourList
        visible: weatherFlyout.tab === "hours"
        width: parent.width
        // the next 24 from Open-Meteo, else wttr.in's 3-hour slots
        model: visible ? (Weather.hours.length > 0 ? Weather.hours : Weather.hourly) : []
        height: visible ? Math.min(contentHeight, 10 * Theme.rowHeight) : 0
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        onVisibleChanged: if (visible) positionViewAtBeginning()

        delegate: Item {
            required property var modelData
            readonly property int min: modelData.at.getHours() * 60
            width: hourList.width
            height: Theme.rowHeight

            Text {
                id: hourText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(48)
                text: Qt.formatTime(modelData.at, Theme.hours("HH:00"))
                color: Theme.text
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
            Item {
                id: hourIcon
                anchors.left: hourText.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconCell
                height: parent.height
                Text {
                    anchors.centerIn: parent
                    text: Weather.iconFor(modelData.code, Weather.sunriseMin >= 0 && (min < Weather.sunriseMin || min >= Weather.sunsetMin))
                    color: Theme.text
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontIconSize
                }
            }
            // the chance of rain, as a figure and a short level
            Meter {
                anchors.left: hourIcon.right
                anchors.leftMargin: Theme.spaceL
                anchors.right: rainText.left
                anchors.rightMargin: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                fraction: modelData.rain / 100
                animated: false
            }
            Text {
                id: rainText
                anchors.right: hourTemp.left
                anchors.rightMargin: Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(34)
                horizontalAlignment: Text.AlignRight
                text: modelData.rain + "%"
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
            Text {
                id: hourTemp
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.ceil(tempMetrics.advanceWidth)
                horizontalAlignment: Text.AlignRight
                text: Weather.temp(modelData.tempF, modelData.tempC)
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
        }
    }

    // --- Week: each day's range on the week's scale ---

    // the week's coldest and warmest, in the units shown
    readonly property real weekLo: Weather.forecast.reduce((m, d) => Math.min(m, Weather.metric ? d.loC : d.loF), Infinity)
    readonly property real weekHi: Weather.forecast.reduce((m, d) => Math.max(m, Weather.metric ? d.hiC : d.hiF), -Infinity)


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
        model: weatherFlyout.tab === "week" ? Weather.forecast : []

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
                id: lo
                anchors.right: range.left
                anchors.rightMargin: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                width: Math.ceil(tempMetrics.advanceWidth)
                horizontalAlignment: Text.AlignRight
                text: Weather.temp(modelData.loF, modelData.loC)
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }

            // low to high, placed on the week's coldest-to-warmest track
            Rectangle {
                id: range
                readonly property real span: Math.max(1, weatherFlyout.weekHi - weatherFlyout.weekLo)
                readonly property real lo: Weather.metric ? modelData.loC : modelData.loF
                readonly property real hi: Weather.metric ? modelData.hiC : modelData.hiF
                anchors.right: hi.left
                anchors.rightMargin: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(70)
                height: Theme.fit(5)
                radius: height / 2
                color: Theme.meterTrack

                Rectangle {
                    x: parent.width * (range.lo - weatherFlyout.weekLo) / range.span
                    width: Math.max(parent.height, parent.width * (range.hi - range.lo) / range.span)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.meterFill
                }
            }

            Text {
                id: hi
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.ceil(tempMetrics.advanceWidth)
                horizontalAlignment: Text.AlignRight
                text: Weather.temp(modelData.hiF, modelData.hiC)
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
        }
    }

    FlyoutDivider {}

    Row {
        id: tail
        width: parent.width
        spacing: Theme.spaceS
        readonly property real cell: (width - spacing) / 2

        FlyoutChip {
            width: tail.cell
            icon: "󰑓"
            spinning: Weather.fetching
            text: Weather.fetching ? "Refreshing…" : Weather.failed ? "Try again" : "Refresh"
            onClicked: Weather.refresh()
        }
        FlyoutChip {
            width: tail.cell
            icon: "󰔄"
            text: Weather.metric ? "Show °F" : "Show °C"
            onClicked: Settings.setWeatherUnits(Weather.metric ? "F" : "C")
        }
    }
}
