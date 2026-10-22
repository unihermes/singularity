// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutChipLine.qml
//
// Chips sharing one line in equal widths: a flyout's tools, its windows,
// its way out. Each entry is { icon, text, act }; a click emits picked(act).
// Alone in a section of a sectioned flyout it is a region instead: the
// section's frame hugs it (SectionRuns) and its parts fill the frame,
// split by the frame's line.

import QtQuick
import "../services"

Item {
    id: root

    property var chips: []
    signal picked(string act)

    // directly in a sectioned column, with only breaks (or nothing) shown
    // either side of it
    readonly property bool isChipRegion: {
        var col = parent
        if (!Theme.sectionFramed || !col || col.sectioned !== true) return false
        var kids = col.children, at = -1
        for (var i = 0; i < kids.length; i++) if (kids[i] === root) at = i
        function alone(from, step) {
            for (var j = from; j >= 0 && j < kids.length; j += step) {
                var c = kids[j]
                if (!c.visible || c.height <= 0) continue
                return c.isFlyoutHeading === true || c.isSectionBreak === true
                    || (/^QQuickItem\(/.test(String(c)) && c.children.length === 0)
            }
            return true
        }
        return at >= 0 && alone(at - 1, -1) && alone(at + 1, 1)
    }

    width: parent ? parent.width : 0
    implicitHeight: Theme.chipHeight

    Row {
        visible: !root.isChipRegion
        anchors.fill: parent
        spacing: Theme.spaceS

        Repeater {
            model: root.isChipRegion ? [] : root.chips

            FlyoutChip {
                required property var modelData
                width: (root.width - parent.spacing * (root.chips.length - 1)) / root.chips.length
                icon: modelData.icon
                text: modelData.text
                onClicked: root.picked(modelData.act)
            }
        }
    }

    // out to the frame's inner line: FlyoutPanel's column sits channelWidth
    // + spaceM in from the frame's edge
    Item {
        id: region
        visible: root.isChipRegion
        readonly property real bleed: Theme.channelWidth + Theme.spaceM - Theme.sectionDepth
        readonly property real corner: Math.max(0, Theme.sectionRadius - Theme.sectionDepth)
        x: -bleed
        width: root.width + bleed * 2
        height: root.height

        Repeater {
            model: root.isChipRegion ? root.chips : []

            Item {
                id: part
                required property var modelData
                required property int index
                readonly property bool first: index === 0
                readonly property bool last: index === root.chips.length - 1
                x: index * width
                width: region.width / root.chips.length
                height: region.height

                Rectangle {
                    anchors.fill: parent
                    visible: partMouse.containsMouse
                    color: Theme.hoverFill
                    topLeftRadius: part.first ? region.corner : 0
                    bottomLeftRadius: part.first ? region.corner : 0
                    topRightRadius: part.last ? region.corner : 0
                    bottomRightRadius: part.last ? region.corner : 0
                }

                Rectangle {
                    visible: !part.first
                    width: Theme.borderWidth
                    height: parent.height
                    color: Theme.sectionLine
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spaceS

                    Text {
                        visible: part.modelData.icon !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: part.modelData.icon
                        color: partLabel.color
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontBody
                        font.weight: Theme.weightBody
                    }
                    Text {
                        id: partLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: part.modelData.text
                        color: partMouse.containsMouse ? Theme.textStrong : Theme.text
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontBody
                    }
                }

                MouseArea {
                    id: partMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(part.modelData.act)
                }
            }
        }
    }
}
