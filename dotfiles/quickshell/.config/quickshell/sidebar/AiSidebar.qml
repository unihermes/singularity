// Singularity - Quickshell
// ~/.config/quickshell/sidebar/AiSidebar.qml
//
// The Claude sidebar (services/Ai.qml): a panel down the right edge of one
// screen, under the bar, out until SUPER+I or its × puts it away (a click
// elsewhere doesn't). The plans' limits under the heading (AiUsage), then
// Chat, Desktop and Code as tabs over one shape: the tab's own line (Code's
// folder, Desktop's changes), the conversation or a list in its place (past
// sessions, folders, the diff), a prompt waiting for an answer, and the
// composer.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"
import "../flyouts"

PanelWindow {
    id: root

    readonly property bool open: Ai.shown && !Ai.capturing
    readonly property var session: Ai.current

    // what the middle shows: talk | past | projects | diff
    property string view: "talk"
    onViewChanged: {
        if (view === "past") Ai.listPast()
        else if (view === "projects") Ai.listProjects()
    }
    Connections {
        target: Ai
        function onTabChanged() { root.view = "talk" }
        function onHasChangesChanged() { if (!Ai.hasChanges && root.view === "diff") root.view = "talk" }
    }

    screen: Ai.screen
    anchors { top: true; bottom: true; right: true }
    margins { top: Theme.edgeMargin; bottom: Theme.edgeMargin; right: Theme.edgeMargin }
    implicitWidth: Theme.fit(440) + (padX - Theme.panelPad) * 2
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
        duration: Theme.dur(180)
        easing.type: Theme.ease
    }
    onOpenChanged: {
        slide.stop()
        if (Theme.animFactor <= 0) { reveal = open ? 1 : 0; return }
        slide.to = open ? 1 : 0
        slide.start()
        if (open) Qt.callLater(composer.focusInput)
    }
    Component.onCompleted: if (open) { reveal = 1; Qt.callLater(composer.focusInput) }

    readonly property int sectionGap: Theme.sectionInset - Theme.channelWidth
    readonly property int padX: Theme.channelWidth * 2 + sectionGap + Theme.spaceM
    readonly property int padY: Theme.channelWidth * 2 + sectionGap + Theme.spaceXs

    // a fresh conversation on this tab; the old one stays under 󰋚
    function startOver() {
        session.reset()
        view = "talk"
        composer.focusInput()
    }

    function ago(t) {
        var s = Math.max(0, Date.now() / 1000 - t)
        return s < 3600 ? Math.max(1, Math.round(s / 60)) + "m"
            : s < 86400 ? Math.round(s / 3600) + "h"
            : Math.round(s / 86400) + "d"
    }

    PanelFrame {
        id: box
        width: parent.width
        height: parent.height
        ground: Theme.surface
        opacity: Theme.flyoutAnim === "none" ? 1 : root.reveal
        transform: Translate { x: (1 - root.reveal) * Theme.sp(24) }

        // Escape from anywhere that doesn't take it itself
        focus: true
        Keys.onEscapePressed: Ai.shown = false

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

            // everything but the middle, which takes what's left
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
                text: "CLAUDE"
                control: headControls
            }

            // the plans' limits, then a break before the tabs
            AiUsage {
                id: usage
                visible: Ai.fiveHour >= 0 || Ai.sevenDay >= 0 || Ai.codexUsage !== null
            }
            FlyoutDivider { visible: usage.visible }

            Component {
                id: headControls
                Row {
                    spacing: Theme.spaceXs
                    IconButton {
                        icon: "󰋚"
                        visible: Ai.tab !== "desktop"
                        lit: root.view === "past"
                        onClicked: root.view = root.view === "past" ? "talk" : "past"
                    }
                    FlyoutChip {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.session.empty || root.session.sessionId !== ""
                        icon: "󰝒"
                        text: Ai.tab === "chat" ? "New chat" : "New"
                        onClicked: root.startOver()
                    }
                    IconButton {
                        icon: "󰅖"
                        onClicked: Ai.shown = false
                    }
                }
            }

            FlyoutSegmented {
                model: [
                    { value: "chat", text: "Chat" + (Ai.chat.unseen && Ai.tab !== "chat" ? " ●" : "") },
                    { value: "desktop", text: "Desktop" + (Ai.desktop.unseen && Ai.tab !== "desktop" ? " ●" : "") },
                    { value: "code", text: "Code" + (Ai.code.unseen && Ai.tab !== "code" ? " ●" : "") }]
                current: Ai.tab
                onPicked: v => Ai.setTab(v)
            }

            // Code: the folder it works in; a click picks another
            FlyoutRow {
                visible: Ai.tab === "code"
                leadingIcon: "󰉋"
                label: Ai.codeDir.split("/").pop() || "/"
                note: Ai.codeDir.indexOf(Ai.home) === 0 ? "~" + Ai.codeDir.slice(Ai.home.length) : Ai.codeDir
                trailing: root.view === "projects" ? "󰅀" : "󰅂"
                onActivated: root.view = root.view === "projects" ? "talk" : "projects"
            }

            // Desktop: what's waiting to be applied
            FlyoutRow {
                visible: Ai.tab === "desktop" && Ai.hasChanges
                leadingIcon: "󰦒"
                label: Ai.files.length + (Ai.files.length === 1 ? " file changed" : " files changed")
                note: "+" + Ai.files.reduce((n, f) => n + f.added, 0)
                    + " −" + Ai.files.reduce((n, f) => n + f.removed, 0)
                trailing: root.view === "diff" ? "󰅀" : "󰅂"
                onActivated: root.view = root.view === "diff" ? "talk" : "diff"
            }

            Row {
                visible: Ai.tab === "desktop" && Ai.hasChanges
                spacing: Theme.spaceM

                FlyoutChip {
                    icon: "󰄬"
                    text: Ai.applying ? "Applying…" : "Apply"
                    enabled: !Ai.desktop.busy && !Ai.applying
                    onClicked: Ai.apply()
                }
                FlyoutChip {
                    icon: "󰅖"
                    text: "Discard"
                    confirmText: "Discard all?"
                    onClicked: Ai.discard()
                }
            }

            FlyoutDivider {}

            Item {
                id: middle
                width: parent.width
                height: Math.max(Theme.rowHeight * 4, col.height - col.fixedHeight)

                AiTranscript {
                    anchors.fill: parent
                    visible: root.view === "talk"
                    session: root.session
                    available: Ai.available
                    tab: Ai.tab
                }

                // this tab's earlier conversations
                ListView {
                    id: pastList
                    anchors.fill: parent
                    visible: root.view === "past"
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: Ai.past
                    header: FlyoutRow {
                        width: pastList.width
                        visible: Ai.past.length === 0
                        height: visible ? implicitHeight : 0
                        label: Ai.pastLoading ? "Looking…" : "No earlier conversations here"
                        enabled: false
                    }
                    delegate: FlyoutRow {
                        required property var modelData
                        width: pastList.width - Theme.scrollGutter
                        label: modelData.title || "Untitled"
                        note: modelData.turns + (modelData.turns === 1 ? " message" : " messages")
                        trailing: root.ago(modelData.mtime)
                        trailingIsValue: true
                        highlighted: modelData.id === root.session.sessionId
                        onActivated: { Ai.resume(modelData.id); root.view = "talk" }
                    }
                    ScrollBar { flickable: pastList; anchors.right: parent.right }
                }

                // Code: the folders it's been used in, or one typed in
                Column {
                    anchors.fill: parent
                    visible: root.view === "projects"
                    spacing: Theme.flyoutSpacing

                    FlyoutInput {
                        id: dirInput
                        bleed: true
                        echoPassword: false
                        glyph: "󰉋"
                        placeholder: "A folder, like ~/Git/app"
                        onAccepted: {
                            Ai.setCodeDir(text.trim())
                            text = ""
                            root.view = "talk"
                        }
                        onEscapePressed: root.view = "talk"
                    }

                    ListView {
                        id: projList
                        width: parent.width
                        height: parent.height - dirInput.height - parent.spacing
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: Ai.projects
                        delegate: FlyoutRow {
                            required property var modelData
                            width: projList.width - Theme.scrollGutter
                            leadingIcon: "󰉋"
                            label: modelData.name
                            note: modelData.path.indexOf(Ai.home) === 0 ? "~" + modelData.path.slice(Ai.home.length) : modelData.path
                            highlighted: modelData.path === Ai.codeDir
                            onActivated: { Ai.setCodeDir(modelData.path); root.view = "talk" }
                        }
                        ScrollBar { flickable: projList; anchors.right: parent.right }
                    }
                }

                // Desktop: the staged diff
                AiDiff {
                    anchors.fill: parent
                    visible: root.view === "diff"
                    diff: visible ? Ai.diff : ""
                }
            }

            FlyoutDivider {
                visible: root.session.asks.length > 0
            }

            // the first prompt waiting on an answer
            AiAsk {
                visible: root.session.asks.length > 0
                ask: root.session.asks.length > 0 ? root.session.asks[0] : null
                session: root.session
            }

            FlyoutDivider {}

            AiComposer {
                id: composer
                session: root.session
                onEscapePressed: Ai.shown = false
                onNewConversation: root.startOver()
            }
        }
    }

    // looking at a tab is reading it
    Connections {
        target: root.session
        function onUnseenChanged() { if (root.open && root.session.unseen) root.session.unseen = false }
    }
}
