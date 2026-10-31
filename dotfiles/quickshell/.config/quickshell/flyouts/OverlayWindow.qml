// Singularity - Quickshell
// ~/.config/quickshell/flyouts/OverlayWindow.qml
//
// A transparent layer surface over one whole screen, the base for flyouts,
// ALT+Tab, the workspace overlay and the toasts.
//
// What each one sets:
//   scope          the bar's per-screen scope (shell.qml); decides the screen
//   layerNamespace the layer-shell namespace, which Hyprland's layer rules
//                  match on; "unblurred-" goes before it on a display
//                  scaled under 1
//   focusMode      a WlrKeyboardFocus value; None unless the surface needs keys

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

PanelWindow {
    required property var scope
    property string layerNamespace: ""
    property int focusMode: WlrKeyboardFocus.None

    screen: scope.modelData
    anchors { top: true; left: true; right: true; bottom: true }
    // sized explicitly: anchoring all four edges leaves a PanelWindow 100x100
    implicitWidth: screen ? screen.width : 1920
    implicitHeight: screen ? screen.height : 1080
    // Ignore, so y=0 is the screen's top, not below the bar's reserved strip
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: focusMode
    // Hyprland blurs a layer on a display scaled under 1 over only its
    // pixel size (the top-left 75% at 0.75) until what's under it settles,
    // so the dim reaches the rest late; there the namespace falls outside
    // the blur rule (looks.lua)
    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    WlrLayershell.namespace: (monitor && monitor.scale < 1 ? "unblurred-" : "") + layerNamespace
}
