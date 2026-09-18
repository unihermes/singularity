// Singularity - Quickshell
// ~/.config/quickshell/OverlayWindow.qml
//
// A transparent layer-shell surface covering one whole screen, above
// everything. The base for every full-screen surface the shell puts up:
// flyouts (FlyoutPanel), the ALT+Tab switcher, the workspace overlay, and the
// volume/brightness and layout toasts. Each used to declare this setup itself.
//
// What each one sets:
//   scope          the bar's per-screen scope (shell.qml); decides the screen
//   layerNamespace the layer-shell namespace, which Hyprland's layer rules
//                  match on
//   focusMode      a WlrKeyboardFocus value; None unless the surface needs keys

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    required property var scope
    property string layerNamespace: ""
    property int focusMode: WlrKeyboardFocus.None

    screen: scope.modelData
    anchors { top: true; left: true; right: true; bottom: true }
    // Anchoring to all four edges does NOT stretch a PanelWindow -- it stays
    // at its default 100x100, so a backdrop would only cover a corner (and
    // click-off-to-close would only work there) and a box positioned against
    // a screen edge would land in the wrong place. The size has to be given
    // explicitly.
    implicitWidth: screen ? screen.width : 1920
    implicitHeight: screen ? screen.height : 1080
    // Ignore, not a zero zone: with a plain exclusiveZone the compositor
    // still lays the surface out *below* the bar's reserved strip, so its
    // y=0 is the bar's bottom edge and anything offset by the bar's height
    // would move twice over.
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: focusMode
    WlrLayershell.namespace: layerNamespace
}
