// Singularity - Quickshell
// ~/.config/quickshell/windows/System.qml
//
// System: what this machine is and what it is doing, as a sidebar of pages
// rather than one wall of columns. Overview answers "is anything wrong" at a
// glance; the pages behind it go as deep as the kernel will let us on the
// CPU, memory, storage, network, processes, hardware, power and -- since
// every answer here ends in "where do I change that" -- the config files
// themselves.
//
// The numbers come from services/SystemStats.qml (live, sampled only while
// this window is visible) and services/SystemSpecs.qml (static, gathered
// once per session). Appearance settings are deliberately not duplicated
// here -- they live in Settings.
//
// Laid out like Settings: the shared WindowHeader, then two framed panels
// -- the numbered Sections on the left, the open page on the right. The
// ground and Escape are a bare WindowChrome.qml, and the window opens at
// Theme.systemWindowSize.
//
// Floating and centring come from the "quickshell-windows" rule in
// hyprland.lua, as for Settings and Keybinds.

import Quickshell
import QtQuick
import "../services"
import "../settings"
import "../flyouts"
// the pages are loaded by URL below, but naming the directory here is what
// registers its types -- without it a page cannot reach its own siblings
import "system"

FloatingWindow {
    id: root

    readonly property string defaultPage: "overview"
    property string currentPage: defaultPage

    // scaled with Font Size, since the pages' own rows are; the page gets
    // whatever the window has left
    readonly property int sidebarWidth: Theme.fit(240)

    visible: false
    title: "System"
    color: "transparent"

    implicitWidth: Theme.systemWindowSize.width
    implicitHeight: Theme.systemWindowSize.height

    // an unknown or empty page opens the default one
    function open(page) {
        currentPage = pages.some(p => p.id === page) ? page : defaultPage
        visible = true
    }
    function close() { visible = false }

    // the compositor closing it has to clear visible, or the next open()
    // would be a no-op
    onClosed: visible = false
    onVisibleChanged: if (visible) chrome.keySink.forceActiveFocus()

    // Sampling follows the window, not the page: switching pages shouldn't
    // reset the 60-second graphs, and a page that isn't on screen costs
    // nothing beyond the numbers the Overview needed anyway.
    Binding { target: SystemStats; property: "active"; value: root.visible }
    Binding { target: SystemSpecs; property: "active"; value: root.visible }
    // The Processes page wants a full table; everywhere else five rows is
    // the summary. Asking `top` for fewer rows is the cheaper default.
    Binding {
        target: SystemStats
        property: "procLimit"
        value: root.currentPage === "processes" ? 18 : 5
    }

    readonly property var pages: [
        { id: "overview",  label: "Overview",  icon: "󰍹", blurb: "Health at a glance",       source: "system/PageOverview.qml" },
        { id: "health",    label: "Health",    icon: "󰓙", blurb: "Problems and fixes", source: "system/PageHealth.qml" },
        { id: "cpu",       label: "CPU",       icon: "󰻠", blurb: "Load, cores and clocks",   source: "system/PageCpu.qml" },
        { id: "memory",    label: "Memory",    icon: "󰘚", blurb: "RAM, swap and zram",       source: "system/PageMemory.qml" },
        { id: "storage",   label: "Storage",   icon: "󰋊", blurb: "Disks and mounts",         source: "system/PageStorage.qml" },
        { id: "network",   label: "Network",   icon: "󰖩", blurb: "Links and throughput",     source: "system/PageNetwork.qml" },
        { id: "processes", label: "Processes", icon: "󰅐", blurb: "What's running",           source: "system/PageProcesses.qml" },
        { id: "hardware",  label: "Hardware",  icon: "󰢻", blurb: "Devices and sensors",      source: "system/PageHardware.qml" },
        { id: "power",     label: "Power",     icon: "󰂄", blurb: "Battery and profile",      source: "system/PagePower.qml" },
        { id: "config",    label: "Config",    icon: "󰈔", blurb: "The files behind it all",  source: "system/PageConfig.qml" },
    ]
    function select(id) {
        currentPage = id
        // a page's field may have had focus; give Escape back to the window
        chrome.keySink.forceActiveFocus()
    }

    WindowChrome {
        id: chrome
        window: root
        bare: true
    }

    WindowHeader {
        id: header
        window: root
        eyebrow: "MACHINE STATUS"
        title: "System"
        subtitle: (SystemSpecs.hostname || "--") + " / " + (SystemSpecs.distro || "Linux")
    }

    // --- panels ------------------------------------------------------------

    Item {
        id: panels
        anchors.top: header.bottom
        anchors.topMargin: Theme.spaceXl
        x: Theme.windowPad
        width: root.width - Theme.windowPad * 2
        // the window's real size, not the one asked for: the two differ
        // after a density or Font Size change while the window is open, which
        // leaves the window as it was and re-lays out what's inside
        height: root.height - y - Theme.windowPad

        // the pages
        WindowPanel {
            id: sidebar
            width: root.sidebarWidth
            height: parent.height

            FlyoutHeading {
                id: listHeading
                x: Theme.panelPad
                y: Theme.panelPad
                width: parent.width - Theme.panelPad * 2
                text: "SECTIONS"
            }

            Column {
                anchors.top: listHeading.bottom
                anchors.topMargin: Theme.spaceL
                x: Theme.panelPad
                width: parent.width - Theme.panelPad * 2
                spacing: Theme.spaceXs

                Repeater {
                    model: root.pages

                    SettingsSectionRow {
                        required property var modelData
                        required property int index
                        number: (index < 9 ? "0" : "") + (index + 1)
                        icon: modelData.icon
                        label: modelData.label
                        blurb: modelData.blurb
                        selected: root.currentPage === modelData.id
                        onClicked: root.select(modelData.id)
                    }
                }
            }
        }

        // the open page
        WindowPanel {
            anchors.left: sidebar.right
            anchors.leftMargin: Theme.spaceXl
            anchors.right: parent.right
            height: parent.height

            Loader {
                id: pane
                x: Theme.panelPad
                y: Theme.panelPad
                width: parent.width - Theme.panelPad * 2
                height: parent.height - Theme.panelPad * 2
                active: root.visible
                source: {
                    var p = root.pages.find(p => p.id === root.currentPage)
                    return p && p.source ? p.source : ""
                }
            }
        }
    }
}
