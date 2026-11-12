// Singularity - Quickshell
// A level clipped from a full-size rounded track.

import QtQuick
import "../services"

Item {
    id: root
    property real fraction: 0
    property real corner: 0
    property color fillColor: Theme.meterFill
    property bool animated: true
    property bool vertical: false
    readonly property real amount: Math.max(0, Math.min(1, fraction))
    y: vertical ? parent.height - height : 0
    height: vertical ? parent.height * amount : parent.height
    width: vertical ? parent.width : parent.width * amount
    clip: true

    Rectangle {
        width: root.parent.width
        height: root.vertical ? root.parent.height : root.height
        y: root.vertical ? root.height - height : 0
        radius: root.corner
        color: root.fillColor
        Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
    }
    Behavior on width {
        enabled: root.animated
        NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease }
    }
    Behavior on height {
        enabled: root.animated
        NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease }
    }
}
