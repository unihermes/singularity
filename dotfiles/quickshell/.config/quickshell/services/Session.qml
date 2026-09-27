// Singularity - Quickshell
// ~/.config/quickshell/services/Session.qml
//
// Lock, suspend, log out and the rest, for the Control Centre's Power page
// and the SUPER+SHIFT+E power menu.

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
        else if (act === "hibernate") Quickshell.execDetached(["systemctl", "hibernate"])
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
}
