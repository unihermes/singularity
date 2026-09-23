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

import QtQuick
import "../../services"
import "../../flyouts"

Item {
    id: root

    property string title: ""
    property string subtitle: ""

    default property alias content: col.data
    // the column's own width, for content that has to size cells by hand
    readonly property real contentWidth: flick.width - Theme.spaceS * 2

    Column {
        id: header
        width: parent.width
        spacing: Theme.spaceS

        FlyoutHeading { text: root.title.toUpperCase() }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.subtitle
            wrapMode: Text.WordWrap
            color: Theme.subtext
            font.family: Theme.fontText
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
            anchors.rightMargin: Theme.sp(10)
            contentHeight: col.implicitHeight
            interactive: contentHeight > height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: col
                x: Theme.spaceS
                width: flick.width - Theme.spaceS * 2
                spacing: Theme.spaceM
                // the last row of a full page would otherwise sit hard
                // against the window's rounded bottom border
                bottomPadding: Theme.spaceXl
            }
        }

        ScrollBar {
            anchors.right: parent.right
            flickable: flick
        }
    }
}
