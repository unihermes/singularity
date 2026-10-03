// Singularity - Quickshell
// ~/.config/quickshell/windows/system/PageNetwork.qml
//
// The link in use, then every interface the kernel knows about. The
// default route decides which one is "the" connection -- not the name, not
// whether it has an address -- so a VPN taking over shows up here as the
// active interface without any special case for it.

import Quickshell
import QtQuick
import "../../services"
import "../../services/Format.js" as Format
import "../../flyouts"
import "../../settings"
// the page's own building blocks next door; QML needs the directory named
import "../system"

SystemPage {
    id: page

    title: "Network"
    subtitle: SystemStats.iface === "" ? "No default route — offline"
        : SystemStats.connType + " via " + SystemStats.iface
          + (Network.ssid !== "" && SystemStats.connType === "Wi-Fi" ? "  ·  " + Network.ssid : "")

    function signalWord(dbm) {
        if (dbm >= -50) return "excellent"
        if (dbm >= -60) return "good"
        if (dbm >= -70) return "fair"
        if (dbm >= -80) return "weak"
        return "very weak"
    }
    readonly property bool wifi: SystemStats.connType === "Wi-Fi"

    FlyoutHeading { text: "NOW" }

    // the link in use: its name, how fast it's moving, how good the signal
    // is, and the way to change it
    HeadCard {
        glyph: SystemStats.iface === "" ? "󰖪" : page.wifi ? "󰖩" : "󰈀"
        glyphColor: SystemStats.iface === "" ? Theme.muted : Theme.textStrong
        title: SystemStats.iface === "" ? "Offline"
            : page.wifi && Network.ssid !== "" ? Network.ssid : SystemStats.connType + " · " + SystemStats.iface
        lines: SystemStats.iface === "" ? ["No default route"] : [
            "↓ " + Format.rate(Math.max(0, SystemStats.rxRate)) + "   ↑ " + Format.rate(Math.max(0, SystemStats.txRate))
                + (page.wifi && SystemStats.signalDbm < 1000
                    ? "  ·  signal " + page.signalWord(SystemStats.signalDbm) + " (" + SystemStats.signalDbm + " dBm)" : ""),
            SystemStats.rxTotal > 0 ? "Since the link came up ↓ " + Format.bytes(SystemStats.rxTotal)
                + "  ↑ " + Format.bytes(SystemStats.txTotal) : "",
        ]

        FlyoutChip {
            text: "Settings  󰅂"
            onClicked: Quickshell.execDetached(["qs", "ipc", "call", "settings", "open", "network"])
        }
    }

    Spark {
        readonly property real peak: Math.max(65536,
            Math.max.apply(null, SystemStats.rxHistory.concat(SystemStats.txHistory, [0])))
        series: [
            { values: SystemStats.rxHistory, color: Theme.accent, fill: true },
            { values: SystemStats.txHistory, color: Theme.subtext, fill: false },
        ]
        ceiling: peak * 1.15
        caption: "60s · ↓ ↑ · peak " + Format.rate(peak)
    }

    // --- the connection -----------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "CONNECTION" }

    Grid {
        id: conn
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        readonly property real cell: (width - columnSpacing) / 2

        InfoRow {
            width: conn.cell
            label: "Interface"
            value: SystemStats.iface !== "" ? SystemStats.iface : "offline"
            valueColor: SystemStats.iface === "" ? Theme.alert : undefined
        }
        InfoRow { width: conn.cell; label: "Type"; value: SystemStats.connType || "--" }
        InfoRow { width: conn.cell; label: "IPv4 address"; value: SystemStats.ipAddr || "--" }
        InfoRow { width: conn.cell; label: "Gateway"; value: SystemStats.gateway || "--" }
        InfoRow { width: conn.cell; label: "Resolvers"; value: SystemStats.dns || "--" }
        InfoRow {
            width: conn.cell
            visible: page.wifi
            label: "Signal"
            // dBm, and what it means: -50 is next to the router, -70 is the
            // far side of the flat, below -80 is where throughput collapses
            value: SystemStats.signalDbm < 1000 ? SystemStats.signalDbm + " dBm" : "--"
            valueColor: SystemStats.signalDbm < 1000 && SystemStats.signalDbm <= -80 ? Theme.alert : undefined
        }
    }

    // --- every interface ----------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "INTERFACES" }

    // one row each, the one carrying traffic ticked; a row opens to its
    // addresses
    property string openIface: ""

    Repeater {
        model: SystemStats.interfaces

        Column {
            id: ifc
            required property var modelData
            readonly property bool open: page.openIface === modelData.name
            width: parent.width

            FlyoutRow {
                leadingIcon: ifc.modelData.name.startsWith("w") ? "󰖩"
                    : ifc.modelData.name === "lo" ? "󰑓" : "󰈀"
                label: ifc.modelData.name
                note: ifc.modelData.ipv4 || ""
                badge: ifc.modelData.name === SystemStats.iface ? "In use" : ""
                highlighted: ifc.open
                // the loopback has no carrier to report, and says "unknown"
                trailing: (ifc.modelData.name === "lo" ? "loopback" : ifc.modelData.state.toLowerCase())
                    + "  " + (ifc.open ? "󰅀" : "󰅂")
                onActivated: page.openIface = ifc.open ? "" : ifc.modelData.name
            }

            SettingsIndent {
                visible: ifc.open

                InfoRow { label: "IPv4"; value: ifc.modelData.ipv4 || "--" }
                InfoRow { visible: ifc.modelData.ipv6 !== ""; label: "IPv6"; value: ifc.modelData.ipv6 }
                InfoRow { visible: ifc.modelData.mac !== ""; label: "MAC"; value: ifc.modelData.mac }
                InfoRow { label: "MTU"; value: ifc.modelData.mtu > 0 ? String(ifc.modelData.mtu) : "--" }
            }
        }
    }

    FlyoutRow {
        visible: SystemStats.interfaces.length === 0
        enabled: false
        label: "No interfaces reported yet"
    }

    // --- tools --------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "TOOLS" }

    FlyoutRow {
        leadingIcon: "󰓅"
        label: "Ping test"
        note: "Ten pings to 1.1.1.1: is the internet there, and how far"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
            "ping -c 10 1.1.1.1; read -r _"])
    }
    FlyoutRow {
        leadingIcon: "󰑪"
        label: "Trace route"
        note: "Each hop on the way to 1.1.1.1"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
            "command -v tracepath >/dev/null && tracepath 1.1.1.1 || ip route get 1.1.1.1; read -r _"])
    }
    FlyoutRow {
        leadingIcon: "󰒍"
        label: "Listening ports"
        note: "What on this machine accepts connections"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
            "ss -tulpn; read -r _"])
    }
    FlyoutRow {
        leadingIcon: "󰛳"
        label: "Routing table"
        note: "Where each kind of traffic goes"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
            "ip route; echo; ip -6 route; read -r _"])
    }
}
