// Singularity - Quickshell
// ~/.config/quickshell/desktop/SysInfoWidget.qml
//
// The machine at a glance. A head of the distro's mark in the accent
// beside the host and a line under it. Medium: the system and kernel under
// the host, then uptime, packages and local IP as three captioned figures.
// Large: the user and uptime under the host, then a System group (OS,
// kernel, WM, packages, IP) and a Hardware one (CPU, GPU, memory). Small:
// the mark, then the host over the uptime and when it booted. What doesn't
// change is read once; packages and the IP once a minute.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"

WidgetCard {
    id: root

    // read once: os, kernel, host, cpu, gpu, mem, wm, uptime
    property var specs: ({})
    // read each minute: packages, ip
    property var live: ({})
    // when the machine booted, epoch seconds
    property real boot: 0
    property real now: Date.now() / 1000

    function since(sec) {
        sec = Math.max(0, sec)
        const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60)
        return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m"
    }
    // "key=value" lines
    function kvOf(text) {
        const kv = {}
        for (const line of text.split("\n")) {
            const i = line.indexOf("=")
            if (i > 0) kv[line.slice(0, i)] = line.slice(i + 1).trim()
        }
        return kv
    }

    readonly property string uptime: boot > 0 ? since(now - boot) : ""
    readonly property string host: specs.host || ""
    readonly property var figures: [["Uptime", uptime], ["Packages", live.packages], ["IP", live.ip]]
    readonly property var groups: [
        { title: "System", rows: [["OS", specs.os], ["Kernel", specs.kernel], ["WM", specs.wm],
                                  ["Packages", live.packages], ["IP", live.ip]].filter(r => !!r[1]) },
        { title: "Hardware", rows: [["CPU", specs.cpu], ["GPU", specs.gpu], ["Memory", specs.mem]].filter(r => !!r[1]) }
    ]

    Process {
        running: true
        command: ["sh", "-c",
            ". /etc/os-release; echo \"os=${PRETTY_NAME:-$NAME}\"; echo \"kernel=$(uname -r)\"; "
            + "echo \"host=$(cat /proc/sys/kernel/hostname)\"; echo \"uptime=$(cut -d' ' -f1 /proc/uptime)\"; "
            + "echo \"cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2)\"; "
            + "echo \"mem=$(awk '/^MemTotal/ { printf \"%.0f GiB\", $2 / 1048576 }' /proc/meminfo)\"; "
            + "echo \"gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d' | head -1 | sed 's/.*: //')\"; "
            + "echo \"wm=Hyprland $(hyprctl version -j 2>/dev/null | grep -o '\"tag\": *\"[^\"]*' | sed 's/.*\"//')\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = root.kvOf(text)
                // the card's own words: "GeForce RTX 4070", not the vendor's line
                const gpu = (kv.gpu || "").match(/\[([^\]]+)\]/)
                if (gpu) kv.gpu = gpu[1]
                kv.cpu = (kv.cpu || "").replace(/ \d+-Core Processor$/, "").replace(/\(R\)|\(TM\)/g, "")
                root.boot = Date.now() / 1000 - Number(kv.uptime || 0)
                root.specs = kv
            }
        }
    }

    // pacman's local database holds a directory per package and one file
    Process {
        id: liveProbe
        running: true
        command: ["sh", "-c",
            "[ -d /var/lib/pacman/local ] && echo \"packages=$(find /var/lib/pacman/local -mindepth 1 -maxdepth 1 -type d | wc -l)\"; "
            + "echo \"ip=$(ip -4 route get 1.1.1.1 2>/dev/null | grep -o 'src [0-9.]*' | cut -d' ' -f2)\""]
        stdout: StdioCollector {
            onStreamFinished: root.live = root.kvOf(text)
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            root.now = Date.now() / 1000
            if (!liveProbe.running) liveProbe.running = true
        }
    }

    // the head: the distro's mark (Arch's, else Tux) beside the host and a
    // line under it
    Item {
        id: head
        visible: !root.small
        width: parent.width
        height: mark.height

        WidgetText {
            id: mark
            card: root
            text: (root.specs.os || "").indexOf("Arch") !== -1 ? "󰣇" : "󰌽"
            font.family: Theme.fontIcon
            px: root.large ? Theme.fit(52) : Theme.fit(44)
            color: root.accent
            elide: Text.ElideNone
        }
        Column {
            anchors.left: mark.right
            anchors.leftMargin: Theme.fit(12)
            anchors.right: parent.right
            anchors.verticalCenter: mark.verticalCenter
            WidgetText {
                width: parent.width
                card: root
                px: root.large ? Theme.fit(20) : root.textTitle
                text: root.host
                font.weight: root.weightStrong
            }
            WidgetText {
                width: parent.width
                card: root
                px: root.textCaption
                color: root.fgDim
                text: root.large
                    ? [Quickshell.env("USER") || "", root.uptime !== "" ? "up " + root.uptime : ""].filter(s => s !== "").join(" · ")
                    : [root.specs.os || "", root.specs.kernel || ""].filter(s => s !== "").join(" · ")
            }
        }
    }

    Rectangle {
        id: rule
        visible: !root.small
        // large: under the head; medium: halfway to the figures
        y: root.large ? head.height + Theme.fit(14) : Math.round((head.height + figureRow.y) / 2)
        width: parent.width
        height: 1
        color: root.track
    }

    // medium: three captioned figures along the foot
    Row {
        id: figureRow
        visible: !root.small && !root.large
        anchors.bottom: parent.bottom
        width: parent.width

        Repeater {
            model: root.figures
            Column {
                required property var modelData
                width: parent.width / 3
                spacing: Theme.fit(2)
                WidgetCaption {
                    width: parent.width
                    card: root
                    text: modelData[0]
                }
                WidgetText {
                    width: parent.width - Theme.fit(6)
                    card: root
                    px: root.textTitle
                    text: modelData[1] || "-"
                }
            }
        }
    }

    // large: the groups, a caption over rows of label and value, the
    // values lined up just past the widest label
    TextMetrics {
        id: labelWidth
        font.family: root.font
        font.pixelSize: root.textBody
        font.weight: root.weightBody
        text: "Packages"
    }
    Column {
        id: groupList
        visible: root.large
        anchors.top: rule.bottom
        anchors.topMargin: Theme.fit(14)
        anchors.bottom: parent.bottom
        width: parent.width
        readonly property real rowHeight: Theme.fit(21)
        readonly property real captionHeight: Theme.fit(22)
        // the room left over, between the groups
        spacing: Math.max(Theme.fit(8), height - root.groups.reduce((h, g) =>
            h + captionHeight + g.rows.length * rowHeight, 0))

        Repeater {
            model: root.large ? root.groups : []
            Column {
                required property var modelData
                width: groupList.width
                WidgetCaption {
                    width: parent.width
                    height: groupList.captionHeight
                    card: root
                    text: modelData.title
                }
                Repeater {
                    model: modelData.rows
                    Item {
                        required property var modelData
                        width: groupList.width
                        height: groupList.rowHeight
                        WidgetText {
                            id: label
                            width: labelWidth.advanceWidth + Theme.fit(16)
                            card: root
                            text: modelData[0]
                            color: root.fgDim
                        }
                        WidgetText {
                            x: label.width
                            width: parent.width - x
                            card: root
                            text: modelData[1]
                        }
                    }
                }
            }
        }
    }

    // small: the mark, then the host over the uptime and when it booted
    WidgetText {
        visible: root.small
        card: root
        text: mark.text
        font.family: Theme.fontIcon
        px: Theme.fit(40)
        color: root.accent
        elide: Text.ElideNone
    }
    Column {
        visible: root.small
        anchors.bottom: parent.bottom
        width: parent.width
        WidgetCaption {
            width: parent.width
            card: root
            text: root.host
        }
        WidgetText {
            width: parent.width
            card: root
            px: Theme.fit(26)
            text: root.uptime
        }
        WidgetText {
            width: parent.width
            card: root
            px: root.textCaption
            color: root.fgDim
            text: root.boot <= 0 ? ""
                : "up since " + (root.now - root.boot > 86400 ? Qt.formatDate(new Date(root.boot * 1000), "d MMM")
                                                              : Qt.formatTime(new Date(root.boot * 1000), Theme.timeFormat))
        }
    }
}
