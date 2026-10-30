// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPage.qml
//
// The frame every Settings page shares: heading, a one-line description,
// a scrolling column, and toasts (success fades, errors stay). Pages are
// built fresh each visit. `highlight` scrolls to and rings a searched field;
// `tabs` splits the page into isSettingsTab Columns (remembered while the
// window is open); `sectioned` frames each group of rows (DESIGN.md);
// `pinned` sits above the rows while `pinnedVisible`; `footer` floats over
// the foot of the rows while `footerVisible`.

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
    // the page's name as its first heading; off where the window's title
    // bar already names it (Settings › Page)
    property bool titled: true
    // the label of the field a search result picked, "" for none; fields
    // find it by walking up to here, so they need this marker to stop on
    property string highlight: ""
    readonly property bool isSettingsPage: true
    property bool sectioned: false
    property Component pinned: null
    property bool pinnedVisible: true
    property Component footer: null
    property bool footerVisible: true
    readonly property real footerHeight: footerLoader.visible ? footerLoader.height + Theme.spaceL : 0

    // [{ id, label, icon }] and the one showing; [] for an untabbed page
    property var tabs: []
    property string tab: tabs.length > 0 ? tabs[0].id : ""
    // the column whose headings pin to the top as it scrolls: a tabbed
    // page points it at the tab showing
    property Item stickyColumn: col
    // where stickyColumn sits in col: a tab, or a tab inside a Loader
    readonly property point stickyAt: stickyColumn === col ? Qt.point(0, 0)
        : stickyColumn.parent === col ? Qt.point(stickyColumn.x, stickyColumn.y)
        : Qt.point(stickyColumn.x + stickyColumn.parent.x, stickyColumn.y + stickyColumn.parent.y)

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
    // height available to content below the header, for non-scrolling
    // pages: clear of the section's frame above and below when sectioned
    readonly property real bodyHeight: height - header.height - (headed ? Theme.spaceXl : 0)
        - (sectioned ? (Theme.channelWidth + Theme.spaceS) * 2 : 0)

    function say(msg, isError) {
        notice = msg
        noticeIsError = !!isError
        toast.show()
    }

    // retried a few times: the field may not be laid out yet
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

    // keeps `item` at the same place on screen through a re-layout (Font
    // Size, Density), corrected over a few frames as text re-measures
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

    // depth-first (fields can sit in a page's own Column); a field in a
    // folded section unfolds it and is scrolled to on the next try
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

    // sectioned: lined up with the section frames below, clear of the
    // scroll bar's gutter
    Column {
        id: header
        visible: root.headed
        x: root.sectioned && root.scrolls ? Theme.spaceS : 0
        width: parent.width - (root.sectioned && root.scrolls ? Theme.spaceS * 2 + Theme.scrollGutter : 0)
        height: visible ? implicitHeight : 0
        spacing: Theme.spaceS

        FlyoutHeading {
            visible: root.titled && !(root.sectioned && root.tabs.length > 0)
            text: root.title.toUpperCase()
        }

        Text {
            width: parent.width
            visible: text !== "" && !(root.sectioned && root.tabs.length > 0)
            text: root.description
            wrapMode: root.sectioned ? Text.NoWrap : Text.WordWrap
            elide: root.sectioned ? Text.ElideRight : Text.ElideNone
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
            // as round as the sections, the lit tab one step in, so their
            // corners nest
            radius: Theme.sectionRadius
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
                            radius: Math.max(0, Theme.sectionRadius - 3)
                            color: seg.current ? Theme.accent
                                : segMouse.containsMouse ? Theme.hoverFillSoft : "transparent"
                            border.width: seg.current && Theme.frameChannel ? Theme.channelGrooveWidth : 0
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
                                color: seg.current ? Theme.textOnAccent : Theme.subtext
                                font.family: Theme.fontIcon
                                font.pixelSize: Theme.fontIconSize
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, seg.width - segIcon.width - Theme.spaceS * 3)
                                elide: Text.ElideRight
                                text: seg.modelData.label
                                color: seg.current ? Theme.textOnAccent
                                    : segMouse.containsMouse ? Theme.textStrong : Theme.text
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
            // the rows end above the footer rather than under it
            anchors.bottomMargin: root.footerHeight
            anchors.rightMargin: root.scrolls ? Theme.scrollGutter : 0
            contentHeight: col.implicitHeight
            interactive: root.scrolls && contentHeight > height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            SectionRuns {
                visible: root.sectioned
                x: Theme.spaceS
                width: flick.width - Theme.spaceS * 2
                column: root.stickyColumn
                columnY: col.y + root.stickyAt.y
            }

            Column {
                id: col
                // sectioned: inset to clear the sections' frames
                readonly property int inset: root.sectioned ? Theme.channelWidth + Theme.spaceL : 0
                readonly property bool sectioned: root.sectioned
                x: Theme.spaceS + inset
                width: flick.width - x * 2
                spacing: Theme.spaceM
                topPadding: root.sectioned ? Theme.channelWidth + Theme.spaceS : 0
                // clear of the panel's rounded bottom border, as on System
                bottomPadding: Theme.spaceXl
            }
        }

        Loader {
            id: footerLoader
            anchors.bottom: parent.bottom
            x: Theme.spaceS
            width: flick.width - Theme.spaceS * 2
            active: root.footer !== null && root.footerVisible
            visible: active
            sourceComponent: root.footer
        }

        // scroll indicator, as in the Keybinds list
        StickyHeading {
            width: flick.width
            flickable: flick
            column: root.stickyColumn
            columnX: col.x + root.stickyAt.x
            columnY: root.stickyAt.y
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
        anchors.bottomMargin: (shown ? Theme.spaceL : 0) + root.footerHeight
        width: Math.min(toastRow.implicitWidth + Theme.spaceXl * 2, parent.width - Theme.spaceXl * 2)
        height: toastRow.implicitHeight + Theme.spaceL * 2
        radius: Theme.radiusInner
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: root.noticeIsError ? Theme.alert : Theme.strokeHover
        opacity: shown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease } }
        Behavior on anchors.bottomMargin { NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease } }

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
