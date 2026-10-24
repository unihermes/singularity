// Singularity - Quickshell
// ~/.config/quickshell/services/Weather.qml
//
// Conditions, the next hours and a 3-day forecast from wttr.in (no key,
// IP-located), every 30 minutes, then a week of days from Open-Meteo for
// the place wttr.in found (its 3 days stand in when that fails); a failure
// keeps the last reading.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool ready: false
    property string area: ""
    property int code: 0
    property string condition: ""
    property real tempF: 0
    property real tempC: 0
    property real feelsF: 0
    property real feelsC: 0
    property int humidity: 0
    property real windMph: 0
    property real windKmph: 0
    property string windDir: ""
    // today's sunrise and sunset, minutes after midnight; -1 until known
    property int sunriseMin: -1
    property int sunsetMin: -1
    // against the clock, not the fetch, so the icon turns at sunset
    // rather than at the next refresh after it
    readonly property int nowMin: clock.hours * 60 + clock.minutes
    readonly property bool isNight: sunriseMin >= 0 && sunsetMin >= 0
        && (nowMin < sunriseMin || nowMin >= sunsetMin)

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    // [{ date, hiF, loF, hiC, loC, code, rain }]: a week from Open-Meteo,
    // else wttr.in's 3 days
    property var forecast: []
    // the next six 3-hour slots: [{ at (Date), tempF, tempC, code, rain }]
    property var hourly: []
    // the next 24 hours from Open-Meteo, the same shape; empty until it answers
    property var hours: []
    // today's highest chance of rain, %
    property int rainChance: 0
    property real latitude: NaN
    property real longitude: NaN
    property var updated: null
    property bool failed: false
    readonly property bool fetching: fetch.running

    readonly property bool metric: Settings.weatherUnits === "C"

    function temp(f, c) { return Math.round(metric ? c : f) + "°" }

    function refresh() { if (!fetch.running) fetch.running = true }

    // WWO weather codes (what wttr.in returns) to Material Design glyphs
    function iconFor(c, night) {
        if (c === 113) return night ? "󰖔" : "󰖙"
        if (c === 116) return night ? "󰼱" : "󰖕"
        if (c === 119 || c === 122) return "󰖐"
        if ([143, 248, 260].indexOf(c) !== -1) return "󰖑"
        if ([200, 386, 389, 392, 395].indexOf(c) !== -1) return "󰙾"
        if ([227, 230, 323, 326, 329, 332, 335, 338, 368, 371].indexOf(c) !== -1) return "󰖘"
        if ([179, 182, 185, 281, 284, 311, 314, 317, 350, 362, 365, 374, 377].indexOf(c) !== -1) return "󰙿"
        if ([299, 302, 305, 308, 356, 359].indexOf(c) !== -1) return "󰖖"
        return "󰖗"   // the light/patchy rain codes, and anything unlisted
    }

    // WMO codes (what Open-Meteo returns) to the nearest WWO code, for iconFor
    function wwoOf(w) {
        if (w === 0) return 113
        if (w === 1 || w === 2) return 116
        if (w === 3) return 119
        if (w === 45 || w === 48) return 248
        if (w >= 51 && w <= 57) return 266
        if (w === 61 || w === 80) return 302
        if (w >= 63 && w <= 67 || w === 81 || w === 82) return 308
        if (w >= 71 && w <= 77 || w === 85 || w === 86) return 332
        if (w >= 95) return 389
        return 296
    }

    // Open-Meteo's week into `forecast` and its next day into `hours`, both
    // units
    function parseWeek(text) {
        var all = JSON.parse(text)
        var hr = all.hourly
        if (hr && hr.time) {
            var hs = [], now = Date.now()
            for (var k = 0; k < hr.time.length && hs.length < 24; k++) {
                // local times, as timezone=auto gives them
                var at = new Date(hr.time[k])
                if (at.getTime() + 3600000 <= now) continue
                var c = hr.temperature_2m[k]
                hs.push({ at: at, tempC: c, tempF: c * 9 / 5 + 32,
                          code: wwoOf(hr.weather_code[k]), rain: hr.precipitation_probability[k] || 0 })
            }
            root.hours = hs
        }
        var d = all.daily
        var f = []
        for (var i = 0; i < d.time.length; i++) {
            var hi = d.temperature_2m_max[i], lo = d.temperature_2m_min[i]
            f.push({ date: d.time[i], hiC: hi, loC: lo, hiF: hi * 9 / 5 + 32, loF: lo * 9 / 5 + 32,
                     code: wwoOf(d.weather_code[i]), rain: d.precipitation_probability_max[i] || 0 })
        }
        if (f.length > 0) root.forecast = f
    }

    // "06:59 AM" -> minutes after midnight
    function minutesOf(t) {
        var m = String(t).match(/(\d+):(\d+)\s*(AM|PM)/i)
        if (!m) return -1
        var h = Number(m[1]) % 12
        if (m[3].toUpperCase() === "PM") h += 12
        return h * 60 + Number(m[2])
    }

    // wttr.in's JSON into the properties above; `at` is when it was fetched
    function parse(text, at) {
        var d = JSON.parse(text)
        var c = d.current_condition[0]
        var a = d.nearest_area && d.nearest_area[0]
        root.area = a ? a.areaName[0].value + ", " + a.region[0].value : ""
        root.code = Number(c.weatherCode)
        root.condition = c.weatherDesc[0].value.trim()
        root.tempF = Number(c.temp_F); root.tempC = Number(c.temp_C)
        root.feelsF = Number(c.FeelsLikeF); root.feelsC = Number(c.FeelsLikeC)
        root.humidity = Number(c.humidity)
        root.windMph = Number(c.windspeedMiles); root.windKmph = Number(c.windspeedKmph)
        root.windDir = c.winddir16Point

        var astro = d.weather[0].astronomy[0]
        root.sunriseMin = root.minutesOf(astro.sunrise)
        root.sunsetMin = root.minutesOf(astro.sunset)

        var f = [], h = []
        for (var i = 0; i < d.weather.length; i++) {
            var w = d.weather[i]
            // midday (the 12:00 slot) stands in for the day
            var noon = w.hourly[Math.min(4, w.hourly.length - 1)]
            f.push({ date: w.date, hiF: Number(w.maxtempF), loF: Number(w.mintempF),
                     hiC: Number(w.maxtempC), loC: Number(w.mintempC),
                     code: Number(noon.weatherCode),
                     rain: Math.max.apply(null, w.hourly.map(s => Number(s.chanceofrain))) })
            for (var j = 0; j < w.hourly.length; j++) {
                var slot = w.hourly[j]
                var t = new Date(w.date + "T00:00:00")
                t.setHours(Number(slot.time) / 100)
                // the slot still running counts: it's the next 3 hours
                if (t.getTime() + 3 * 3600000 > at.getTime())
                    h.push({ at: t, tempF: Number(slot.tempF), tempC: Number(slot.tempC),
                             code: Number(slot.weatherCode), rain: Number(slot.chanceofrain) })
            }
        }
        root.hourly = h.slice(0, 6)
        root.rainChance = f.length > 0 ? f[0].rain : 0
        // kept while the week's fetch is out, or when it fails
        if (root.forecast.length <= f.length) root.forecast = f
        if (a && a.latitude) {
            root.latitude = Number(a.latitude)
            root.longitude = Number(a.longitude)
            if (!week.running) week.running = true
        }
        root.updated = at
        root.ready = true
        root.failed = false
    }

    Process {
        id: fetch
        command: ["curl", "-sf", "--max-time", "15", "https://wttr.in/?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var at = new Date()
                try {
                    root.parse(text, at)
                    cache.save({ fetched: at.toISOString(), body: text })
                } catch (e) {
                    root.failed = true
                }
            }
        }
        onExited: code => { if (code !== 0) root.failed = true }
    }

    Process {
        id: week
        command: ["curl", "-sf", "--max-time", "15", "https://api.open-meteo.com/v1/forecast?latitude="
            + root.latitude + "&longitude=" + root.longitude
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            + "&hourly=temperature_2m,weather_code,precipitation_probability"
            + "&timezone=auto&forecast_days=7"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.parseWeek(text) } catch (e) {} }
        }
    }

    // only while something shows it: the bar's Weather, or Night light
    // following the sunset
    readonly property bool wanted: Settings.widgetVisible("weather") || Settings.nightLightSchedule === "sun"

    Timer {
        interval: 1800000
        repeat: true
        running: root.wanted
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // retries every 3 minutes after a failure, until one succeeds
    Timer {
        interval: 180000
        repeat: true
        running: root.wanted && root.failed
        onTriggered: root.refresh()
    }

    // the last report, shown at once on start if it's under three hours
    // old; the fetch on start replaces it moments later
    DiskCache {
        id: cache
        name: "weather"
        onRestored: data => {
            var at = new Date(data.fetched)
            if (root.ready || !data.body || !(Date.now() - at < 3 * 3600000)) return
            try { root.parse(data.body, at) } catch (e) {}
        }
    }
}
