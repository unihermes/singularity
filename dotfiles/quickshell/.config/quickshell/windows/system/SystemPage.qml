// Singularity - Quickshell
// ~/.config/quickshell/windows/system/SystemPage.qml
//
// The frame every System page shares: a heading, one line saying what the
// page is about, and a scrolling column for the page's own content. The
// same shape as SettingsPage.qml, without the status line -- these pages
// read rather than write, so there is nothing to report back.
//
// Pages are created by the window's Loader when shown and destroyed when
// left, so anything a page probes for itself runs on arrival and stops on
// the way out. Nothing here keeps state between visits.
//
// Laid out as a sectioned Settings page is (DESIGN.md): with channel
// frames each run of rows between headings sits in a channel of its own,
// and the subtitle keeps to one line.

import QtQuick
import "../../services"
import "../../flyouts"

Item {
    id: root

    property string title: ""
    property string subtitle: ""

    default property alias content: col.data
    // the column's own width, for content that has to size cells by hand
    readonly property real contentWidth: col.width

    Column {
        id: header
        width: parent.width
        spacing: Theme.spaceS

        FlyoutHeading { text: root.title.toUpperCase() }

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
