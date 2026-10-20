// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Backdrop.qml
//
// The click-off catcher behind a flyout or overlay: any press (not click)
// dismisses; the wheel is swallowed. The panel needs an Absorber of its own,
// or presses its rows don't take fall through to this.

import QtQuick

MouseArea {
    signal dismissed()

    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
    onPressed: dismissed()
    onWheel: wheel => wheel.accepted = true
}
