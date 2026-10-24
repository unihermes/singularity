// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageVpn.qml
//
// Proton VPN over WireGuard (services/Vpn.qml): on or off and what goes
// through it, the servers imported from Proton's WireGuard files, and
// qBittorrent kept on the tunnel with the forwarded port.

import Quickshell
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "VPN"
    description: "Proton VPN over WireGuard, for qBittorrent or everything."

    SettingsNote {
        visible: !Vpn.available
        text: Vpn.missing
        alert: true
    }

    FlyoutHeading { text: "CONNECTION" }

    SettingsField {
        label: "VPN"
        hint: Vpn.busy ? "Working…"
            : !Vpn.up ? (Vpn.error !== "" ? Vpn.error : Vpn.servers.length > 0 ? "Off" : "Import a server first")
            : Vpn.stalled ? "No answer from " + Vpn.currentName
            : "On  ·  " + Vpn.currentName

        Switch {
            anchors.right: parent.right
            enabled: Vpn.available && Vpn.servers.length > 0 && !Vpn.busy
            checked: Vpn.up
            onToggled: Vpn.toggle()
        }
    }

    SettingsField {
        label: "Route everything"
        hint: Settings.vpnFull ? "Every app, and DNS, goes through it" : "Only qBittorrent; games keep their ping"

        Switch {
            anchors.right: parent.right
            enabled: !Vpn.busy
            checked: Settings.vpnFull
            onToggled: Vpn.setFull(!Settings.vpnFull)
        }
    }

    SettingsField {
        label: "Kill switch"
        hint: !Settings.vpnFull ? "With Route everything only"
            : "No internet if it drops, till you turn it off"
        dimmed: !Settings.vpnFull

        Switch {
            anchors.right: parent.right
            enabled: Settings.vpnFull && !Vpn.busy
            checked: Settings.vpnKillSwitch
            onToggled: Vpn.setKillSwitch(!Settings.vpnKillSwitch)
        }
    }

    SettingsField {
        label: "Connect at login"
        hint: "If it was on when you left"

        Switch {
            anchors.right: parent.right
            checked: Settings.vpnAtLogin
            onToggled: Settings.setVpnAtLogin(!Settings.vpnAtLogin)
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "SERVERS" + (Vpn.servers.length > 0 ? "  " + Vpn.servers.length : "") }

    // each with whether it forwards a port, Connect, and Remove on hover
    Repeater {
        model: Vpn.servers

        SettingsField {
            id: server
            required property var modelData
            readonly property bool on: Vpn.up && Vpn.upServer === modelData.id

            label: (modelData.country ? modelData.country + "  " : "") + modelData.name
            hint: [on ? "Connected" : "",
                   modelData.pf === true ? "Forwards a port" : modelData.pf === false ? "No port forwarding" : "",
                   modelData.id].filter(t => t).join("  ·  ")

            HoverHandler { id: serverHover }

            Row {
                anchors.right: parent.right
                spacing: Theme.spaceL

                IconButton {
                    id: removeBtn
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (serverHover.hovered || armed) && !server.on
                    icon: "󰆴"
                    confirm: true
                    onClicked: {
                        Vpn.remove(server.modelData.id)
                        page.say("Removed " + server.modelData.name, false)
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: removeBtn.armed
                    text: "Click again to remove"
                    color: Theme.alert
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }
                FlyoutChip {
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: !server.on && !Vpn.busy
                    text: server.on ? "Connected" : "Connect"
                    onClicked: Vpn.connect(server.modelData.id)
                }
            }
        }
    }

    FlyoutRow {
        visible: Vpn.servers.length === 0
        enabled: false
        label: "No servers yet"
    }

    SettingsField {
        label: "Import from Downloads"
        hint: Vpn.importCount === 0 ? "No WireGuard files in Downloads"
            : Vpn.importCount > 0 ? "Moved in " + Vpn.importCount + (Vpn.importCount === 1 ? " server" : " servers")
            : "Proton's WireGuard files; they're moved here"

        FlyoutChip {
            anchors.right: parent.right
            icon: "󰈠"
            text: "Import"
            onClicked: Vpn.importDownloads()
        }
    }

    SettingsNote {
        text: "account.protonvpn.com › Downloads › WireGuard: GNU/Linux, NAT-PMP on, a P2P server"
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "QBITTORRENT" }

    SettingsField {
        label: "Only over the VPN"
        hint: !Vpn.hasQbit ? "qBittorrent isn't installed"
            : !Settings.vpnQbit ? "Off; it uses any connection"
            : Vpn.qbitState === "restart" ? "Quit qBittorrent once to apply"
            : Vpn.qbitState === "saved" ? "Set; it downloads only while the VPN is on"
            : Vpn.qbitState === "set" ? "On the VPN" + (Vpn.up ? "" : "; waiting for it")
            : "Checking…"
        dimmed: !Vpn.hasQbit

        Switch {
            anchors.right: parent.right
            enabled: Vpn.hasQbit
            checked: Settings.vpnQbit
            onToggled: Settings.setVpnQbit(!Settings.vpnQbit)
        }
    }

    SettingsField {
        label: "Forwarded port"
        hint: Vpn.port > 0 ? "Set as qBittorrent's listening port"
            : !Vpn.hasNatpmp ? "libnatpmp isn't installed"
            : !Vpn.connected ? "While the VPN is on"
            : Vpn.current && Vpn.current.pf === false ? "This server doesn't forward ports"
            : Vpn.portError !== "" ? Vpn.portError
            : "Asking…"
        dimmed: Vpn.port === 0

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceL

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Vpn.port > 0
                text: Vpn.port
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: Theme.fontBody
            }
            FlyoutChip {
                anchors.verticalCenter: parent.verticalCenter
                visible: Vpn.port > 0
                icon: "󰆏"
                text: "Copy"
                onClicked: Quickshell.execDetached(["wl-copy", String(Vpn.port)])
            }
        }
    }

    SettingsNote {
        text: "Its Web UI listens on 127.0.0.1:" + Vpn.qbitWebPort + " so the shell can set the port"
    }
}
