// Singularity - Quickshell
// ~/.config/quickshell/windows/CentredWindow.qml
//
// A standalone window opened from the Control Centre (System, Keybinds): a
// real toplevel rather than a layer-shell flyout, so it can be focused,
// moved, alt-tabbed to and left open while you work. The flyouts close on
// click-off; these deliberately don't. The chrome is WindowChrome.qml.
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
    // content width; the height is Theme.windowBodyHeight for every window
    property int contentWidth: 380
    // what the content gets of that height, for content that fills it
    readonly property int bodyHeight: implicitHeight - chrome.contentY - Theme.sp(40)
    // data, not children: a window's content includes non-visual objects
    // (FileViews, Timers, Processes), and children only accepts Items. The
    // Column still lays out just the Items among them.
    default property alias content: body.data

    // Closed until something calls open(). Each open maps a fresh toplevel,
    // so Hyprland's rule re-centres it on the focused monitor every time.
    visible: false
    title: heading.charAt(0) + heading.slice(1).toLowerCase()
    color: "transparent"

    implicitWidth: contentWidth + 2 * Theme.windowPad
    // the same outer height as Settings, so the three match
    implicitHeight: chrome.contentY + Theme.windowBodyHeight + Theme.windowPad

    // bodyHeight leaves 40 below the content, not the 16 pad: the panel's
    // outer border is rounded (Theme.radius), and a
    // content block whose own corners are square sitting right at a 16px
    // inset could still poke past that curve into the double border near the
    // very bottom -- happened with System's network graph, the tallest
    // column's last element and the one nearest a corner. 24 wasn't enough
    // once the network column grew a Type/IP/Signal block above the graph.

    function open() { visible = true }
    function close() { visible = false }

    // the compositor closing it (SUPER+Q, a click on nothing) comes through
    // here, and has to clear visible or the next open() would be a no-op
    onClosed: visible = false

    WindowChrome {
        id: chrome
        window: root
        heading: root.heading
    }

    Column {
        id: body
        x: Theme.windowPad
        y: chrome.contentY

        width: root.contentWidth
        height: root.bodyHeight
        clip: true
        spacing: Theme.spaceM
    }
}
