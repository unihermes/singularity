// Singularity - Quickshell
// ~/.config/quickshell/windows/CentredWindow.qml
//
// A standalone window opened from the Control Centre (System, Keybinds): a
// real toplevel rather than a layer-shell flyout, so it can be focused,
// moved, alt-tabbed to and left open while you work. The flyouts close on
// click-off; these deliberately don't. Dressed like Settings and System:
// the shared WindowHeader over one framed WindowPanel holding the content,
// on a bare WindowChrome.qml for the ground and Escape.
//
// Fixed size (Theme.windowBodyHeight), so content that can run long
// scrolls inside it rather than growing the window.
//
// Floating and centring are Hyprland's job, not this file's -- see the
// "quickshell-windows" rule in hyprland.lua. Without it the monocle rule
// maximizes these like any other tiled window.

import Quickshell
import QtQuick
import "../services"

FloatingWindow {
    id: root

    property string heading: ""
    // the small line over the title, and the one under it
    property string eyebrow: ""
    property string subtitle: ""
    // content width; the height is Theme.windowBodyHeight for every window
    property int contentWidth: 380
    // what the content gets of that height, for content that fills it
    readonly property int bodyHeight: Theme.windowBodyHeight
    // data, not children: a window's content includes non-visual objects
    // (FileViews, Timers, Processes), and children only accepts Items. The
    // Column still lays out just the Items among them.
    default property alias content: body.data

    // Closed until something calls open(). Each open maps a fresh toplevel,
    // so Hyprland's rule re-centres it on the focused monitor every time.
    visible: false
    title: heading.charAt(0) + heading.slice(1).toLowerCase()
    color: "transparent"

    implicitWidth: contentWidth + Theme.panelPad * 2 + Theme.windowPad * 2
    // the same outer height as Settings and System, so the three match
    implicitHeight: panel.y + panel.height + Theme.windowPad

    function open() { visible = true }
    function close() { visible = false }

    // the compositor closing it (SUPER+Q, a click on nothing) comes through
    // here, and has to clear visible or the next open() would be a no-op
    onClosed: visible = false
    onVisibleChanged: if (visible) chrome.keySink.forceActiveFocus()

    WindowChrome {
        id: chrome
        window: root
        bare: true
    }

    WindowHeader {
        id: header
        window: root
        eyebrow: root.eyebrow
        title: root.title
        subtitle: root.subtitle
    }

    // the panel's own padding keeps square-cornered content clear of the
    // window's rounded border, which the body once had to leave room for
    WindowPanel {
        id: panel
        anchors.top: header.bottom
        anchors.topMargin: Theme.spaceXl
        x: Theme.windowPad
        width: root.width - Theme.windowPad * 2
        height: root.bodyHeight + Theme.panelPad * 2

        Column {
            id: body
            x: Theme.panelPad
            y: Theme.panelPad
            width: root.contentWidth
            height: root.bodyHeight
            clip: true
            spacing: Theme.spaceM
        }
    }
}
