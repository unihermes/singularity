// Singularity - Quickshell
// ~/.config/quickshell/windows/KeybindsWindow.qml
//
// Keybinds on its own (SUPER+K, the Control Centre's Keybinds row): the
// window header over one framed panel holding the same page Settings shows
// under Keybinds -- SettingsPageKeybinds, and through it KeybindsBody and
// the page's toast -- so the two are one editor in two places.
//
// The ground and Escape come from WindowChrome.qml; floating and centring
// from the "quickshell-windows" rule in windows.lua, as for Settings.

import Quickshell
import QtQuick
import "../services"
import "../settings"
import "../flyouts"

FloatingWindow {
    id: root

    visible: false
    title: "Keybinds"
    color: "transparent"

    implicitWidth: Theme.windowSize.width
    implicitHeight: Theme.windowSize.height

    function open() { visible = true }
    function close() { visible = false }

    // the compositor closing it has to clear visible, or the next open()
    // would be a no-op
    onClosed: visible = false
    onVisibleChanged: if (visible) chrome.keySink.forceActiveFocus()

    WindowChrome {
        id: chrome
        window: root

        // `/` puts the cursor in the search, as in Settings
        Keys.onPressed: event => {
            if (event.text === "/" && page.item) {
                page.item.focusSearch()
                event.accepted = true
            }
        }
    }

    WindowHeader {
        id: header
        window: root
        eyebrow: "DESKTOP CONFIGURATION"
        title: "Keybinds"
        subtitle: "Every shortcut in binds.lua, and presets worth adding"
    }

    WindowPanel {
        anchors.top: header.bottom
        anchors.topMargin: Theme.spaceXl
        x: Theme.windowPad
        width: root.width - Theme.windowPad * 2
        height: root.height - y - Theme.windowPad

        // only while open, as Settings' pages are: nothing is parsed or
        // watched while the window is shut
        Loader {
            id: page
            x: Theme.panelPad
            y: Theme.panelPad
            width: parent.width - Theme.panelPad * 2
            height: parent.height - Theme.panelPad * 2
            active: root.visible
            // built off the render loop, so the window maps at once and
            // the page lands a moment later instead of holding up both
            asynchronous: true
            sourceComponent: SettingsPageKeybinds { headed: false }
        }
    }
}
