// Singularity - Quickshell
// ~/.config/quickshell/services/SystemSpecs.qml
//
// The System window's static facts: the distribution and kernel, the CPU,
// GPU, board and firmware, displays, disks, input devices, the package
// database, the boot breakdown and the shell's own versions -- plus the
// copy-to-clipboard summary of them.
//
// Gathered when the window opens, not sampled: none of it changes while the
// machine is up, so each probe runs once per session and the reopen after
// that is free. The live half is SystemStats.qml.
//
// A singleton for the same reason SystemStats is one: the pages are loaded
// on demand and would otherwise each need the object handed down to them.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "Format.js" as Format

Singleton {
    id: root

    property bool active: false

    // --- identity --------------------------------------------------------

    property string kernel: ""
    property string hostname: ""
    property string distro: ""
    property string distroBuild: ""
    property string arch: ""
    property string chassis: ""

    // --- packages --------------------------------------------------------

    property int pkgCount: -1
    property int aurCount: -1
    property int explicitCount: -1
    property int orphanCount: -1
    property string cacheSize: ""
    property string lastUpgrade: ""

    // --- cpu / gpu / board ------------------------------------------------

    property string cpuModel: ""
    property string cpuVendor: ""
    property int cpuCores: 0
    property int cpuThreads: 0
    property real cpuMaxMhz: 0
    property real cpuMinMhz: 0
    property string cpuCache: ""
    property string cpuDriver: ""

    property string gpuModel: ""
    property string gpuDriver: ""
    property string mesaVersion: ""

    property string board: ""
    property string biosVendor: ""
    property string biosVersion: ""
    property string biosDate: ""

    // --- devices ----------------------------------------------------------

    // [{ name, size, model, tran, rota }], real disks only -- lsblk lists
    // the two read-only "loop-like" card-reader placeholders on this laptop
    // as 0B disks, which is noise rather than storage
    property var storage: []
    // [{ name, width, height, hz, scale, make, model }]
    property var monitors: []
    // [{ kind, name }] from Hyprland: keyboards, mice, touchpads, tablets
    property var inputs: []
    property int usbCount: -1
    property int pciCount: -1

    // --- session ----------------------------------------------------------

    property string hyprVersion: ""
    property string qsVersion: ""
    property string qtVersion: ""
    property string shellName: ""
    property string sessionType: ""
    property string bootLine: ""     // systemd-analyze's one-line summary

    // --- gathering --------------------------------------------------------

    FileView { id: kernelFile; path: "/proc/sys/kernel/osrelease"; blockLoading: true }
    FileView { id: hostFile;   path: "/proc/sys/kernel/hostname";  blockLoading: true }

    onActiveChanged: if (active) {
        kernelFile.reload()
        hostFile.reload()
        kernel = kernelFile.text().trim()
        hostname = hostFile.text().trim()
        // the package counts are the one thing here that moves during a
        // session -- an install between two opens should show
        pkgProc.running = true
        // static for the life of the machine's session; no need to re-probe
        // on every reopen the way the live gauges reset
        if (cpuModel === "") specsProc.running = true
        if (monitors.length === 0) monitorsProc.running = true
        if (inputs.length === 0) inputsProc.running = true
        if (bootLine === "") bootProc.running = true
    }

    // One shell script, one round trip, for everything that lives in a file
    // or falls out of a single tool. `column -t` isn't used -- fixed-width
    // awk fields would fall over on a model name with spaces, so each record
    // is pipe-separated or section-separated and split in onStreamFinished.
    Process {
        id: specsProc
        command: ["sh", "-c",
            // 0: cpu model, vendor, cache, cores, threads
            "awk -F': ' '/^model name/{m=$2} /^vendor_id/{v=$2} /^cache size/{c=$2} "
            + "/^cpu cores/{k=$2} /^processor/{t++} END{print m; print v; print c; print k; print t}' /proc/cpuinfo\n"
            + "echo ---\n"
            // 1: cpu frequency limits and the scaling driver
            + "for f in cpuinfo_max_freq cpuinfo_min_freq scaling_driver; do "
            + "cat /sys/devices/system/cpu/cpu0/cpufreq/$f 2>/dev/null || echo; done\n"
            + "echo ---\n"
            // 2: gpu model and the kernel driver bound to it
            // the driver line is not always the next one -- Subsystem: and
            // DeviceName: can come between -- so read on until the device's
            // block ends rather than assuming it sits directly underneath
            + "lspci -k | awk '/VGA compatible|3D controller/{sub(/^[0-9a-f:.]+ /,\"\"); "
            + "sub(/^(VGA compatible controller|3D controller): /,\"\"); print; d=\"\"; "
            + "while ((getline line) > 0) { if (line !~ /^\\t/) break; "
            + "if (line ~ /Kernel driver in use/) { sub(/.*: /,\"\",line); d=line; break } } "
            + "print d; exit}'\n"
            + "echo ---\n"
            // 3: mesa's package version
            + "pacman -Q mesa 2>/dev/null | awk '{print $2}'\n"
            + "echo ---\n"
            // 4: DMI -- board, firmware, chassis
            + "for f in sys_vendor product_name bios_vendor bios_version bios_date chassis_type; do "
            + "cat /sys/class/dmi/id/$f 2>/dev/null || echo; done\n"
            + "echo ---\n"
            // 5: disks
            + "lsblk -d -n -o NAME,SIZE,MODEL,TYPE,TRAN,ROTA\n"
            + "echo ---\n"
            // 6: distribution
            + "awk -F= '/^PRETTY_NAME=/{gsub(/\"/,\"\",$2); print $2} "
            + "/^BUILD_ID=/{gsub(/\"/,\"\",$2); b=$2} END{print b}' /etc/os-release 2>/dev/null\n"
            + "echo ---\n"
            // 7: architecture, then the counts of attached buses
            + "uname -m\n"
            // -1, not 0, when the tool isn't installed: "0 USB devices" is
            // a claim about the machine, "--" is a claim about the probe
            + "command -v lsusb >/dev/null && lsusb | wc -l || echo -1\n"
            + "command -v lspci >/dev/null && lspci | wc -l || echo -1\n"
            + "echo ---\n"
            // 8: versions of the pieces this desktop is made of
            + "hyprctl version 2>/dev/null | awk 'NR==1{print $2; exit}'\n"
            + "quickshell --version 2>/dev/null | awk 'NR==1{print $2; exit}'\n"
            + "qmake6 -query QT_VERSION 2>/dev/null || pacman -Q qt6-base 2>/dev/null | awk '{print $2}'\n"
            + "basename \"${SHELL:-}\"\n"
            + "echo \"${XDG_SESSION_TYPE:-}\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.split("\n---\n")
                function lines(n) { return (parts[n] || "").split("\n").map(s => s.trim()) }

                var cpu = lines(0)
                root.cpuModel = cpu[0] || ""
                root.cpuVendor = cpu[1] || ""
                root.cpuCache = cpu[2] || ""
                root.cpuCores = Number(cpu[3]) || 0
                root.cpuThreads = Number(cpu[4]) || 0

                var freq = lines(1)
                root.cpuMaxMhz = (Number(freq[0]) || 0) / 1000
                root.cpuMinMhz = (Number(freq[1]) || 0) / 1000
                root.cpuDriver = freq[2] || ""

                var gpu = lines(2)
                root.gpuModel = gpu[0] || ""
                root.gpuDriver = gpu[1] || ""
                root.mesaVersion = lines(3)[0] || ""

                var dmi = lines(4)
                root.board = [dmi[0], dmi[1]].filter(s => s && s !== "").join(" ").trim()
                root.biosVendor = dmi[2] || ""
                root.biosVersion = dmi[3] || ""
                root.biosDate = dmi[4] || ""
                root.chassis = root.chassisName(Number(dmi[5]))

                var disks = []
                var dl = lines(5)
                for (var i = 0; i < dl.length; i++) {
                    if (dl[i] === "") continue
                    // NAME, SIZE, TYPE, TRAN and ROTA never contain spaces,
                    // so they're safe to shift off either end; MODEL is
                    // whatever's left in the middle, and is the one field
                    // that can contain spaces ("Micron 1024GB NVMe")
                    var f = dl[i].split(/\s+/)
                    if (f.length < 5) continue
                    var rota = f.pop(), tran = f.pop(), type = f.pop()
                    var name = f.shift(), size = f.shift()
                    // real disks with a real bus only: card-reader slots
                    // report a 0B "disk" with no media in them, and zram is
                    // compressed RAM masquerading as a block device (tran "")
                    if (type !== "disk" || size === "0B" || tran === "") continue
                    disks.push({ name: name, size: size, model: f.join(" ") || "--",
                                 tran: tran, rota: rota === "1" })
                }
                root.storage = disks

                var os = lines(6)
                root.distro = os[0] || ""
                root.distroBuild = os[1] || ""

                var bus = lines(7)
                root.arch = bus[0] || ""
                root.usbCount = Number(bus[1])
                root.pciCount = Number(bus[2])

                var ver = lines(8)
                root.hyprVersion = (ver[0] || "").replace(/^v/, "")
                root.qsVersion = ver[1] || ""
                root.qtVersion = ver[2] || ""
                root.shellName = ver[3] || ""
                root.sessionType = ver[4] || ""
            }
        }
    }

    // SMBIOS chassis types, the handful a desktop actually turns up as.
    function chassisName(n) {
        var names = { 3: "Desktop", 4: "Low profile desktop", 6: "Mini tower",
                      7: "Tower", 8: "Portable", 9: "Laptop", 10: "Notebook",
                      11: "Handheld", 13: "All in one", 14: "Subnotebook",
                      30: "Tablet", 31: "Convertible", 32: "Detachable" }
        return names[n] || ""
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
                    hz: Math.round(m.refreshRate), scale: m.scale,
                    make: m.make || "", model: m.model || "",
                    description: m.description || "",
                }))
            }
        }
    }

    // Keyboards, mice and touchpads as Hyprland sees them -- the names here
    // are the ones a device rule in hyprland.lua has to match, which is the
    // reason to show them at all.
    Process {
        id: inputsProc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var d
                try { d = JSON.parse(text) } catch (e) { return }
                var out = []
                ;(d.keyboards || []).forEach(k => out.push({
                    kind: "Keyboard", name: k.name,
                    detail: k.layout || "" }))
                ;(d.mice || []).forEach(m => out.push({
                    kind: "Pointer", name: m.name, detail: "" }))
                ;(d.touch || []).forEach(t => out.push({
                    kind: "Touch", name: t.name, detail: "" }))
                ;(d.tablets || []).forEach(t => out.push({
                    kind: "Tablet", name: t.name || "", detail: "" }))
                root.inputs = out.filter(x => x.name)
            }
        }
    }

    // How long the last boot took, split the way systemd splits it. Cheap
    // and one-shot; it reads the same numbers `systemd-analyze` prints.
    Process {
        id: bootProc
        command: ["sh", "-c", "systemd-analyze 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "Startup finished in 4.2s (firmware) + ... = 21.3s"
                root.bootLine = text.trim().replace(/^Startup finished in\s*/, "")
            }
        }
    }

    // pacman -Qm is exactly the AUR set: packages installed from outside the
    // sync repos. That's what yay counts too, without needing yay. -Qtdq is
    // the orphan set: dependencies nothing depends on any more.
    Process {
        id: pkgProc
        command: ["sh", "-c",
            "pacman -Qq | wc -l\n"
            + "pacman -Qqm | wc -l\n"
            + "pacman -Qqe | wc -l\n"
            + "pacman -Qqtd 2>/dev/null | wc -l\n"
            + "du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1\n"
            // the last full upgrade, from pacman's own log
            + "awk -F'[][]' '/starting full system upgrade/{t=$2} END{print t}' "
            + "/var/log/pacman.log 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var f = text.split("\n")
                root.pkgCount = Number(f[0])
                root.aurCount = Number(f[1])
                root.explicitCount = Number(f[2])
                root.orphanCount = Number(f[3])
                root.cacheSize = (f[4] || "").trim()
                // pacman logs "2026-09-14T09:12:33+0100"; the date alone is
                // what anyone reads off this line
                root.lastUpgrade = (f[5] || "").trim().split("T")[0]
            }
        }
    }

    // --- copy --------------------------------------------------------------

    property bool copied: false

    function copySummary() {
        var s = SystemStats
        var lines = [
            "Host: " + hostname + (chassis ? " (" + chassis + ")" : ""),
            "OS: " + (distro || "--") + (arch ? " " + arch : ""),
            "Kernel: " + kernel,
            "Uptime: " + Format.duration(s.uptimeSec),
            "CPU: " + (cpuModel || "--")
                + (cpuThreads ? "  " + cpuCores + "c/" + cpuThreads + "t" : "")
                + (cpuMaxMhz ? " @ " + (cpuMaxMhz / 1000).toFixed(2) + "GHz" : ""),
            "GPU: " + (gpuModel || "--") + (gpuDriver ? " (" + gpuDriver + ")" : ""),
            "Mesa: " + (mesaVersion || "--"),
            "RAM: " + Format.kib(s.memTotalKb),
            "Board: " + (board || "--"),
            "Firmware: " + [biosVendor, biosVersion, biosDate].filter(x => x).join(" "),
            "Storage: " + (storage.length ? storage.map(d => d.model + " " + d.size).join(", ") : "--"),
            "Monitors: " + (monitors.length
                ? monitors.map(m => m.name + " " + m.width + "x" + m.height + "@" + m.hz + "Hz").join(", ") : "--"),
            "Packages: " + (pkgCount < 0 ? "--" : pkgCount + " (" + aurCount + " AUR)"),
            "Shell: Quickshell " + (qsVersion || "--") + " on Hyprland " + (hyprVersion || "--"),
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
