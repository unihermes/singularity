// Singularity - Quickshell
// ~/.config/quickshell/sidebar/NotificationSidebar.qml
//
// The notification history (services/Notifications.qml) as a panel down
// the right edge of one screen, under the bar, as the Claude sidebar is:
// out until the bell, its ×, Escape or a click off it (DismissGrab, the bars
// excepted) puts it away, or a notification is opened from it. Newest first under a heading per day, each a few lines
// (NotificationCard, collapsed) that a click opens in place. Clear all on
// the heading, then Do Not Disturb and Settings at the foot. Empty, it
// says so in a card. Coming out marks everything read; what was new stays
// marked while it's out.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"
import "../flyouts"

PanelWindow {
    id: root

    readonly property bool open: Notifications.shown
    function requestClose() { Notifications.shown = false }

    // every screen's bar: a press there doesn't put it away
    property var bars: []
    DismissGrab { panel: root; also: root.bars }

    // the key of the entry opened in place, "" for none
    property string expanded: ""

    screen: Notifications.screen
    anchors { top: true; bottom: true; right: true }
    margins { top: Theme.edgeMargin; bottom: Theme.edgeMargin; right: Theme.edgeMargin }
    implicitWidth: Theme.fit(400) + (padX - Theme.panelPad) * 2
    // kept clear of the bar's strip, without pushing windows aside
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "singularity-sidebar"

    // 0 in, 1 out; slides in from the edge
    property real reveal: 0
    visible: open || reveal > 0
    NumberAnimation on reveal {
        id: slide
        running: false
        duration: Theme.durMedium
        easing.type: Theme.ease
    }
    onOpenChanged: {
        Notifications.setViewing(open)
        if (open) {
            expanded = ""
            list.positionViewAtBeginning()
        }
        slide.stop()
        if (Theme.animFactor <= 0) { reveal = open ? 1 : 0; return }
        slide.to = open ? 1 : 0
        slide.start()
    }
    Component.onCompleted: if (open) {
        reveal = 1
        Notifications.setViewing(true)
    }

    readonly property int sectionGap: Theme.sectionInset - Theme.channelWidth
    readonly property int padX: Theme.channelWidth * 2 + sectionGap + Theme.spaceM
    readonly property int padY: Theme.channelWidth * 2 + sectionGap + Theme.spaceXs

    // Today, Yesterday, else the weekday and date
    function dayOf(t) {
        const d = new Date(t)
        const today = new Date(Notifications.now)
        today.setHours(0, 0, 0, 0)
        const diff = Math.round((today - new Date(d.getFullYear(), d.getMonth(), d.getDate())) / 86400000)
        return diff <= 0 ? "Today" : diff === 1 ? "Yesterday" : Qt.formatDate(d, "dddd d MMM")
    }

    PanelFrame {
        id: box
        width: parent.width
        height: parent.height
        ground: Theme.surface
        opacity: Theme.flyoutAnim === "none" ? 1 : root.reveal
        transform: Translate { x: (1 - root.reveal) * Theme.sp(24) }

        focus: true
        Keys.onEscapePressed: Notifications.shown = false

        Absorber {}

        SectionRuns {
            x: Theme.channelWidth + root.sectionGap
            width: box.width - x * 2
            height: box.height
            column: col
            columnY: col.y
            padY: Theme.spaceXs
        }

        Column {
            id: col
            x: root.padX
            y: root.padY
            width: parent.width - root.padX * 2
            height: parent.height - root.padY * 2
            spacing: Theme.flyoutSpacing
            readonly property bool sectioned: true
            readonly property bool isFlyoutPage: true

            // everything but the list, which takes what's left
            readonly property real fixedHeight: {
                var h = 0, n = 0
                for (var i = 0; i < children.length; i++) {
                    var c = children[i]
                    if (c === middle || !c.visible) continue
                    h += c.height
                    n++
                }
                return h + spacing * n
            }

            FlyoutHeading {
                text: "NOTIFICATIONS" + (Notifications.count > 0 ? "  " + Notifications.count : "")
                control: headControls
            }

            Component {
                id: headControls
                Row {
                    spacing: Theme.spaceXs
                    FlyoutChip {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Notifications.count > 0
                        text: "Clear all"
                        confirmText: "Clear " + Notifications.count + "?"
                        onClicked: Notifications.clearAll()
                    }
                    IconButton {
                        icon: "󰅖"
                        onClicked: Notifications.shown = false
                    }
                }
            }

            Item {
                id: middle
                width: parent.width
                height: Math.max(Theme.rowHeight * 4, col.height - col.fixedHeight)

                HeadCard {
                    visible: Notifications.count === 0
                    width: parent.width
                    glyph: "󰄬"
                    glyphColor: Theme.good
                    title: "All caught up"
                    lines: ["The history is empty"]
                }

                ListView {
                    id: list
                    anchors.fill: parent
                    visible: Notifications.count > 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: Theme.spaceXs
                    model: Notifications.history

                    delegate: Column {
                        id: line
                        required property var modelData
                        required property int index
                        readonly property string day: root.dayOf(modelData.time)
                        readonly property bool firstOfDay: index === 0
                            || root.dayOf(Notifications.history[index - 1].time) !== day
                        width: list.width - Theme.scrollGutter

                        Text {
                            visible: line.firstOfDay
                            width: parent.width
                            topPadding: line.index === 0 ? 0 : Theme.spaceM
                            bottomPadding: Theme.spaceXs
                            text: Theme.heading(line.day)
                            color: Theme.subtext
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontCaption
                            font.letterSpacing: Theme.headingSpacing
                        }

                        NotificationCard {
                            width: parent.width
                            entry: line.modelData
                            framed: false
                            inHistory: true
                            bodyLines: 10
                            collapsed: root.expanded !== line.modelData.key
                            onToggled: root.expanded = collapsed ? line.modelData.key : ""
                        }
                    }
                }

                ScrollBar {
                    anchors.right: parent.right
                    flickable: list
                }
            }

            FlyoutDivider {}

            FlyoutAction {
                icon: Notifications.dnd ? "󰂛" : "󰂚"
                label: "Do Not Disturb"
                status: Notifications.dnd ? "Popups are held" : ""
                checked: Notifications.dnd
                onActivated: Notifications.toggleDnd()
            }

            FlyoutDivider {}

            FlyoutChipLine {
                chips: [{ icon: "󰒓", text: "Settings", act: "settings" }]
                onPicked: {
                    Notifications.shown = false
                    Notifications.settingsRequested()
                }
            }
        }
    }
}
