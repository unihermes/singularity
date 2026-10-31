// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageVpn.qml
//
// Proton VPN over WireGuard (services/Vpn.qml). A card pinned on top says
// whether it's up, where it comes out and what goes through it, with the
// round power button. Then tiles: what goes through it (qBittorrent only
// or Everything, the kill switch, at login), every imported server (a
// click connects to it; Remove on hover) and Import, and qBittorrent kept
// on the tunnel with the forwarded port.

import Quickshell
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "VPN"
    description: "Proton VPN over WireGuard, for qBittorrent or everything."

    // how long it's been up, ticking by the minute
    property real now: Date.now()
    Timer {
        running: Vpn.up
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: page.now = Date.now()
    }
    function upFor() {
        var min = Math.max(0, Math.floor((now - Vpn.upSince) / 60000))
        return min < 60 ? min + " min" : Math.floor(min / 60) + " h " + (min % 60) + " min"
    }

    // "CA" from "CA#816", "US" from "US-CA#98"
    function code(name) { return name.split(/[#\- ]/)[0].slice(0, 3).toUpperCase() }

    pinned: ConnHero {
        glyph: Vpn.up ? "󰦝" : "󰖂"
        eyebrow: Vpn.busy ? "Working"
            : !Vpn.up ? "Not connected"
            : Vpn.stalled ? "No answer from the server"
            : "Connected  ·  " + page.upFor()
        title: Vpn.up ? (Vpn.current && Vpn.current.country ? Vpn.current.country + "  ·  " : "") + Vpn.currentName
            : Vpn.servers.length > 0 ? "Off" : "No servers yet"
        line: !Vpn.available ? Vpn.missing
            : !Vpn.up ? (Vpn.error !== "" ? Vpn.error
                : Vpn.picked ? "Connects to " + Vpn.picked.name : "Import a server below")
            : Vpn.mode === "full" ? "Everything goes through it" + (Vpn.killSwitchOn ? "  ·  kill switch on" : "")
            : "Only qBittorrent goes through it"
        on: Vpn.up
        powerEnabled: Vpn.available && Vpn.servers.length > 0
        busy: Vpn.busy
        onToggled: Vpn.toggle()
    }

    // --- what goes through it -------------------------------------------

    FlyoutHeading { text: "WHAT GOES THROUGH IT" }

    TileGrid {
        columns: 4

        ConnTile {
            width: parent.cell
            label: "qBittorrent only"
            glyph: "󰇚"
            title: "qBittorrent only"
            caption: "Nothing else"
            lit: !Settings.vpnFull
            clickable: !Vpn.busy
            onClicked: if (Settings.vpnFull) Vpn.setFull(false)
        }
        ConnTile {
            width: parent.cell
            label: "Everything"
            glyph: "󰇧"
            title: "Everything"
            caption: "Every app, and DNS"
            lit: Settings.vpnFull
            clickable: !Vpn.busy
            onClicked: if (!Settings.vpnFull) Vpn.setFull(true)
        }
        ConnTile {
            width: parent.cell
            label: "Kill switch"
            glyph: "󰒃"
            title: "Kill switch"
            caption: !Settings.vpnFull ? "With Everything only"
                : Settings.vpnKillSwitch ? "No internet if it drops" : "Off"
            lit: Settings.vpnFull && Settings.vpnKillSwitch
            dimmed: !Settings.vpnFull
            clickable: Settings.vpnFull && !Vpn.busy
            onClicked: Vpn.setKillSwitch(!Settings.vpnKillSwitch)
        }
        ConnTile {
            width: parent.cell
            label: "Connect at login"
            glyph: "󰐥"
            title: "Connect at login"
            caption: Settings.vpnAtLogin ? "If on when you left" : "Off"
            lit: Settings.vpnAtLogin
            onClicked: Settings.setVpnAtLogin(!Settings.vpnAtLogin)
        }
    }

    // --- servers ----------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "SERVERS" + (Vpn.servers.length > 0 ? "  " + Vpn.servers.length : "") }

    // each a tile with its country's code, the arrows on the ones that
    // forward a port; a click connects, Remove on hover
    TileGrid {
        columns: 4

        Repeater {
            model: Vpn.servers

            ConnTile {
                id: server
                required property var modelData
                readonly property bool on: Vpn.up && Vpn.upServer === modelData.id
                width: parent.cell
                glyph: page.code(modelData.name)
                title: modelData.name
                caption: on ? (Vpn.stalled ? "No answer" : "Connected") : modelData.country || modelData.id
                lit: on
                clickable: !on && !Vpn.busy && Vpn.available
                onClicked: Vpn.connect(modelData.id)

                corner: [
                    IconButton {
                        visible: (server.hovered || armed) && !server.on
                        implicitWidth: Theme.chipHeight
                        implicitHeight: Theme.chipHeight
                        icon: "󰆴"
                        confirm: true
                        onClicked: {
                            Vpn.remove(server.modelData.id)
                            page.say("Removed " + server.modelData.name, false)
                        }
                    },
                    Text {
                        visible: server.modelData.pf === true
                        height: Theme.chipHeight
                        verticalAlignment: Text.AlignVCenter
                        text: "󰓢"
                        color: Theme.subtext
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontIconSize
                    }
                ]
            }
        }

        ConnTile {
            width: parent.cell
            label: "Import from Downloads"
            glyph: "󰈠"
            title: "Import"
            caption: Vpn.importCount === 0 ? "None in Downloads"
                : Vpn.importCount > 0 ? "Moved in " + Vpn.importCount
                : "From Downloads"
            onClicked: Vpn.importDownloads()
        }
    }

    SettingsNote {
        text: "From account.protonvpn.com › Downloads › WireGuard, NAT-PMP on  ·  󰓢 forwards a port"
    }

    // --- qBittorrent --------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "QBITTORRENT" }

    Row {
        id: qbit
        readonly property real cell: (width - spacing * 2) / 3
        readonly property real tileHeight: Math.max(port.implicitHeight, only.implicitHeight)
        width: parent.width
        spacing: Theme.spaceS

        ConnTile {
            id: port
            width: qbit.cell * 2 + qbit.spacing
            height: qbit.tileHeight
            label: "Forwarded port"
            glyph: "󰓢"
            title: Vpn.port > 0 ? String(Vpn.port) : "No port"
            big: true
            clickable: false
            dimmed: Vpn.port === 0
            caption: Vpn.port > 0 ? "qBittorrent's listening port"
                : !Vpn.hasNatpmp ? "libnatpmp isn't installed"
                : !Vpn.connected ? "While the VPN is on"
                : Vpn.current && Vpn.current.pf === false ? "This server doesn't forward ports"
                : Vpn.portError !== "" ? Vpn.portError
                : "Asking…"

            corner: FlyoutChip {
                visible: Vpn.port > 0
                icon: "󰆏"
                text: "Copy"
                onClicked: Quickshell.execDetached(["wl-copy", String(Vpn.port)])
            }
        }
        ConnTile {
            id: only
            width: qbit.cell
            height: qbit.tileHeight
            label: "Only over the VPN"
            glyph: "󰒃"
            title: "Only over the VPN"
            caption: !Vpn.hasQbit ? "qBittorrent isn't installed"
                : !Settings.vpnQbit ? "Off; it uses any connection"
                : Vpn.qbitState === "restart" ? "Quit it once to apply"
                : Vpn.qbitState === "saved" ? "Downloads only while it's on"
                : Vpn.qbitState === "set" ? (Vpn.up ? "On the VPN" : "Waiting for the VPN")
                : "Checking…"
            lit: Settings.vpnQbit && Vpn.hasQbit
            dimmed: !Vpn.hasQbit
            clickable: Vpn.hasQbit
            onClicked: Settings.setVpnQbit(!Settings.vpnQbit)
        }
    }

    SettingsNote {
        text: "Its Web UI listens on 127.0.0.1:" + Vpn.qbitWebPort + " so the shell can set the port"
    }
}
