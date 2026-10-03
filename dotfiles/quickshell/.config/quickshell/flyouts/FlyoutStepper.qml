// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutStepper.qml
//
// An integer setting in a flyout: a label, a minus, the value, a plus.
//
// A stepper rather than Slider.qml, which the volume and brightness panels
// use. Those are 0-100 and approximate -- you drag until it looks right.
// These are small exact integers where the whole range is a dozen steps and
// every one is visible, so a 200px track would make single-pixel changes a
// game of aim. The row still shows the range so the ends aren't a surprise.

import QtQuick
import "../services"

Item {
    id: root

    property string label: ""
    property int value: 0
    property int minimum: 0
    property int maximum: 100
    property string suffix: ""
    // shown in place of value + suffix, for a stepper whose integer is a
    // count of steps (0.1s of sensitivity) rather than the setting itself
    property string displayValue: ""
    // left offset for the label, to line up under an icon column (a
    // FlyoutAction's labels start 28px in)
    property int labelInset: 0
    // the value cell is fixed-width so the buttons don't shuffle; widen it
    // for values with more digits than the appearance metrics have
    property int valueWidth: 34
    // a ring of named choices (a style) rather than a number: the buttons
    // are ‹ › and never go inert, stepping past either end wrapping round
    property bool wrap: false
    readonly property int scaledValueWidth: Math.max(Theme.fs(valueWidth), Theme.fit(valueWidth))

    signal stepped(int delta)

    width: parent ? parent.width : 0
    implicitHeight: Theme.rowHeight

    Text {
        anchors.left: parent.left
        anchors.leftMargin: root.labelInset
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.text
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontBody
    }

    // one control: a frame holding the minus, the value and the plus, the
    // buttons bare inside it and filled on hover
    Rectangle {
        id: controls
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: inner.width + inset * 2
        height: Theme.controlSize
        readonly property int inset: Theme.frameChannel ? Theme.channelWidth
            : Theme.frameDouble ? Theme.frameInset + Theme.borderWidth : Theme.borderWidth
        readonly property color edge: minus.hovered || plus.hovered ? Theme.strokeHover : Theme.stroke
        radius: Theme.radiusInner
        color: Theme.fieldFill
        border.width: Theme.controlBorder(edge)
        border.color: Theme.controlStroke(edge)

        ControlEdge { stroke: controls.edge; sunken: true; radius: controls.radius }

        component Button: Rectangle {
            id: btn
            property string glyph: ""
            // at an end of the range the button is inert rather than hidden,
            // so the row doesn't reflow every time you reach a limit
            property bool live: true
            readonly property bool hovered: ma.containsMouse
            signal pressed()

            width: Theme.controlSize
            height: controls.height - controls.inset * 2
            radius: Math.max(0, controls.radius - controls.inset)
            color: btn.live && ma.containsMouse ? Theme.hoverFill : "transparent"

            Text {
                anchors.centerIn: parent
                text: btn.glyph
                color: btn.live ? (ma.containsMouse ? Theme.textStrong : Theme.text) : Theme.textDisabled
                font.family: root.wrap ? Theme.fontIcon : Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: btn.live
                enabled: btn.live
                cursorShape: Qt.PointingHandCursor
                onClicked: btn.pressed()
            }
        }

        Row {
            id: inner
            x: controls.inset
            anchors.verticalCenter: parent.verticalCenter

            Button {
                id: minus
                glyph: root.wrap ? "󰅁" : "−"
                live: root.wrap || root.value > root.minimum
                onPressed: root.stepped(-1)
            }

            // Fixed width, wide enough for the longest value the range can
            // produce: letting it hug the text would shuffle both buttons
            // sideways every time the number gained or lost a digit.
            Item {
                width: root.scaledValueWidth
                height: minus.height

                Text {
                    anchors.centerIn: parent
                    text: root.displayValue !== "" ? root.displayValue : root.value + root.suffix
                    color: Theme.textStrong
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }
            }

            Button {
                id: plus
                glyph: root.wrap ? "󰅂" : "+"
                live: root.wrap || root.value < root.maximum
                onPressed: root.stepped(1)
            }
        }
    }
}
