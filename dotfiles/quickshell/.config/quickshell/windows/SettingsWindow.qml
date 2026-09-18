// Singularity - Quickshell
// ~/.config/quickshell/windows/SettingsWindow.qml
//
// Settings: a sidebar of sections and a pane showing one of them. Changes
// apply as they're made -- there is no Save -- and each page writes straight
// to the thing it controls (mimeapps.list, hyprland.lua, hypridle.conf,
// pipewire, swaync) rather than to a store of its own -- except Appearance,
// whose shell half is Settings.qml, shared with the Control Centre's
// Appearance page.
//
// Its own FloatingWindow rather than a CentredWindow: that one is a single
// content-sized Column, and a fixed-size sidebar + pane doesn't fit it. The
// chrome is the same WindowChrome.qml.
//
// No memory: every open starts on Appearance (or the page open() is asked
// for), and the page is a Loader that only exists while the window is
// visible, so nothing a page read or ran survives a close -- and nothing runs
// at all while Settings is shut.
//
// Floating and centring come from the "quickshell-windows" rule in
// hyprland.lua, as for System and Keybinds.

import Quickshell
import QtQuick
import "../services"
import "../settings"

FloatingWindow {
    id: root

    readonly property string defaultPage: "appearance"
    property string currentPage: defaultPage

    // scaled with Font Size, since the pages' own columns are
    readonly property int sidebarWidth: Theme.fs(190)
    // Keybinds' list is laid out for 720; the page frame adds its margin
    readonly property int paneWidth: Theme.fs(740)
    readonly property int paneHeight: Theme.fs(600)

    visible: false
    title: "Settings"
    color: "transparent"

    implicitWidth: Theme.windowPad + sidebarWidth + Theme.spaceXl + 1 + Theme.spaceXl + paneWidth + Theme.windowPad
    implicitHeight: chrome.contentY + paneHeight + Theme.windowPad

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

    readonly property var pages: [
        { id: "appearance",    label: "Appearance",    icon: "󰏘", source: "../settings/SettingsPageAppearance.qml" },
        { id: "display",       label: "Display",       icon: "󰍹", source: "../settings/SettingsPageDisplay.qml" },
        { id: "audio",         label: "Audio",         icon: "󰕾", source: "../settings/SettingsPageAudio.qml" },
        { id: "input",         label: "Input",         icon: "󰌌", source: "../settings/SettingsPageInput.qml" },
        { id: "power",         label: "Power & Idle",  icon: "󰂄", source: "../settings/SettingsPagePower.qml" },
        { id: "notifications", label: "Notifications", icon: "󰂚", source: "../settings/SettingsPageNotifications.qml" },
        { id: "windowrules",   label: "Window Rules",  icon: "󰖲", source: "../settings/SettingsPageWindowRules.qml" },
        { id: "keybinds",      label: "Keybinds",      icon: "󰘳", source: "../settings/SettingsPageKeybinds.qml" },
        { id: "shell",         label: "Terminal",      icon: "󰆍", source: "../settings/SettingsPageShell.qml" },
        { id: "filetypes",     label: "File Types",    icon: "󰈔", source: "../settings/SettingsPageFileTypes.qml" },
    ]

    function select(page) {
        currentPage = page.id
        // a page's field may have had focus; give Escape back to the window
        chrome.keySink.forceActiveFocus()
    }

    WindowChrome {
        id: chrome
        window: root
        heading: "SETTINGS"
    }

    // --- sidebar -----------------------------------------------------------

    Column {
        id: sidebar
        x: Theme.windowPad
        y: chrome.contentY
        width: root.sidebarWidth
        spacing: Theme.spaceXs

        Repeater {
            model: root.pages

            SettingsNavRow {
                required property var modelData
                icon: modelData.icon
                label: modelData.label
                selected: root.currentPage === modelData.id
                onClicked: root.select(modelData)
            }
        }
    }

    Rectangle {
        id: rule
        anchors.left: sidebar.right
        anchors.leftMargin: Theme.spaceXl
        y: chrome.contentY
        width: Theme.borderWidth
        height: root.paneHeight
        color: Theme.stroke

    }

    // --- pane --------------------------------------------------------------

    Loader {
        id: pane
        anchors.left: rule.right
        anchors.leftMargin: Theme.spaceXl
        y: chrome.contentY
        width: root.paneWidth
        height: root.paneHeight
        active: root.visible
        source: {
            var p = root.pages.find(p => p.id === root.currentPage)
            return p && p.source ? p.source : ""
        }
    }
}
