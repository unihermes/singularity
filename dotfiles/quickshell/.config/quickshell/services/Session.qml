// Singularity - Quickshell
// ~/.config/quickshell/services/Session.qml
//
// Lock, suspend, log out and the rest, for the Control Centre and power
// menu, plus one-off reboots into another OS or the firmware. `resumed()`
// for services that keep time (Qt's timers stop during sleep).

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // offered once logind says it can (install.sh's hibernation step)
    property bool canHibernate: false

    function refresh() {
        hibernateCheck.running = true
        rebootCheck.running = true
    }
    Component.onCompleted: refresh()

    // a fresh detached process (Restart shell, and how Qt rereads fonts)
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

    // [{ act, label, icon }]: one-off reboots (another OS, firmware setup)
    // via logind, no helper or password; entries from systemd-boot via logind
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
        { act: "lock",      label: "Lock",      icon: "󰌾", key: "L", detail: "Locks the screen; everything keeps running" },
        { act: "suspend",   label: "Suspend",   icon: "󰤄", key: "S", detail: "Sleeps in memory; wakes in a second" },
    ].concat(canHibernate ? [
        { act: "hibernate", label: "Hibernate", icon: "󰒲", key: "H", detail: "Saves to disk and powers off" },
    ] : []).concat([
        { act: "logout",    label: "Log Out",   icon: "󰍃", key: "E", detail: "Ends the session, back to the login screen" },
        { act: "reboot",    label: "Reboot",    icon: "󰜉", key: "R", detail: "Restarts the machine" },
        { act: "poweroff",  label: "Shut Down", icon: "󰐥", key: "P", detail: "Powers off" },
    ])

    function run(act) {
        // through hypridle's lock_cmd, like SUPER+L
        if (act === "lock") Quickshell.execDetached(["loginctl", "lock-session"])
        else if (act === "suspend") Quickshell.execDetached(["systemctl", "suspend"])
        // the panel is blanked first (the compositor freezes while the image
        // is written); the marker tells lid.sh the resume should light it
        else if (act === "hibernate") Quickshell.execDetached(["sh", "-c", `
            m="$XDG_RUNTIME_DIR/singularity-hibernating"
            dpms() { hyprctl eval "hl.dispatch(hl.dsp.dpms({ action = \\"$1\\" }))" >/dev/null; }
            touch "$m"
            dpms off
            systemctl hibernate || { rm -f "$m"; dpms on; }`])
        // Logout ends the logind session scope (hl.dsp.exit() would just be
        // relaunched by start-hyprland), after stopping the session's units
        // while the compositor is still up, with a timeout.
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
