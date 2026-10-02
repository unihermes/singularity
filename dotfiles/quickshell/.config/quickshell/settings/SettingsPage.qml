// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPage.qml
//
// The frame every Settings page shares: a heading with its rule running
// out beside it, one line saying what the page changes and where it lands,
// and a scrolling column for the page's own rows. What a change did comes
// back as a toast over the bottom of the page: a success fades on its own,
// an error stays until clicked or replaced.
//
// Pages are created by the window's Loader when shown and destroyed when
// left, so a page reads its backing store fresh in Component.onCompleted and
// never has to reconcile with state from an earlier visit.
//
// `highlight` is set by the window when a search result lands here: the page
// scrolls the field with that label into view and rings it for a moment.
//
// A long page can be split into `tabs`: a row of them under the
// description, and the page's content in Columns marked isSettingsTab, each
// showing while `tab` is its own. The window remembers each page's tab
// while it's open, and a search result in a hidden tab switches to it.
//
// `sectioned` is the redesigned layout, page by page (DESIGN.md): with
// channel frames each group of rows sits in a channel of its own, the tabs
// are one segmented strip in place of the heading, and hints keep to one
// line. `pinned` shows above the scrolling rows while `pinnedVisible`.

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
    // off where a window header already names the page (the Keybinds window)
    property bool headed: true
    // the label of the field a search result picked, "" for none; fields
    // find it by walking up to here, so they need this marker to stop on
    property string highlight: ""
    readonly property bool isSettingsPage: true
    property bool sectioned: false
    readonly property bool channelled: sectioned && Theme.frameChannel
    property Component pinned: null
    property bool pinnedVisible: true

    // [{ id, label, icon }] and the one showing; [] for an untabbed page
    property var tabs: []
    property string tab: tabs.length > 0 ? tabs[0].id : ""
    // the column whose headings pin to the top as it scrolls: a tabbed
    // page points it at the tab showing
    property Item stickyColumn: col

    function tabMemory() {
        for (var p = parent; p; p = p.parent)
            if (p.pageTabs !== undefined) return p
        return null
    }
    onTabChanged: {
        if (!tabsReady) return
        flick.contentY = 0
        var m = tabMemory()
        if (!m) return
        var t = {}
        for (var k in m.pageTabs) t[k] = m.pageTabs[k]
        t[title] = tab
        m.pageTabs = t
    }
    property bool tabsReady: false
    Component.onCompleted: {
        var m = tabMemory()
        if (m && m.pageTabs[title] !== undefined && tabs.some(t => t.id === m.pageTabs[title]))
            tab = m.pageTabs[title]
        tabsReady = true
    }

    default property alias content: col.data
    // height available to content below the header, for non-scrolling pages
    readonly property real bodyHeight: height - header.height - (headed ? Theme.spaceXl : 0)

    function say(msg, isError) {
        notice = msg
        noticeIsError = !!isError
        toast.show()
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
    // A field in a folded section unfolds it, and is scrolled to on the
    // next try, once it has been laid out again.
    function scrollTo(item, label) {
        for (var i = 0; i < item.children.length; i++) {
            var c = item.children[i]
            if (c.isSettingsField === true && c.searchable !== false && c.label === label) {
                for (var p = c.parent; p && p !== col; p = p.parent) {
                    // in a tab that isn't showing: show it, then try again
                    if (p.isSettingsTab === true && root.tab !== p.tabId) {
                        root.tab = p.tabId
                        return false
                    }
                    if (p.isFlyoutHeading === true) {
                        p.toggle()
                        return false
                    }
                }
                if (root.scrolls) {
                    var y = col.mapFromItem(c, 0, 0).y
                    var max = Math.max(0, flick.contentHeight - flick.height)
                    // clear of the section's heading, pinned at the top
                    flick.contentY = Math.max(0, Math.min(max, y - Theme.spaceXl - Theme.headingHeight))
                }
                return true
            }
            if (scrollTo(c, label)) return true
        }
        return false
    }

    Column {
        id: header
        visible: root.headed
        width: parent.width
        height: visible ? implicitHeight : 0
        spacing: Theme.spaceS

        FlyoutHeading {
            visible: !(root.sectioned && root.tabs.length > 0)
            text: root.title.toUpperCase()
        }

        Text {
            width: parent.width
            visible: text !== "" && !(root.sectioned && root.tabs.length > 0)
            text: root.description
            wrapMode: Text.WordWrap
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }

        // the tabs: icon and name, the one showing lit and underlined
        // sectioned: the tabs as one segmented strip, the one showing filled
        Rectangle {
            id: tabStrip
            visible: root.tabs.length > 0 && root.sectioned
            width: parent.width
            height: Theme.rowHeightTall + Theme.spaceS
            radius: Theme.radiusInner
            color: Theme.controlFill("transparent")
            border.width: Theme.controlBorder(Theme.stroke)
            border.color: Theme.controlStroke(Theme.stroke)

            ControlEdge { sunken: true; radius: tabStrip.radius }

            Row {
                x: Theme.borderWidth
                y: Theme.borderWidth
                height: parent.height - Theme.borderWidth * 2

                Repeater {
                    id: tabRep
                    model: root.tabs

                    Item {
                        id: seg
                        required property var modelData
                        required property int index
                        readonly property bool current: root.tab === modelData.id
                        width: (tabStrip.width - Theme.borderWidth * 2) / tabRep.count
                        height: parent.height

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: Theme.radiusSmall
                            color: seg.current ? (Theme.frameChannel ? Theme.accent : Theme.selectedFill)
                                : segMouse.containsMouse ? Theme.hoverFillSoft : "transparent"
                            border.width: !seg.current ? 0 : Theme.frameChannel ? Theme.channelGrooveWidth : Theme.borderWidth
                            border.color: Theme.frameChannel ? Theme.channelGroove : Theme.selectedStroke
                        }

                        Rectangle {
                            visible: seg.index > 0
                            width: Theme.borderWidth
                            height: parent.height - Theme.spaceS * 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.stroke
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spaceS
                            Text {
                                id: segIcon
                                anchors.verticalCenter: parent.verticalCenter
                                text: seg.modelData.icon || ""
                                visible: text !== ""
                                color: seg.current && Theme.frameChannel ? "#ffffff"
                                    : seg.current ? Theme.accent : Theme.subtext
                                font.family: Theme.fontIcon
                                font.pixelSize: Theme.fontIconSize
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, seg.width - segIcon.width - Theme.spaceS * 3)
                                elide: Text.ElideRight
                                text: seg.modelData.label
                                color: seg.current && Theme.frameChannel ? "#ffffff"
                                    : seg.current || segMouse.containsMouse ? Theme.textStrong : Theme.text
                                font.family: Theme.fontText
                                font.pixelSize: Theme.fontSmall
                                font.weight: seg.current ? Theme.weightStrong : Theme.weightBody
                            }
                        }

                        MouseArea {
                            id: segMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tab = seg.modelData.id
                        }
                    }
                }
            }
        }

        Loader {
            width: parent.width
            active: root.pinned !== null && root.pinnedVisible
            visible: active
            sourceComponent: root.pinned
        }

        Flow {
            width: parent.width
            visible: root.tabs.length > 0 && !root.sectioned
            topPadding: Theme.spaceS
            spacing: Theme.spaceXs

            Repeater {
                model: root.tabs

                Rectangle {
                    id: tabChip
                    required property var modelData
                    readonly property bool current: root.tab === modelData.id
                    width: tabRow.implicitWidth + Theme.spaceL * 2
                    height: Theme.rowHeightTall
                    radius: Theme.radiusInner
                    color: current ? Theme.selectedFill : tabMouse.containsMouse ? Theme.overlay : "transparent"
                    border.width: current ? Theme.borderWidth : 0
                    border.color: Theme.selectedStroke

                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: Theme.spaceS
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tabChip.modelData.icon || ""
                            visible: text !== ""
                            color: tabChip.current ? Theme.accent : Theme.subtext
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontIconSize
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tabChip.modelData.label
                            color: tabChip.current ? Theme.textStrong : Theme.text
                            font.family: Theme.fontText
                            font.pixelSize: Theme.fontBody
                            font.weight: tabChip.current ? Theme.weightStrong : Theme.weightBody
                        }
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tab = tabChip.modelData.id
                    }
                }
            }
        }
    }

    Item {
        anchors.top: header.bottom
        anchors.topMargin: root.headed ? Theme.spaceXl : 0
        anchors.bottom: parent.bottom
        width: parent.width

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.rightMargin: root.scrolls ? Theme.scrollGutter : 0
            contentHeight: col.implicitHeight
            interactive: root.scrolls && contentHeight > height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            SectionRuns {
                visible: root.channelled
                x: Theme.spaceS
                width: flick.width - Theme.spaceS * 2
                column: root.stickyColumn
                columnY: col.y + (root.stickyColumn === col ? 0 : root.stickyColumn.y)
            }

            Column {
                id: col
                // sectioned: inset to clear the sections' frames
                readonly property int inset: root.channelled ? Theme.channelWidth + Theme.spaceL : 0
                readonly property bool sectioned: root.channelled
                x: Theme.spaceS + inset
                width: flick.width - x * 2
                spacing: Theme.spaceM
                topPadding: root.channelled ? Theme.channelWidth + Theme.spaceS : 0
                // clear of the panel's rounded bottom border, as on System
                bottomPadding: Theme.spaceXl
            }
        }

        // scroll indicator, as in the Keybinds list
        StickyHeading {
            width: flick.width
            flickable: flick
            column: root.stickyColumn
        }

        ScrollBar {
            anchors.right: parent.right
            flickable: flick
            visible: root.scrolls && overflow > 0
        }
    }

    // the page's last result
    Rectangle {
        id: toast

        property bool shown: false

        function show() {
            shown = root.notice !== ""
            if (shown && !root.noticeIsError) toastTimer.restart()
            else toastTimer.stop()
        }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: shown ? Theme.spaceL : 0
        width: Math.min(toastRow.implicitWidth + Theme.spaceXl * 2, parent.width - Theme.spaceXl * 2)
        height: toastRow.implicitHeight + Theme.spaceL * 2
        radius: Theme.radiusInner
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: root.noticeIsError ? Theme.alert : Theme.strokeHover
        opacity: shown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: Theme.dur(180); easing.type: Theme.ease } }
        Behavior on anchors.bottomMargin { NumberAnimation { duration: Theme.dur(180); easing.type: Theme.ease } }

        Timer {
            id: toastTimer
            interval: 4000
            onTriggered: toast.shown = false
        }

        Row {
            id: toastRow
            x: Theme.spaceXl
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceM

            Text {
                id: toastIcon
                text: root.noticeIsError ? "󰀦" : "󰄬"
                color: root.noticeIsError ? Theme.alert : Theme.good
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize
            }

            Text {
                width: Math.min(implicitWidth, toast.parent.width - Theme.spaceXl * 4 - toastIcon.width - toastRow.spacing)
                anchors.verticalCenter: parent.verticalCenter
                text: root.notice
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toast.shown = false
        }
    }
}
