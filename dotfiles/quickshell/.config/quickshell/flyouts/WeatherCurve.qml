// Singularity - Quickshell
// ~/.config/quickshell/flyouts/WeatherCurve.qml
//
// The temperature over the next day as a curve, the chance of rain as
// faint bars under it, and the sky and temperature at each labelled hour.
// Open-Meteo's 24 hours, else wttr.in's 3-hour slots. The Weather flyout's
// Now tab and the large weather widget.

import QtQuick
import "../services"

Column {
    id: root

    property alias bare: graph.bare
    property alias graphHeight: graph.height
    property alias textColor: graph.textColor
    property alias dimColor: graph.dimColor
    property alias lineColor: graph.lineColor
    property alias barColor: graph.barColor
    property alias fontFamily: graph.fontFamily
    property alias labelSize: graph.labelSize
    property int iconSize: Theme.fontIconSize
    property color iconColor: Theme.text

    readonly property var slots: Weather.hours.length > 0 ? Weather.hours : Weather.hourly
    readonly property var temps: slots.map(h => ({ t: h.at.getTime(), v: Weather.metric ? h.tempC : h.tempF }))
    // the slot at each labelled hour
    readonly property var marked: slots.filter(h => graph.ticks.indexOf(h.at.getTime()) !== -1)

    width: parent ? parent.width : 0
    spacing: Theme.spaceXs

    function night(at) {
        var m = at.getHours() * 60
        return Weather.sunriseMin >= 0 && (m < Weather.sunriseMin || m >= Weather.sunsetMin)
    }

    Item {
        width: parent.width
        height: root.iconSize + 2
        Repeater {
            model: root.marked
            Text {
                required property var modelData
                x: Math.max(0, Math.min(parent.width - width, graph.xOf(modelData.at.getTime()) - width / 2))
                text: Weather.iconFor(modelData.code, root.night(modelData.at))
                color: root.iconColor
                font.family: Theme.fontIcon
                font.pixelSize: root.iconSize
            }
        }
    }

    TimeGraph {
        id: graph
        from: root.slots.length > 0 ? root.slots[0].at.getTime() : 0
        to: root.slots.length > 0 ? root.slots[root.slots.length - 1].at.getTime() : 1
        maxTicks: 8
        points: root.temps
        // a little room under the coldest hour and over the warmest
        floor: root.temps.reduce((m, p) => Math.min(m, p.v), Infinity) - 2
        ceiling: root.temps.reduce((m, p) => Math.max(m, p.v), -Infinity) + 1
        // wttr.in's slots are 3 hours apart
        breakAfter: 4 * 3600000
        bars: root.slots.map(h => ({ t: h.at.getTime(), v: h.rain / 100 }))
        labels: root.marked.map(h => ({ t: h.at.getTime(), v: Weather.metric ? h.tempC : h.tempF,
                                         text: Weather.temp(h.tempF, h.tempC) }))
    }
}
