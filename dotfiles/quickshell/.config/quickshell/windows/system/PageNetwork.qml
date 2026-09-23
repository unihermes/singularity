// Singularity - Quickshell
// ~/.config/quickshell/windows/system/PageNetwork.qml
//
// The link in use, then every interface the kernel knows about. The
// default route decides which one is "the" connection -- not the name, not
// whether it has an address -- so a VPN taking over shows up here as the
// active interface without any special case for it.

import Quickshell
import Quickshell.Io
import QtQuick
import "../../services"
import "../../services/Format.js" as Format
import "../../flyouts"
// the page's own building blocks next door; QML needs the directory named
import "../system"

SystemPage {
    id: page

    title: "Network"
    subtitle: SystemStats.iface === "" ? "No default route — offline"
        : SystemStats.connType + " via " + SystemStats.iface
          + (Network.ssid !== "" && SystemStats.connType === "Wi-Fi" ? "  ·  " + Network.ssid : "")

    Spark {
        readonly property real peak: Math.max(65536,
            Math.max.apply(null, SystemStats.rxHistory.concat(SystemStats.txHistory, [0])))
        series: [
            { values: SystemStats.rxHistory, color: Theme.text, fill: true },
            { values: SystemStats.txHistory, color: Theme.subtext, fill: false },
        ]
        ceiling: peak * 1.15
        caption: "↓ ↑ · peak " + Format.rate(peak)
    }

    InfoRow { label: "Download"; value: "↓ " + Format.rate(SystemStats.rxRate) }
    InfoRow { label: "Upload";   value: "↑ " + Format.rate(SystemStats.txRate) }
    InfoRow {
        label: "Since link up"
        value: SystemStats.rxTotal > 0
            ? "↓ " + Format.bytes(SystemStats.rxTotal) + "   ↑ " + Format.bytes(SystemStats.txTotal)
            : "--"
    }

    // --- the connection -----------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "CONNECTION" }

    InfoRow {
        label: "Interface"
        value: SystemStats.iface !== "" ? SystemStats.iface : "offline"
        valueColor: SystemStats.iface === "" ? Theme.alert : undefined
    }
    InfoRow { label: "Type"; value: SystemStats.connType || "--" }
    InfoRow {
        visible: SystemStats.connType === "Wi-Fi"
        label: "Network"
        value: Network.ssid !== "" ? Network.ssid : "--"
    }
    InfoRow {
        visible: SystemStats.connType === "Wi-Fi"
        label: "Signal"
        // dBm, and what it means: -50 is next to the router, -70 is the far
        // side of the flat, below -80 is where throughput collapses
        value: SystemStats.signalDbm < 1000
            ? SystemStats.signalDbm + " dBm  ·  " + page.signalWord(SystemStats.signalDbm) : "--"
        valueColor: SystemStats.signalDbm < 1000 && SystemStats.signalDbm <= -80 ? Theme.alert : undefined
    }
    InfoRow { label: "IPv4 address"; value: SystemStats.ipAddr || "--" }
    InfoRow { label: "Gateway";      value: SystemStats.gateway || "--" }
    InfoRow { label: "Resolvers";    value: SystemStats.dns || "--" }

    function signalWord(dbm) {
        if (dbm >= -50) return "excellent"
        if (dbm >= -60) return "good"
        if (dbm >= -70) return "fair"
        if (dbm >= -80) return "weak"
        return "very weak"
    }

    // --- every interface ----------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "INTERFACES" }

    Repeater {
        model: SystemStats.interfaces

        Column {
            id: ifc
            required property var modelData
            readonly property bool active: modelData.name === SystemStats.iface

            width: parent.width
            spacing: 0
            // each block is a card's worth of lines; the gap keeps two
            // interfaces from reading as one
            bottomPadding: Theme.spaceM

            Item {
                width: parent.width
                height: Theme.chipHeight

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.indicatorWidth
                    height: parent.height - 4
                    radius: width / 2
                    color: Theme.accent
                    visible: ifc.active
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: ifc.active ? Theme.spaceM : 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    color: Theme.textStrong
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontBody
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.state.toLowerCase()
                    color: modelData.state === "UP" ? Theme.text : Theme.muted
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                }
            }

            InfoRow { label: "IPv4"; value: modelData.ipv4 || "--" }
            InfoRow { visible: modelData.ipv6 !== ""; label: "IPv6"; value: modelData.ipv6 }
            InfoRow { visible: modelData.mac !== ""; label: "MAC"; value: modelData.mac }
            InfoRow { label: "MTU"; value: modelData.mtu > 0 ? String(modelData.mtu) : "--" }
        }
    }

    Text {
        width: parent.width
        visible: SystemStats.interfaces.length === 0
        text: "No interfaces reported yet."
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }

    // --- tools --------------------------------------------------------------

    FlyoutHeading { text: "TOOLS" }

    Flow {
        width: parent.width
        spacing: Theme.spaceM

        FlyoutChip {
            text: "Ping test"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "ping -c 10 1.1.1.1; read -r _"])
        }
        FlyoutChip {
            text: "Trace route"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "command -v tracepath >/dev/null && tracepath 1.1.1.1 || ip route get 1.1.1.1; read -r _"])
        }
        FlyoutChip {
            text: "Listening ports"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "ss -tulpn; read -r _"])
        }
        FlyoutChip {
            text: "Routing table"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "ip route; echo; ip -6 route; read -r _"])
        }
    }
}
