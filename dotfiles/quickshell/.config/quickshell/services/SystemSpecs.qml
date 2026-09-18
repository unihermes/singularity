// Singularity - Quickshell
// ~/.config/quickshell/SystemSpecs.qml
//
// The System window's static facts: kernel, hostname, package counts, CPU,
// GPU, board, storage and displays, plus the copy-to-clipboard summary of
// them. Gathered when the window opens, not sampled -- the specs only once
// per session, since none of them change while the machine is up. Owned by
// SystemStats, as its `specs`.

import Quickshell
import Quickshell.Io
import QtQuick
import "Format.js" as Format

Item {
    id: root
    visible: false

    // the live side, for the copy summary's uptime and RAM
    required property var stats
    property bool active: false

    property string kernel: ""
    property string hostname: ""
    property int pkgCount: -1
    property int aurCount: -1

    // --- specs (static; gathered once per open, not polled) -------------

    property string cpuModel: ""
    property string gpuModel: ""
    property string gpuDriver: ""
    property string mesaVersion: ""
    property string board: ""
    // [{ name, size, model }], real disks only -- lsblk lists the two
    // read-only "loop-like" card-reader placeholders on this laptop as 0B
    // disks, which is noise rather than storage
    property var storage: []
    // [{ name, width, height, hz }]
    property var monitors: []

    FileView { id: kernelFile;  path: "/proc/sys/kernel/osrelease"; blockLoading: true }
    FileView { id: hostFile;    path: "/proc/sys/kernel/hostname";  blockLoading: true }

    onActiveChanged: if (active) {
        kernelFile.reload()
        hostFile.reload()
        kernel = kernelFile.text().trim()
        hostname = hostFile.text().trim()
        pkgProc.running = true
        // static for the life of the machine's session; no need to re-probe
        // on every reopen the way the live gauges reset above
        if (cpuModel === "") specsProc.running = true
        if (monitors.length === 0) monitorsProc.running = true
    }

    // One shell script, one round trip: CPU model from /proc/cpuinfo, the
    // first VGA/3D controller lspci reports plus the kernel driver it's
    // bound to, mesa's package version, DMI board vendor + product name, and
    // the disk block devices with a real size. `column -t` isn't used --
    // fixed-width awk fields would fall over on a model name with spaces, so
    // each record is pipe-separated instead and split in onStreamFinished.
    Process {
        id: specsProc
        command: ["sh", "-c",
            "awk -F: '/model name/{print $2; exit}' /proc/cpuinfo\n"
            + "echo ---\n"
            + "lspci -k | awk '/VGA compatible|3D controller/{sub(/^[0-9a-f:.]+ /,\"\"); "
            + "sub(/^(VGA compatible controller|3D controller): /,\"\"); print; getline; "
            + "if ($0 ~ /Kernel driver in use/) { sub(/.*: /,\"\"); print } else print \"\"; exit}'\n"
            + "echo ---\n"
            + "pacman -Q mesa 2>/dev/null | awk '{print $2}'\n"
            + "echo ---\n"
            + "cat /sys/class/dmi/id/sys_vendor 2>/dev/null\n"
            + "cat /sys/class/dmi/id/product_name 2>/dev/null\n"
            + "echo ---\n"
            + "lsblk -d -n -o NAME,SIZE,MODEL,TYPE,TRAN"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.split("\n---\n")
                root.cpuModel = (parts[0] || "").trim()
                var gpu = (parts[1] || "").trim().split("\n")
                root.gpuModel = (gpu[0] || "").trim()
                root.gpuDriver = (gpu[1] || "").trim()
                root.mesaVersion = (parts[2] || "").trim()
                var dmi = (parts[3] || "").trim().split("\n")
                root.board = [dmi[0], dmi[1]].filter(s => s && s.trim() !== "").join(" ").trim()
                var disks = []
                var lines = (parts[4] || "").trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].trim() === "") continue
                    // NAME and SIZE never contain spaces, so they're safe to
                    // shift off the front; MODEL is whatever's left in the
                    // middle once TRAN and TYPE (the two before it) are
                    // peeled off the end -- MODEL is the one field that can
                    // itself contain spaces ("Micron 1024GB NVMe")
                    var f = lines[i].trim().split(/\s+/)
                    if (f.length < 4) continue
                    var tran = f.pop(), type = f.pop(), name = f.shift(), size = f.shift()
                    // real disks with a real bus only: card-reader slots
                    // report a 0B "disk" with no media in them, and zram is
                    // compressed RAM masquerading as a block device (tran "")
                    if (type !== "disk" || size === "0B" || tran === "") continue
                    disks.push({ name: name, size: size, model: f.join(" ") || "--", tran: tran })
                }
                root.storage = disks
            }
        }
    }

    // Refresh rate isn't in Quickshell's own Screen type, only in Hyprland's
    // IPC -- and unlike Quickshell.screens, that's already keyed by name in
    // an order matching nothing in particular, so match by name below rather
    // than assuming the two lists line up.
    Process {
        id: monitorsProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var data
                try { data = JSON.parse(text) } catch (e) { return }
                root.monitors = data.map(m => ({
                    name: m.name, width: m.width, height: m.height,
                    hz: Math.round(m.refreshRate),
                }))
            }
        }
    }

    // pacman -Qm is exactly the AUR set: packages installed from outside the
    // sync repos. That's what yay counts too, without needing yay.
    Process {
        id: pkgProc
        command: ["sh", "-c", "pacman -Qq | wc -l; pacman -Qqm | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                var f = text.trim().split("\n")
                root.pkgCount = Number(f[0])
                root.aurCount = Number(f[1])
            }
        }
    }

    // --- copy --------------------------------------------------------------

    property bool copied: false

    function copySummary() {
        var lines = [
            "Host: " + hostname, "Kernel: " + kernel, "Uptime: " + Format.duration(stats.uptimeSec),
            "CPU: " + (cpuModel || "--"),
            "GPU: " + (gpuModel || "--") + (gpuDriver ? " (" + gpuDriver + ")" : ""),
            "Mesa: " + (mesaVersion || "--"),
            "RAM: " + Format.kib(stats.memTotalKb),
            "Board: " + (board || "--"),
            "Storage: " + (storage.length ? storage.map(d => d.model + " " + d.size).join(", ") : "--"),
            "Monitors: " + (monitors.length
                ? monitors.map(m => m.name + " " + m.width + "x" + m.height + "@" + m.hz + "Hz").join(", ") : "--"),
            "Packages: " + (pkgCount < 0 ? "--" : pkgCount + " (" + aurCount + " AUR)"),
        ]
        // the text goes in argv, not down stdin -- Process exposes no way to
        // close stdin's write end, and wl-copy blocks reading until EOF
        copyProc.command = ["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", lines.join("\n") + "\n"]
        copyProc.running = true
        copied = true
        copiedTimer.restart()
    }

    Timer { id: copiedTimer; interval: 1600; onTriggered: root.copied = false }

    Process { id: copyProc; command: ["true"] }
}
