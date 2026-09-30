// Singularity - Quickshell
// ~/.config/quickshell/services/Session.qml
//
// Lock, suspend, log out and the rest, for the Control Centre's Power page
// and the SUPER+SHIFT+E power menu. Also `resumed()`, for services that keep
// time: Qt's timers run on the monotonic clock, which stops while the machine
// sleeps, so anything due during a suspend or hibernate would otherwise fire
// late by however long the machine was out.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Hibernate is only offered once logind says it can: that needs a
    // swapfile, the resume hook and resume= on the cmdline (install.sh's
    // hibernation step), none of which link.sh alone sets up.
    property bool canHibernate: false

    function refresh() { hibernateCheck.running = true }
    Component.onCompleted: refresh()

    Process {
        id: hibernateCheck
        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1",
                  "org.freedesktop.login1.Manager", "CanHibernate"]
        stdout: StdioCollector {
            onStreamFinished: root.canHibernate = text.trim() === 's "yes"'
        }
    }

    // In menu order; `act` is what run() takes
    readonly property var actions: [
        { act: "lock",      label: "Lock",      icon: "󰌾", key: "L" },
        { act: "suspend",   label: "Suspend",   icon: "󰤄", key: "S" },
    ].concat(canHibernate ? [
        { act: "hibernate", label: "Hibernate", icon: "󰒲", key: "H" },
    ] : []).concat([
        { act: "logout",    label: "Log Out",   icon: "󰍃", key: "E" },
        { act: "reboot",    label: "Reboot",    icon: "󰜉", key: "R" },
        { act: "poweroff",  label: "Shut Down", icon: "󰐥", key: "P" },
    ])

    function run(act) {
        // through hypridle's lock_cmd, like SUPER+L
        if (act === "lock") Quickshell.execDetached(["loginctl", "lock-session"])
        else if (act === "suspend") Quickshell.execDetached(["systemctl", "suspend"])
        // Writing the image takes a minute or so, and the compositor is
        // frozen for all of it: left lit, the panel holds whatever frame
        // was up -- usually hyprlock half faded in over the desktop -- and
        // looks hung. Blank it first, the way a closed lid does. The marker
        // tells lid.sh sleep that the panel is off on purpose, so the resume
        // lights it instead of treating it as a stray wake to keep dark.
        else if (act === "hibernate") Quickshell.execDetached(["sh", "-c", `
            m="$XDG_RUNTIME_DIR/singularity-hibernating"
            dpms() { hyprctl eval "hl.dispatch(hl.dsp.dpms(\\"$1\\"))" >/dev/null; }
            touch "$m"
            dpms off
            systemctl hibernate || { rm -f "$m"; dpms on; }`])
        // hl.dsp.exit() only kills the compositor -- start-hyprland (the
        // hyprland package's own session wrapper, PID 1 of the logind
        // session scope) treats that as a crash and immediately relaunches
        // it, so nothing ever visibly closes. Killing the whole logind
        // session scope instead ends everything in it and drops back to
        // the ly login screen.
        else if (act === "logout") Quickshell.execDetached(["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""])
        else if (act === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
        else if (act === "poweroff") Quickshell.execDetached(["systemctl", "poweroff"])
    }

    // --- waking ------------------------------------------------------------

    // After a suspend or hibernate, at most once a minute
    signal resumed()
    property real lastResume: 0

    function noteResume() {
        var now = Date.now()
        if (now - lastResume < 60000) return
        lastResume = now
        resumed()
    }

    // logind's PrepareForSleep(false), sent as the machine comes back
    Process {
        id: sleepWatch
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1",
                  "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("PrepareForSleep (false") !== -1) root.noteResume()
            }
        }
        onExited: sleepRewatch.restart()
    }

    Timer {
        id: sleepRewatch
        interval: 5000
        onTriggered: sleepWatch.running = true
    }

    // Backstop for a missed signal: the wall clock jumping ahead of this
    // timer means the machine was asleep in between.
    property real lastTick: Date.now()
    Timer {
        interval: 15000
        repeat: true
        running: true
        onTriggered: {
            var now = Date.now()
            if (now - root.lastTick > 45000) root.noteResume()
            root.lastTick = now
        }
    }
}
