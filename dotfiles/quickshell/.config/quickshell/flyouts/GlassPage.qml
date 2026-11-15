// A Control Centre sub-page's body in Glass: its content on one frosted
// card at least `fillHeight` tall, so every page matches the home's size.
// Other looks get the content bare.

import QtQuick
import "../services"

Item {
    id: root

    default property alias content: inner.data
    property real fillHeight: 0
    readonly property int pad: Theme.glass ? Theme.spaceL : 0

    width: parent ? parent.width : 0
    height: Theme.glass ? Math.max(fillHeight, inner.height + pad * 2) : inner.height

    GlassCard {
        anchors.fill: parent
        visible: Theme.glass
    }
    Item {
        id: inner
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        height: childrenRect.height
    }
}
