// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPage.qml
//
// The frame every Settings page shares: a heading with its rule running
// out beside it, one line saying what the page changes and where it lands,
// a status line, and a scrolling column for the page's own rows.
//
// Pages are created by the window's Loader when shown and destroyed when
// left, so a page reads its backing store fresh in Component.onCompleted and
// never has to reconcile with state from an earlier visit.
//
// `highlight` is set by the window when a search result lands here: the page
// scrolls the field with that label into view and rings it for a moment.

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
    // the label of the field a search result picked, "" for none; fields
    // find it by walking up to here, so they need this marker to stop on
    property string highlight: ""
    readonly property bool isSettingsPage: true

    default property alias content: col.data
    // height available to content below the header, for non-scrolling pages
    readonly property real bodyHeight: height - header.height - Theme.sp(10)

    function say(msg, isError) {
        notice = msg
        noticeIsError = !!isError
    }

    // The field isn't there yet on the frame the page loads -- Repeaters and
    // the pages' own parsing fill the column later -- so the scroll is tried
    // again a few times before giving up.
    onHighlightChanged: if (highlight !== "") {
        findTries = 0
        find.restart()
        fade.restart()
    }

    property int findTries: 0

    Timer {
        id: find
        interval: 60
        repeat: true
        onTriggered: {
            if (root.highlight === "" || root.scrollTo(col, root.highlight) || ++root.findTries > 12)
                stop()
        }
    }

    // Keeps `item` at the same place on screen through a change that
    // re-lays out the page above it: Font Size and Density rescale every
    // row, so the control you just clicked moved out from under the pointer
    // and the next click missed it. Called before the change; the page
    // then scrolls by however far the item moved. Text re-measures over a
    // frame or two, so it's corrected a few times rather than once.
    property Item holdItem: null
    property real holdY: 0
    property int holdTries: 0

    function holdInPlace(item) {
        if (!scrolls || !item) return
        holdItem = item
        holdY = item.mapToItem(root, 0, 0).y
        holdTries = 0
        hold.restart()
    }

    Timer {
        id: hold
        interval: 16
        repeat: true
        onTriggered: {
            if (!root.holdItem || ++root.holdTries > 8) {
                stop()
                root.holdItem = null
                return
            }
            var dy = root.holdItem.mapToItem(root, 0, 0).y - root.holdY
            if (Math.abs(dy) < 1) return
            var max = Math.max(0, flick.contentHeight - flick.height)
            flick.contentY = Math.max(0, Math.min(max, flick.contentY + dy))
        }
    }

    // the ring is a hint, not a state: it clears itself
    Timer {
        id: fade
        interval: 4000
        onTriggered: root.highlight = ""
    }

    // Depth-first, because a field can sit inside a page's own Column (the
    // per-monitor blocks on Display) rather than directly in the scroller.
    function scrollTo(item, label) {
        for (var i = 0; i < item.children.length; i++) {
            var c = item.children[i]
            if (c.isSettingsField === true && c.label === label) {
                if (root.scrolls) {
                    var y = col.mapFromItem(c, 0, 0).y
                    var max = Math.max(0, flick.contentHeight - flick.height)
                    flick.contentY = Math.max(0, Math.min(max, y - Theme.spaceXl))
                }
                return true
            }
            if (scrollTo(c, label)) return true
        }
        return false
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
