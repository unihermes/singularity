// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Absorber.qml
//
// Fills a panel's box under its rows and takes every press they don't, so
// none reaches the Backdrop behind and closes the panel: a right-click on a
// row that only answers the left, or a click between rows.

import QtQuick

MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
}
