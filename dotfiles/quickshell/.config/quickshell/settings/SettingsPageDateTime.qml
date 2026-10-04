// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageDateTime.qml
//
// The system's time zone and network time, through timedatectl (a change
// asks the polkit agent for the password), and the shell's own clock
// preferences: 12- or 24-hour, and the calendar's first weekday. Those two
// live in Settings.qml and reach the bar clock and the calendar flyout
// straight away.
//
// A running Qt program keeps the zone it started with until told otherwise,
// so a zone change made here calls Date.timeZoneUpdated() for the shell.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Date & Time"
    description: "The time zone, and how the clocks read."

    property string zone: ""
    property string zoneAbbrev: ""
    property bool ntp: false
    property bool canNtp: false
    property bool synced: false
    // [{ id, city, region, abbrev, offset (minutes), countries }]: every
    // zone, with what it's called and how far from UTC it is now
    property var zones: []
    // alias -> its current name ("US/Eastern" -> "America/New_York")
    property var aliases: ({})

    readonly property string canonical: aliases[zone] || zone
    readonly property var current: zones.find(z => z.id === canonical) || null

    function cityOf(z) { return z.slice(z.lastIndexOf("/") + 1).replace(/_/g, " ") }
    function regionOf(z) { return z.indexOf("/") < 0 ? "" : z.slice(0, z.indexOf("/")).replace(/_/g, " ") }
    // -240 -> "UTC−4", 330 -> "UTC+5:30"
    function offText(min) {
        var a = Math.abs(min), h = Math.floor(a / 60), m = a % 60
        return "UTC" + (min < 0 ? "−" : "+") + h + (m ? ":" + (m < 10 ? "0" : "") + m : "")
    }
    // a zone's wall time now, from the shell's clock and the zone's offset
    function timeIn(z) {
        var d = new Date(clock.date.getTime() + (z.offset + clock.date.getTimezoneOffset()) * 60000)
        return Qt.formatTime(d, Theme.hours("HH:mm"))
    }

    function reread() { status.running = true }

    Component.onCompleted: {
        reread()
        list.running = true
    }

    Process {
        id: status
        command: ["sh", "-c", "timedatectl show; echo \"Abbrev=$(date +'%Z, UTC%:z')\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = {}
                text.split("\n").forEach(l => {
                    var i = l.indexOf("=")
                    if (i > 0) v[l.slice(0, i)] = l.slice(i + 1)
                })
                page.zone = v.Timezone || ""
                page.zoneAbbrev = v.Abbrev || ""
                page.ntp = v.NTP === "yes"
                page.canNtp = v.CanNTP === "yes"
                page.synced = v.NTPSynchronized === "yes"
            }
        }
        onExited: code => { if (code !== 0) page.say("timedatectl isn't answering", true) }
    }

    // Z <TAB> zone <TAB> abbreviation <TAB> +hh:mm for every zone, C <TAB>
    // zone <TAB> countries from zone1970.tab, L <TAB> alias <TAB> its name
    Process {
        id: list
        command: ["sh", "-c", `
            for z in $(timedatectl list-timezones); do
                printf 'Z\\t%s\\t%s\\t%s\\n' "$z" $(TZ=$z date +'%Z %:z')
            done
            d=/usr/share/zoneinfo
            [ -f $d/zone1970.tab ] && awk -F'\\t' 'FNR == NR { if (!/^#/) c[$1] = $2; next }
                !/^#/ { n = split($1, cc, ","); s = ""; for (i = 1; i <= n; i++) s = s (i > 1 ? ", " : "") c[cc[i]]; printf "C\\t%s\\t%s\\n", $3, s }' $d/iso3166.tab $d/zone1970.tab
            [ -f $d/tzdata.zi ] && awk '$1 == "L" { printf "L\\t%s\\t%s\\n", $3, $2 }' $d/tzdata.zi
            exit 0`]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], countries = {}, al = {}
                text.split("\n").forEach(l => {
                    var f = l.split("\t")
                    if (f[0] === "C") countries[f[1]] = f[2] || ""
                    else if (f[0] === "L") al[f[1]] = f[2]
                    else if (f[0] === "Z" && f.length >= 4) {
                        // f[2] the abbreviation, f[3] the offset, +hh:mm
                        var m = /([+-])(\d+):(\d+)/.exec(f[3])
                        out.push({ id: f[1], city: page.cityOf(f[1]), region: page.regionOf(f[1]), abbrev: f[2],
                            offset: m ? (m[1] === "-" ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3])) : 0 })
                    }
                })
                out.forEach(z => z.countries = countries[z.id] || "")
                page.aliases = al
                page.zones = out
            }
        }
    }

    // One change at a time; the message is what the toast says on success.
    property string pendingMessage: ""
    property bool zoneChanged: false

    function run(args, message, isZone) {
        if (change.running) return
        pendingMessage = message
        zoneChanged = !!isZone
        change.command = ["timedatectl"].concat(args)
        change.running = true
    }

    Process {
        id: change
        stderr: StdioCollector { id: changeErr }
        onExited: code => {
            if (code === 0) {
                if (page.zoneChanged) Date.timeZoneUpdated()
                page.say(page.pendingMessage, false)
            } else {
                var e = changeErr.text.trim()
                page.say(/authoriz|authentic/i.test(e) ? "Not changed: the password wasn't given"
                    : "timedatectl refused" + (e ? ": " + e : ""), true)
            }
            page.reread()
        }
    }

    // the time shown on the page, ticking
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // --- layout --------------------------------------------------------------

    property bool choosing: false
    property string query: ""
    readonly property int shownMatches: 7
    // best first: a city starting with the search, then anything containing it
    readonly property var matches: {
        if (!choosing) return []
        var q = query.trim().toLowerCase()
        var real = zones.filter(z => !aliases[z.id])
        if (q === "") return real
        var starts = [], rest = []
        real.forEach(z => {
            var city = z.city.toLowerCase()
            if (city.startsWith(q)) starts.push(z)
            else if (city.indexOf(q) >= 0 || z.id.toLowerCase().indexOf(q) >= 0
                || z.countries.toLowerCase().indexOf(q) >= 0 || z.abbrev.toLowerCase() === q) rest.push(z)
        })
        return starts.concat(rest)
    }

    FlyoutHeading { text: "TIME ZONE" }

    // the time now, large and ticking, and where and how it's kept
    HeadCard {
        glyph: "󰥔"
        title: Qt.formatTime(clock.date, Theme.hours("HH:mm:ss"))
        lines: [[Qt.formatDate(clock.date, "ddd d MMM yyyy"),
                 page.zone === "" ? "" : page.cityOf(page.canonical) + ", " + page.zoneAbbrev.replace(/, UTC.*/, "")
                     + (page.current ? " (" + page.offText(page.current.offset) + ")" : ""),
                 !page.ntp ? "set by hand" : page.synced ? "synchronised over the network" : "waiting for a time server"
                ].filter(t => t !== "").join("  ·  ")]
        rule: true
    }

    // the zone; it opens to a search of every place
    FlyoutRow {
        leadingIcon: "󰇧"
        label: "Time zone"
        note: page.zone === "" ? "" : page.cityOf(page.canonical) + (page.current ? " · " + page.offText(page.current.offset) : "")
        highlighted: page.choosing
        trailing: "Change…  " + (page.choosing ? "󰅀" : "󰅂")
        enabled: !change.running
        onActivated: {
            page.choosing = !page.choosing
            search.text = ""
            if (page.choosing) Qt.callLater(search.forceFocus)
        }
    }

    SettingsIndent {
        visible: page.choosing

        FlyoutInput {
            id: search
            echoPassword: false
            glyph: "󰍉"
            placeholder: "Search a city, a country or an abbreviation (EST)"
            onTextChanged: page.query = text
            onAccepted: if (page.matches.length > 0) zoneRows.pick(page.matches[0])
            onEscapePressed: page.choosing = false
        }

        Repeater {
            id: zoneRows
            function pick(z) {
                page.choosing = false
                if (z.id !== page.canonical) page.run(["set-timezone", z.id], "Time zone: " + z.city, true)
            }
            model: page.matches.slice(0, page.shownMatches)

            FlyoutRow {
                required property var modelData
                label: modelData.city
                // a zone can span a dozen countries; the first two say where
                note: modelData.countries === "" ? modelData.region
                    : modelData.countries.split(", ").slice(0, 2).join(", ") + (modelData.countries.split(", ").length > 2 ? "…" : "")
                highlighted: modelData.id === page.canonical
                trailing: page.timeIn(modelData) + "   " + modelData.abbrev + " · " + page.offText(modelData.offset)
                onActivated: zoneRows.pick(modelData)
            }
        }

        FlyoutRow {
            visible: page.matches.length > page.shownMatches
            enabled: false
            label: "and " + (page.matches.length - page.shownMatches) + " more; type to narrow"
        }
        FlyoutRow {
            visible: page.zones.length > 0 && page.matches.length === 0
            enabled: false
            label: "No zone matches"
        }
        SettingsNote { text: "Changing it asks for your password" }
    }

    // an old alias (US/Eastern) can move to its current name in one go
    SettingsField {
        visible: page.zone !== "" && page.canonical !== page.zone
        label: "Zone name"
        hint: page.zone + " is an old name for it"

        FlyoutChip {
            anchors.right: parent.right
            text: "Use " + page.canonical
            enabled: !change.running
            onClicked: page.run(["set-timezone", page.canonical], "Time zone: " + page.canonical, true)
        }
    }

    SettingsField {
        label: "Network time"
        hint: !page.canNtp ? "No network time service installed"
            : page.ntp ? (page.synced ? "Synchronised over the network" : "Waiting for a time server")
            : "The clock runs on its own"

        Switch {
            anchors.right: parent.right
            checked: page.ntp
            enabled: page.canNtp && !change.running
            onToggled: page.run(["set-ntp", page.ntp ? "false" : "true"],
                page.ntp ? "Network time off" : "Network time on")
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "CLOCK AND CALENDAR" }

    SettingsField {
        label: "Hour format"
        hint: "Reads " + Qt.formatTime(clock.date, Settings.clock24 ? "HH:mm" : "h:mm AP") + " now"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: [{ value: true, text: "24-hour" }, { value: false, text: "12-hour" }]
            current: Settings.clock24
            onPicked: v => {
                Settings.setClock24(v)
                page.say(v ? "24-hour clock" : "12-hour clock", false)
            }
        }
    }

    SettingsField {
        label: "First day of the week"
        hint: "Where the calendar's weeks start"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: [{ value: 1, text: "Monday" }, { value: 0, text: "Sunday" }, { value: 6, text: "Saturday" }]
            current: Settings.weekStart
            onPicked: v => {
                Settings.setWeekStart(v)
                page.say("Weeks start on " + ["Sunday", "Monday", "", "", "", "", "Saturday"][v], false)
            }
        }
    }

    // the calendar's week as it will run, its first day marked
    SettingsField {
        label: ""
        hint: "The calendar's week"
        searchable: false

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceXs

            Repeater {
                model: 7
                Rectangle {
                    required property int index
                    readonly property int day: (Settings.weekStart + index) % 7
                    width: Theme.fs(28)
                    height: Theme.fs(22)
                    radius: Theme.radiusSmall
                    color: "transparent"
                    border.width: Theme.borderWidth
                    border.color: index === 0 ? Theme.accent : Theme.stroke
                    Text {
                        anchors.centerIn: parent
                        text: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"][parent.day]
                        color: index === 0 ? Theme.textStrong : parent.day === 0 || parent.day === 6 ? Theme.muted : Theme.subtext
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontCaption
                    }
                }
            }
        }
    }
}
