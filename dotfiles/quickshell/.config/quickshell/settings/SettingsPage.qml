// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPage.qml
//
// The frame every Settings page shares: a heading, one line saying what the
// page changes and where it lands, a status line, and a scrolling column for
// the page's own rows.
//
// Pages are created by the window's Loader when shown and destroyed when
// left, so a page reads its backing store fresh in Component.onCompleted and
// never has to reconcile with state from an earlier visit.

import QtQuick
import "../services"
import "../flyouts"

Item {
    id: root

    property string title: ""
    property string description: ""
    // the page's last result: "Saved", a Hyprland complaint, a missing tool
    property string notice: ""
    property bool noticeIsError: false
    // off for a page that manages its own scrolling (Keybinds)
    property bool scrolls: true

    default property alias content: col.data
    // height available to content below the header, for non-scrolling pages
    readonly property real bodyHeight: height - header.height - Theme.sp(10)

    function say(msg, isError) {
        notice = msg
        noticeIsError = !!isError
    }

    Column {
        id: header
        width: parent.width
        spacing: Theme.spaceS

        FlyoutHeading { text: root.title.toUpperCase() }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.description
            wrapMode: Text.WordWrap
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }

        Text {
            width: parent.width
            height: Theme.headingHeight
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: root.notice
            color: root.noticeIsError ? Theme.alert : Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
    }

    Item {
        anchors.top: header.bottom
        anchors.topMargin: Theme.sp(10)
        anchors.bottom: parent.bottom
        width: parent.width

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.rightMargin: root.scrolls ? Theme.sp(10) : 0
            contentHeight: col.implicitHeight
            interactive: root.scrolls && contentHeight > height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: col
                x: Theme.spaceS
                width: flick.width - Theme.spaceS * 2

                spacing: Theme.spaceM
            }
        }

        // scroll indicator, as in the Keybinds list
        ScrollBar {
            anchors.right: parent.right
            flickable: flick
            visible: root.scrolls && overflow > 0
        }
    }
}
