// Singularity - Quickshell
// ~/.config/quickshell/windows/System.qml
//
// System: what this machine is and what it is doing. Home answers "is
// anything wrong" at a glance -- four headline figures with their last
// minute, then every page as a tile carrying its own live figure; the pages
// behind it go as deep as the kernel will let us on the CPU, memory,
// storage, network, processes, hardware, power and -- since every answer
// here ends in "where do I change that" -- the config files themselves.
//
// The numbers come from services/SystemStats.qml (live, sampled only while
// this window is visible) and services/SystemSpecs.qml (static, gathered
// once per session). Appearance settings are deliberately not duplicated
// here -- they live in Settings.
//
// Laid out like Settings: the shared one-line WindowHeader (System › Page
// inside a page, with a back button to Home), then one framed panel
// showing Home (WindowHome.qml) or the open page. The ground and Escape
// are a bare WindowChrome.qml, and the window opens at Theme.windowSize,
// the same size as Settings.
//
// Floating and centring come from the "quickshell-windows" rule in
// windows.lua, as for Settings.

import Quickshell
import QtQuick
import "../services"
import "../services/Format.js" as Format
import "../settings"
import "../flyouts"
// the pages are loaded by URL below, but naming the directory here is what
// registers its types -- without it a page cannot reach its own siblings
import "system"

FloatingWindow {
    id: root

    // the open page, or "" for Home
    property string currentPage: ""

    visible: false
    title: "System"
    color: "transparent"

    implicitWidth: Theme.windowSize.width
    implicitHeight: Theme.windowSize.height

    // an unknown or empty page opens Home
    function open(page) {
        currentPage = pages.some(p => p.id === page) ? page : ""
        home.toTop()
        visible = true
    }
    function close() { visible = false }

    // the compositor closing it has to clear visible, or the next open()
    // would be a no-op
    onClosed: visible = false
    onVisibleChanged: if (visible) chrome.keySink.forceActiveFocus()

    // Sampling follows the window, not the page: switching pages shouldn't
    // reset the 60-second graphs, and a page that isn't on screen costs
    // nothing beyond the numbers Home needed anyway.
    Binding { target: SystemStats; property: "active"; value: root.visible }
    Binding { target: SystemSpecs; property: "active"; value: root.visible }
    // The Processes page wants a full table; everywhere else five rows is
    // the summary. Asking `top` for fewer rows is the cheaper default.
    Binding {
        target: SystemStats
        property: "procLimit"
        value: root.currentPage === "processes" ? 18 : 5
    }

    // in Home's groups, in Home's order
    readonly property var groups: [
        { heading: "Status",       ids: ["health"] },
        { heading: "Running",      ids: ["cpu", "memory", "processes"] },
        { heading: "Devices",      ids: ["storage", "network", "power"] },
        { heading: "This machine", ids: ["hardware", "config"] },
    ]
    readonly property var pages: [
        { id: "health",    label: "Health",    icon: "󰓙", blurb: "Checks, and what needs a look",   source: "system/PageHealth.qml" },
        { id: "cpu",       label: "CPU",       icon: "󰻠", blurb: "Load, cores and frequency",       source: "system/PageCpu.qml" },
        { id: "memory",    label: "Memory",    icon: "󰘚", blurb: "RAM, swap and what holds it",     source: "system/PageMemory.qml" },
        { id: "processes", label: "Processes", icon: "󰅐", blurb: "What's running, heaviest first",  source: "system/PageProcesses.qml" },
        { id: "storage",   label: "Storage",   icon: "󰋊", blurb: "Disks, partitions and space",     source: "system/PageStorage.qml" },
        { id: "network",   label: "Network",   icon: "󰖩", blurb: "The link, traffic and addresses", source: "system/PageNetwork.qml" },
        { id: "power",     label: "Power",     icon: "󰂄", blurb: "Battery, draw and profile",       source: "system/PagePower.qml" },
        { id: "hardware",  label: "Hardware",  icon: "󰢻", blurb: "Board, chips and devices",        source: "system/PageHardware.qml" },
        { id: "config",    label: "Config",    icon: "󰈔", blurb: "The files behind it all",         source: "system/PageConfig.qml" },
    ]
    readonly property var openPage: pages.find(p => p.id === currentPage) || null

    // --- Home's tiles: each page's live figure --------------------------------

    readonly property real netPeak: Math.max(65536,
        Math.max.apply(null, SystemStats.rxHistory.concat([0])))

    function tile(id) {
        switch (id) {
        case "health":
            if (Health.lastScan === "") return { status: Health.scanning ? "Checking…" : "Not checked yet" }
            if (Health.problems + Health.warnings > 0)
                return { status: (Health.problems + Health.warnings) + " to look at",
                         color: Health.problems > 0 ? Theme.alert : Theme.textStrong }
            return { status: "All clear · " + Health.checks.length + " checks", color: Theme.good }
        case "cpu":
            return {
                status: [SystemStats.cpuHistory.length > 0 ? Format.pct(SystemStats.cpu) : "--",
                         SystemStats.cpuMhz > 0 ? (SystemStats.cpuMhz / 1000).toFixed(1) + " GHz" : "",
                         SystemStats.tempC >= 0 ? Math.round(SystemStats.tempC) + "°C" : ""].filter(t => t).join(" · "),
                color: SystemStats.cpu >= 0.9 ? Theme.alert : undefined,
                history: SystemStats.cpuHistory }
        case "memory":
            return {
                status: Format.pct(SystemStats.mem) + " · " + Format.kib(SystemStats.memUsedKb) + " of " + Format.kib(SystemStats.memTotalKb),
                color: SystemStats.mem >= 0.9 ? Theme.alert : undefined,
                history: SystemStats.memHistory }
        case "processes":
            return { status: SystemStats.threadTotal + " threads · " + SystemStats.procRunning + " running" }
        case "storage":
            return SystemStats.diskSize > 0
                ? { status: Format.bytes(SystemStats.diskSize - SystemStats.diskUsed) + " free on /",
                    color: SystemStats.diskUsed / SystemStats.diskSize >= 0.9 ? Theme.alert : undefined }
                : { status: "" }
        case "network":
            return SystemStats.iface === ""
                ? { status: "Offline", color: Theme.alert }
                : { status: SystemStats.iface + " · ↓ " + Format.rate(Math.max(0, SystemStats.rxRate)),
                    history: SystemStats.rxHistory, historyCeiling: netPeak * 1.15 }
        case "power":
            if (SystemStats.batNowWh <= 0) return { status: "" }
            return { status: "Battery " + (Number(SystemStats.bat.capacity) || 0) + "%"
                + (SystemStats.batHours > 0
                    ? " · " + Format.duration(SystemStats.batHours * 3600) + (SystemStats.batCharging ? " to full" : " left")
                    : SystemStats.batCharging ? " · charging" : "") }
        case "hardware":
            return { status: SystemSpecs.board }
        case "config":
            return { status: Updates.repoBehind > 0
                ? Updates.repoBehind + (Updates.repoBehind === 1 ? " commit behind" : " commits behind") : "" }
        }
        return { status: "" }
    }
    readonly property var homeGroups: groups.map(g => ({
        heading: g.heading,
        items: g.ids.map(id => {
            var p = pages.find(p => p.id === id), t = tile(id)
            return { id: id, icon: p.icon, label: p.label, blurb: p.blurb, status: t.status,
                     statusColor: t.color, history: t.history, historyCeiling: t.historyCeiling }
        })
    }))

    function select(id) {
        currentPage = id
        // a page's field may have had focus; give Escape back to the window
        chrome.keySink.forceActiveFocus()
    }

    WindowChrome {
        id: chrome
        window: root
    }

    WindowHeader {
        id: header
        window: root
        title: "System"
        subtitle: (SystemSpecs.hostname || "--") + " · " + (SystemSpecs.distro || "Linux")
        page: root.openPage ? root.openPage.label : ""
        onBack: root.select("")
    }

    // --- the panel: Home or the open page ------------------------------------

    WindowPanel {
        anchors.top: header.bottom
        anchors.topMargin: Theme.spaceXl
        x: Theme.windowPad
        width: root.width - Theme.windowPad * 2
        // the window's real size, not the one asked for: the two differ
        // after a density or Font Size change while the window is open, which
        // leaves the window as it was and re-lays out what's inside
        height: root.height - y - Theme.windowPad

        WindowHome {
            id: home
            x: Theme.panelPad
            y: Theme.panelPad
            width: parent.width - Theme.panelPad * 2
            height: parent.height - Theme.panelPad * 2
            visible: root.currentPage === ""
            groups: root.homeGroups
            header: HomeFigures { onActivated: id => root.select(id) }
            onActivated: id => root.select(id)
        }

        Loader {
            id: pane
            // sections folded on this window's pages (FlyoutHeading),
            // kept across page switches and dropped with the window
            property var foldedSections: []
            x: Theme.panelPad
            y: Theme.panelPad
            width: parent.width - Theme.panelPad * 2
            height: parent.height - Theme.panelPad * 2
            active: root.visible && root.openPage !== null
            // built off the render loop, so the window maps at once and
            // the page lands a moment later instead of holding up both
            asynchronous: true
            source: root.openPage ? root.openPage.source : ""
        }
    }
}
