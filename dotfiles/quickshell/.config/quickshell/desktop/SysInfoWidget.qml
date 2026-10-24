// Singularity - Quickshell
// ~/.config/quickshell/desktop/SysInfoWidget.qml
//
// The machine at a glance, fastfetch style: the distro's mark in the
// accent beside user@host over a rule and a row each for the system,
// kernel, uptime, packages and local IP. Large puts the mark, user@host and
// the uptime over the rows and adds the CPU, GPU, memory and Hyprland's
// version; small keeps the mark, the host and the uptime. Read once a minute.

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

    readonly property string uptime: boot > 0 ? since(now - boot) : ""
    readonly property string title: (Quickshell.env("USER") || "") + "@" + (info.host || "")
    // large has the uptime under user@host instead
    readonly property var rows: (large
        ? [["OS", info.os], ["Kernel", info.kernel], ["Packages", info.packages], ["IP", info.ip],
           ["CPU", info.cpu], ["GPU", info.gpu], ["Memory", info.mem], ["WM", info.wm]]
        : [["OS", info.os], ["Kernel", info.kernel], ["Uptime", uptime], ["Packages", info.packages],
           ["IP", info.ip]]).filter(r => !!r[1])

    Process {
        id: probe
        running: true
        command: ["sh", "-c",
            ". /etc/os-release; echo \"os=${PRETTY_NAME:-$NAME}\"; echo \"kernel=$(uname -r)\"; "
            + "echo \"host=$(cat /proc/sys/kernel/hostname)\"; echo \"uptime=$(cut -d' ' -f1 /proc/uptime)\"; "
            + "command -v pacman >/dev/null && echo \"packages=$(pacman -Qq | wc -l)\"; "
            + "echo \"ip=$(ip -4 route get 1.1.1.1 2>/dev/null | grep -o 'src [0-9.]*' | cut -d' ' -f2)\"; "
            + "echo \"cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2)\"; "
            + "echo \"mem=$(awk '/^MemTotal/ { printf \"%.0f GiB\", $2 / 1048576 }' /proc/meminfo)\"; "
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
        px: root.small ? Theme.fit(56) : root.large ? Theme.fit(84) : Theme.fit(100)
        color: root.accent
        elide: Text.ElideNone
        lineHeight: 0.85
        anchors.verticalCenter: root.small || root.large ? undefined : parent.verticalCenter
        anchors.verticalCenterOffset: -Theme.fit(2)
    }

    // small: the host over the uptime, at the foot
    Column {
        visible: root.small
        anchors.bottom: parent.bottom
        width: parent.width
        WidgetText {
            width: parent.width
            card: root
            px: Theme.fit(13)
            text: (root.info.host || "").toUpperCase()
            color: root.accent
            font.weight: Font.Bold
            font.letterSpacing: 1
        }
        WidgetText {
            width: parent.width
            card: root
            px: Theme.fit(24)
            text: root.uptime
            font.weight: Font.Bold
        }
    }

    // large: user@host and the system beside the mark
    Column {
        visible: root.large
        x: mark.width + Theme.fit(16)
        anchors.verticalCenter: mark.verticalCenter
        width: parent.width - x
        spacing: Theme.fit(2)
        WidgetText {
            width: parent.width
            card: root
            px: Theme.fit(18)
            text: root.title
            color: root.accent
            font.weight: Font.Bold
        }
        WidgetText {
            width: parent.width
            card: root
            px: Theme.fit(14)
            text: root.uptime !== "" ? "up " + root.uptime : ""
            color: root.fgDim
        }
    }

    // the widest label, so the values line up just past it
    TextMetrics {
        id: keyWidth
        font.family: root.font
        font.pixelSize: Theme.fit(14)
        font.weight: Font.Bold
        text: root.rows.reduce((a, r) => r[0].length > a.length ? r[0] : a, "")
    }

    Column {
        visible: !root.small
        x: root.large ? 0 : mark.width + Theme.fit(20)
        y: root.large ? parent.height - height : (parent.height - height) / 2
        width: parent.width - x
        spacing: Theme.fit(root.large ? 9 : 2)

        // medium: user@host over a rule, fastfetch's head
        WidgetText {
            visible: !root.large
            width: parent.width
            card: root
            px: Theme.fit(15)
            text: root.title
            color: root.accent
            font.weight: Font.Bold
        }
        Item {
            width: parent.width
            height: root.large ? 1 : Theme.fit(7)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: root.track
            }
        }

        Repeater {
            model: root.rows
            Item {
                required property var modelData
                width: parent.width
                height: value.implicitHeight

                WidgetText {
                    id: key
                    width: keyWidth.advanceWidth + Theme.fit(12)
                    card: root
                    px: Theme.fit(14)
                    text: modelData[0]
                    color: root.accent
                    font.weight: Font.Bold
                }
                WidgetText {
                    id: value
                    x: key.width
                    width: parent.width - x
                    card: root
                    px: Theme.fit(14)
                    text: modelData[1]
                }
            }
        }
    }
}
