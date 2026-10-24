// Singularity - Quickshell
// ~/.config/quickshell/desktop/SysInfoWidget.qml
//
// The machine at a glance, fastfetch style: the distro's mark in the
// accent beside a row each for the system, kernel, host, uptime, packages
// and local IP; large adds the CPU, GPU and Hyprland's version. Small
// keeps the mark, the system and the uptime. Read once a minute.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"

WidgetCard {
    id: root

    property var info: ({})
    // when the machine booted, epoch seconds
    property real boot: 0
    property real now: Date.now() / 1000

    function since(sec) {
        sec = Math.max(0, sec)
        const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60)
        return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m"
    }

    readonly property var rows: {
        const all = [
            ["OS", info.os], ["Kernel", info.kernel], ["Host", info.host],
            ["Uptime", boot > 0 ? since(now - boot) : ""], ["Packages", info.packages], ["IP", info.ip],
            ["CPU", info.cpu], ["GPU", info.gpu], ["WM", info.wm]
        ].filter(r => !!r[1])
        const keep = small ? ["OS", "Uptime"] : large ? null : ["OS", "Kernel", "Host", "Uptime", "Packages", "IP"]
        return keep ? all.filter(r => keep.indexOf(r[0]) !== -1) : all
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c",
            ". /etc/os-release; echo \"os=${PRETTY_NAME:-$NAME}\"; echo \"kernel=$(uname -r)\"; "
            + "echo \"host=$(cat /proc/sys/kernel/hostname)\"; echo \"uptime=$(cut -d' ' -f1 /proc/uptime)\"; "
            + "command -v pacman >/dev/null && echo \"packages=$(pacman -Qq | wc -l)\"; "
            + "echo \"ip=$(ip -4 route get 1.1.1.1 2>/dev/null | grep -o 'src [0-9.]*' | cut -d' ' -f2)\"; "
            + "echo \"cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2)\"; "
            + "echo \"gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d' | head -1 | sed 's/.*: //')\"; "
            + "echo \"wm=Hyprland $(hyprctl version -j 2>/dev/null | grep -o '\"tag\": *\"[^\"]*' | sed 's/.*\"//')\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = {}
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0) kv[line.slice(0, i)] = line.slice(i + 1).trim()
                }
                // the card's own words: "GeForce RTX 4070", not the vendor's line
                const gpu = (kv.gpu || "").match(/\[([^\]]+)\]/)
                if (gpu) kv.gpu = gpu[1]
                kv.cpu = (kv.cpu || "").replace(/ \d+-Core Processor$/, "").replace(/\(R\)|\(TM\)/g, "")
                root.boot = Date.now() / 1000 - Number(kv.uptime || 0)
                root.info = kv
            }
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            root.now = Date.now() / 1000
            if (!probe.running) probe.running = true
        }
    }

    // the distro's mark: Arch's, else Tux
    WidgetText {
        id: mark
        card: root
        text: (root.info.os || "").indexOf("Arch") !== -1 ? "󰣇" : "󰌽"
        font.family: Theme.fontIcon
        px: root.small ? Theme.fit(40) : Theme.fit(64)
        color: root.accent
        anchors.verticalCenter: root.small ? undefined : parent.verticalCenter
    }

    Column {
        x: root.small ? 0 : mark.width + Theme.fit(18)
        y: root.small ? parent.height - height : (parent.height - height) / 2
        width: parent.width - x
        spacing: Theme.fit(root.large ? 8 : 2)

        Repeater {
            model: root.rows
            Item {
                required property var modelData
                width: parent.width
                height: value.implicitHeight

                WidgetText {
                    id: key
                    visible: !root.small
                    width: Theme.fit(80)
                    card: root
                    px: Theme.fit(13)
                    text: modelData[0]
                    color: root.accent
                    font.weight: Font.Bold
                }
                WidgetText {
                    id: value
                    x: root.small ? 0 : key.width
                    width: parent.width - x
                    card: root
                    px: Theme.fit(13)
                    text: modelData[1]
                }
            }
        }
    }
}
