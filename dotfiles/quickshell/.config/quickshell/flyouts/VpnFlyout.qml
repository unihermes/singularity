// Singularity - Quickshell
// ~/.config/quickshell/flyouts/VpnFlyout.qml
//
// The VPN's switch on the heading; the tunnel as a card (the server, what
// goes through it, the forwarded port, Copy port at its end); Route
// everything and, with it, the kill switch; every imported server as a row,
// a click connecting to it; Settings. Self-contained: only needs Vpn.

import Quickshell
import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "vpn"
    menuWidth: Theme.flyoutMenuWidth

    FlyoutHeading {
        text: "VPN"
        control: Vpn.servers.length > 0 ? headingSwitch : null
    }

    Component {
        id: headingSwitch
        Switch {
            checked: Vpn.up
            enabled: Vpn.available && !Vpn.busy
            onToggled: Vpn.toggle()
        }
    }

    HeadCard {
        visible: Vpn.servers.length > 0
        glyph: Vpn.up ? "󰦝" : "󰖂"
        glyphColor: Vpn.stalled ? Theme.alert : Vpn.up ? Theme.textStrong : Theme.muted
        title: Vpn.busy ? "Working…"
            : !Vpn.up ? "Off"
            : (Vpn.current && Vpn.current.country ? Vpn.current.country + "  ·  " : "") + Vpn.currentName
        lines: !Vpn.up ? [!Vpn.available ? Vpn.missing
                    : Vpn.error !== "" ? Vpn.error
                    : Settings.vpnQbit ? "qBittorrent waits for it" : ""]
            : [Vpn.stalled ? "No answer from the server"
                    : Vpn.mode === "full" ? "Everything goes through it" + (Vpn.killSwitchOn ? "  ·  kill switch" : "")
                    : "Only qBittorrent goes through it",
               Vpn.port > 0 ? "Port " + Vpn.port
                    : Vpn.current && Vpn.current.pf === false ? "This server doesn't forward ports"
                    : Vpn.connected && !Vpn.hasNatpmp ? "natpmpc isn't installed"
                    : Vpn.portError]

        FlyoutChip {
            visible: Vpn.port > 0
            icon: "󰆏"
            text: "Copy port"
            onClicked: Quickshell.execDetached(["wl-copy", String(Vpn.port)])
        }
    }

    FlyoutAction {
        visible: Vpn.servers.length > 0
        icon: "󰇧"
        label: "Route everything"
        status: Settings.vpnFull ? "" : "Only qBittorrent uses it"
        checked: Settings.vpnFull
        enabled: !Vpn.busy
        onActivated: Vpn.setFull(!Settings.vpnFull)
    }

    FlyoutAction {
        visible: Vpn.servers.length > 0 && Settings.vpnFull
        icon: "󰒃"
        label: "Kill switch"
        status: Settings.vpnKillSwitch ? "Blocks the internet if it drops" : ""
        checked: Settings.vpnKillSwitch
        enabled: !Vpn.busy
        onActivated: Vpn.setKillSwitch(!Settings.vpnKillSwitch)
    }

    FlyoutHeading {
        text: "SERVERS" + (Vpn.servers.length > 0 ? "  " + Vpn.servers.length : "")
    }

    Repeater {
        model: Vpn.servers

        FlyoutRow {
            required property var modelData
            readonly property bool on: Vpn.up && Vpn.upServer === modelData.id
            label: modelData.country || modelData.name
            note: modelData.country ? modelData.name : ""
            highlighted: on
            busy: Vpn.busy && Settings.vpnServer === modelData.id
            trailing: on ? (Vpn.stalled ? "no answer" : "") : ""
            // the arrows mark the servers that forward a port
            trailingIcons: [modelData.pf ? "󰓢" : ""]
            onActivated: if (!on) Vpn.connect(modelData.id)
        }
    }

    FlyoutRow {
        visible: Vpn.servers.length === 0
        label: Vpn.available ? "No servers; import them in Settings" : Vpn.missing
        enabled: false
    }

    FlyoutDivider {}

    FlyoutChipLine {
        chips: [{ icon: "󰒓", text: "Settings", act: "settings" }]
        onPicked: root.scope.openSettings("vpn")
    }
}
