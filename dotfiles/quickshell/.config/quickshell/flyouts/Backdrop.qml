// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Backdrop.qml
//
// The click-off catcher behind a flyout or overlay: a press anywhere it
// covers dismisses it, with any button. On the press rather than the click,
// as menus do on every desktop: a click needs the release to land too, so a
// right or middle press, or one that dragged off, used to leave it up. The
// wheel is swallowed: nothing under the surface would get it anyway, and a
// scroll shouldn't close anything.
//
// What it sits behind needs an absorber of its own (Absorber.qml), or a
// press with a button its rows don't take falls through to this.

import QtQuick

MouseArea {
    signal dismissed()

    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
    onPressed: dismissed()
    onWheel: wheel => wheel.accepted = true
}
