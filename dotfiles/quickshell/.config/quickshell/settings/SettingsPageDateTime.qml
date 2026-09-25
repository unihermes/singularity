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

    title: "Date & Time"
    description: "Time zone and network time for the whole system, set through timedatectl, and how the shell's clocks and calendar read."

    property string zone: ""
    property string zoneAbbrev: ""
    property bool ntp: false
    property bool canNtp: false
    property bool synced: false
    property var zones: []
    // the region the City list shows; follows the zone until one is picked
    property string region: ""

    function regionOf(z) { return z.indexOf("/") < 0 ? "Other" : z.slice(0, z.indexOf("/")) }
    function cityOf(z) { return z.indexOf("/") < 0 ? z : z.slice(z.indexOf("/") + 1) }
    function pretty(s) { return s.replace(/_/g, " ").replace(/\//g, " / ") }

    readonly property var regions: {
        var seen = {}, out = []
        zones.forEach(z => { var r = regionOf(z); if (!seen[r]) { seen[r] = true; out.push(r) } })
        return out.sort((a, b) => a === "Other" ? 1 : b === "Other" ? -1 : a.localeCompare(b))
    }
    readonly property var cities: zones.filter(z => regionOf(z) === region)

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
                if (page.region === "" && page.zone !== "") page.region = page.regionOf(page.zone)
            }
        }
        onExited: code => { if (code !== 0) page.say("timedatectl isn't answering", true) }
    }

    Process {
        id: list
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector {
            onStreamFinished: page.zones = text.split("\n").filter(z => z !== "")
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

    FlyoutHeading { text: "TIME ZONE" }

    SettingsField {
        label: "Now"
        hint: page.zone === "" ? "" : page.pretty(page.zone) + " (" + page.zoneAbbrev + ")"

        Text {
            anchors.right: parent.right
            text: Qt.formatDateTime(clock.date, Theme.hours("ddd d MMM yyyy, HH:mm:ss"))
            color: Theme.textStrong
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
        }
    }

    SettingsField {
        label: "Region"

        SettingsDropdown {
            anchors.right: parent.right
            model: page.regions
            current: page.region
            labelFor: v => page.pretty(v)
            onPicked: v => page.region = v
        }
    }

    SettingsField {
        label: "Time zone"
        hint: "Asks for your password"

        SettingsDropdown {
            anchors.right: parent.right
            model: page.cities
            current: page.zone
            placeholder: "Choose a city…"
            labelFor: v => page.pretty(page.cityOf(v))
            enabled: !change.running
            onPicked: v => page.run(["set-timezone", v], "Time zone: " + page.pretty(v), true)
        }
    }

    SettingsField {
        label: "Set time automatically"
        hint: !page.canNtp ? "No network time service is installed"
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
        hint: "The bar clock and every time the shell shows"

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
}
