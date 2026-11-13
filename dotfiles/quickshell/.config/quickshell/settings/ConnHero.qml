// The card a connection page opens on (Bluetooth, VPN), pinned above its
// rows: the big glyph, a spaced-out line over the state in large type, a
// line on what that means, the page's chips (`actions`) and the round
// power button. Tinted with the accent while on.

import QtQuick
import "../services"

Rectangle {
    id: root

    property string glyph: ""
    property string eyebrow: ""
    property string title: ""
    property string line: ""
    property bool on: false
    property bool powerEnabled: true
    property bool busy: false
    // chips between the text and the power button
    default property alias actions: chips.data

    signal toggled()

    width: parent ? parent.width : 0
    height: Math.max(texts.implicitHeight, power.height) + Theme.spaceL * 2
    radius: Theme.sectionRadius
    color: Theme.controlFill("transparent")
    border.width: Theme.controlBorder(Theme.stroke)
    border.color: Theme.controlStroke(on ? Theme.strokeFocus : Theme.stroke)
    clip: true

    // the accent glow from the glyph's corner while on
    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.borderWidth
        radius: Math.max(0, root.radius - Theme.borderWidth)
        opacity: root.on ? 1 : 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) }
            GradientStop { position: 0.6; color: "transparent" }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease } }
    }

    Text {
        id: icon
        x: Theme.spaceXl
        anchors.verticalCenter: parent.verticalCenter
        text: root.glyph
        color: root.on ? Theme.accent : Theme.muted
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontHero
    }

    Column {
        id: texts
        anchors.left: icon.right
        anchors.leftMargin: Theme.spaceXl
        anchors.right: chips.left
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            visible: text !== ""
            elide: Text.ElideRight
            text: root.eyebrow.toUpperCase()
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontEyebrow
            font.letterSpacing: 1
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.title
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightStrong
            font.pixelSize: Theme.fontTitle
        }
        Text {
            width: parent.width
            visible: text !== ""
            elide: Text.ElideRight
            text: root.line
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    Row {
        id: chips
        anchors.right: power.left
        anchors.rightMargin: chips.width > 0 ? Theme.spaceXl : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceS
    }

    PowerButton {
        id: power
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceXl
        anchors.verticalCenter: parent.verticalCenter
        on: root.on
        enabled: root.powerEnabled
        busy: root.busy
        onClicked: root.toggled()
    }
}
