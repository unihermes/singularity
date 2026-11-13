// A tile on a connection page (a VPN server, what goes through the
// tunnel): a FlyoutTile a click acts on, with small items in its top
// right corner (`corner`) and the search ring, as a field has, when
// `label` is what Settings' search picked.

import QtQuick
import "../services"
import "../flyouts"

Item {
    id: root

    // what Settings' search knows it by
    property string label: ""
    readonly property bool isSettingsField: true
    property alias glyph: tile.glyph
    property alias title: tile.title
    property alias caption: tile.caption
    property alias lit: tile.lit
    property alias big: tile.big
    property alias dimmed: tile.dimmed
    property bool clickable: true
    default property alias extra: tile.extra
    property alias corner: cornerRow.data
    readonly property alias hovered: hover.hovered

    signal clicked()

    HoverHandler { id: hover }

    readonly property var hostPage: {
        for (var p = parent; p; p = p.parent)
            if (p.isSettingsPage === true) return p
        return null
    }

    implicitHeight: tile.implicitHeight

    FlyoutTile {
        id: tile
        anchors.fill: parent
        clickable: root.clickable
        onClicked: root.clicked()
    }

    Row {
        id: cornerRow
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.spaceM
        spacing: Theme.spaceS
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -Theme.spaceXs
        radius: Theme.radiusInner + Theme.spaceXs
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.accent
        opacity: root.hostPage && root.label !== "" && root.hostPage.highlight === root.label ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease } }
    }
}
