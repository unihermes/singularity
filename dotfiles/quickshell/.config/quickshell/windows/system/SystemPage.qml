// Singularity - Quickshell
// ~/.config/quickshell/windows/system/SystemPage.qml
//
// The frame every System page shares: a one-line subtitle and a scrolling
// column, sectioned like a Settings page. Built fresh each visit; no status
// line, as these pages only read.

import QtQuick
import "../../services"
import "../../flyouts"

Item {
    id: root

    property string subtitle: ""

    default property alias content: col.data
    // the column's own width, for content that has to size cells by hand
    readonly property real contentWidth: col.width

    Column {
        id: header
        width: parent.width
        spacing: Theme.spaceS

        Text {
            width: parent.width
            visible: text !== ""
            text: root.subtitle
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    Item {
        anchors.top: header.bottom
        anchors.topMargin: Theme.spaceXl
        anchors.bottom: parent.bottom
        width: parent.width

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.rightMargin: Theme.scrollGutter
            contentHeight: col.implicitHeight
            interactive: contentHeight > height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            SectionRuns {
                x: Theme.spaceS
                width: flick.width - Theme.spaceS * 2
                column: col
                columnY: col.y
            }

            Column {
                id: col
                // sectioned: inset to clear the sections' frames
                readonly property int inset: Theme.channelWidth + Theme.spaceL
                readonly property bool sectioned: true
                x: Theme.spaceS + inset
                width: flick.width - x * 2
                spacing: Theme.spaceM
                topPadding: Theme.channelWidth + Theme.spaceS
                // the last row of a full page would otherwise sit hard
                // against the window's rounded bottom border
                bottomPadding: Theme.spaceXl
            }
        }

        StickyHeading {
            width: flick.width
            flickable: flick
            column: col
        }

        ScrollBar {
            anchors.right: parent.right
            flickable: flick
        }
    }
}
