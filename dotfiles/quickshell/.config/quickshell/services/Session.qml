// Singularity - Quickshell
// ~/.config/quickshell/services/Session.qml
//
// Lock, suspend, log out and the rest, for the Control Centre's Power page
// and the SUPER+SHIFT+E power menu, plus the one-off reboots into another
// OS or the firmware setup that only the Control Centre and Settings offer.
// Also `resumed()`, for services that keep
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

    function refresh() {
        hibernateCheck.running = true
        rebootCheck.running = true
    }
    Component.onCompleted: refresh()

    // A fresh process: the Control Centre's Restart shell, and the only way
    // Qt rereads fonts (Fonts.qml). Detached, so it outlives this one; the
    // log goes where autostart.lua sends it.
    function restartShell() {
        Quickshell.execDetached(["sh", "-c",
            "qs kill; sleep 0.5; setsid quickshell > \"$HOME/.cache/quickshell.log\" 2>&1 < /dev/null &"])
    }

    Process {
        id: hibernateCheck
        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1",
                  "org.freedesktop.login1.Manager", "CanHibernate"]
        stdout: StdioCollector {
            onStreamFinished: root.canHibernate = text.trim() === 's "yes"'
        }
    }

    // [{ act, label, icon }]: reboots that go somewhere else this once --
    // Windows or macOS beside this one, then the firmware setup -- for
    // rebootInto(). logind sets systemd-boot's one-shot entry or the
    // firmware's boot-to-setup flag, which the active session may do with
    // no password, so it needs no helper of its own. The entries come from
    // logind too: systemd-boot hands it their ids at boot.
    property var rebootTargets: []

    Process {
        id: rebootCheck
        // one JSON line per answer, in this order; {} for one that fails
        command: ["sh", "-c", `
            m() { busctl --json=short "$1" org.freedesktop.login1 /org/freedesktop/login1 \\
                    org.freedesktop.login1.Manager "$2" 2>/dev/null || echo '{}'; }
            m call CanRebootToBootLoaderEntry
            m get-property BootLoaderEntries
            m call CanRebootToFirmwareSetup`]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim().split("\n").map(l => {
                    try { return JSON.parse(l).data } catch (e) { return null }
                })
                const can = d => !!d && d[0] === "yes"
                const oses = { "auto-windows": ["Windows", "󰖳"], "auto-osx": ["macOS", "󰀵"] }
                let t = []
                if (can(out[0]) && Array.isArray(out[1]))
                    t = out[1].filter(id => oses[id]).map(id => ({ act: id, label: oses[id][0], icon: oses[id][1] }))
                if (can(out[2])) t.push({ act: "firmware", label: "BIOS", icon: "󰘚" })
                root.rebootTargets = t
            }
        }
    }

    function rebootInto(act) {
        if (act === "firmware") Quickshell.execDetached(["systemctl", "reboot", "--firmware-setup"])
        else Quickshell.execDetached(["systemctl", "reboot", "--boot-loader-entry=" + act])
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
        // the ly login screen. Before that, the session's systemd units
        // (portals, polkit agent, hypridle; see hyprland-session.target)
        // are stopped while the compositor is still up -- the systemd user
        // manager outlives the logout, and left running they crash on the
        // closed socket and respawn until they hit their start limit. The
        // timeout keeps a unit that won't stop from holding up the logout.
        // Hyprland unsets the Wayland variables it gave systemd when it
        // exits, but terminate-session may not let it get that far.
        else if (act === "logout") Quickshell.execDetached(["sh", "-c",
            "timeout 10 systemctl --user stop hyprland-session.target;"
            + " systemctl --user unset-environment WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE;"
            + " loginctl terminate-session \"$XDG_SESSION_ID\""])
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
