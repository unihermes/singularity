// Singularity - Quickshell
// ~/.config/quickshell/sidebar/AiSidebar.qml
//
// The Claude sidebar (services/Ai.qml): a panel down the right edge of one
// screen, under the bar. Pinning keeps it open when clicking elsewhere;
// SUPER+I, its × and Escape still close it. Ctrl+P toggles the pin, Ctrl+R
// reloads, Ctrl+N starts over, Ctrl+H toggles history and Ctrl+M switches provider.
// Chat and Code are tabs over one shape: Code's folder, the
// conversation or a list in its place (past sessions, folders), a prompt
// waiting for an answer, and the composer. Files dropped anywhere on it attach to the next message.

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../services"
import "../flyouts"

PanelWindow {
    id: root

    readonly property bool open: Ai.shown && !Ai.capturing
    readonly property var session: Ai.current
    // The keyboard comes on opening and on a press inside, never on hover:
    // exclusively until it arrives (on demand alone waits for the pointer to
    // move), then on demand. A press elsewhere closes the panel, or with the
    // pin up hands the keys back. input.lua's click event reports it without
    // taking it from what was clicked, on any screen and over the scratchpad.
    property bool holdsKeys: false
    property bool takingKeys: false
    property bool pointerInside: false
    function takeKeys() {
        holdsKeys = true
        takingKeys = true
        takeTimer.restart()
        composer.focusInput()
    }
    // Hyprland leaves the keys on a layer when the window clicked is the one
    // it already counts as active, so ask for that window again.
    function giveKeysBack() {
        if (!holdsKeys) return
        holdsKeys = false
        takingKeys = false
        Hyprland.dispatch("(function() local w = hl.get_active_window(); local hid = false; "
            + "if w then for _, t in ipairs(type(w.tags) == \"table\" and w.tags or { w.tags }) do "
            + "if tostring(t):match(\"^minimized_\") then hid = true end end end; "
            + "return (w and not hid) and hl.dsp.focus({ window = \"address:\" .. w.address }) or hl.dsp.no_op() end)()")
    }
    Timer { id: takeTimer; interval: 150; onTriggered: root.takingKeys = false }
    // the hover state and Hyprland's own focus change settle first
    Timer {
        id: afterClick
        interval: 60
        onTriggered: {
            if (!root.open) return
            if (root.pointerInside) root.takeKeys()
            else if (Ai.pinned) root.giveKeysBack()
            else Ai.dismiss()
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "custom" && event.data === "singularity-click") afterClick.restart()
            // a special workspace coming or going focuses its window: the keys stay put until a click
            else if (event.name === "activespecial" && root.open && root.holdsKeys) root.takeKeys()
        }
    }

    // what the middle shows: talk | past | projects
    property string view: "talk"
    onViewChanged: {
        if (view === "past") Ai.listPast()
        else if (view === "projects") Ai.listProjects()
    }
    Connections {
        target: Ai
        function onTabChanged() { root.view = "talk" }
    }

    screen: Ai.screen
    anchors { top: true; bottom: true; right: true }
    margins { top: Theme.edgeMargin; bottom: Theme.edgeMargin; right: Theme.edgeMargin }
    implicitWidth: Theme.fit(440) + (padX - Theme.panelPad) * 2
    // kept clear of the bar's strip, without pushing windows aside
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: !holdsKeys ? WlrKeyboardFocus.None
        : takingKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
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
        if (open) Qt.callLater(takeKeys)
        else giveKeysBack()
        slide.stop()
        if (Theme.animFactor <= 0) { reveal = open ? 1 : 0; return }
        slide.to = open ? 1 : 0
        slide.start()
    }
    Component.onCompleted: if (open) { reveal = 1; Qt.callLater(takeKeys) }

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

        HoverHandler { onHoveredChanged: root.pointerInside = hovered }

        // Escape from anywhere that doesn't take it itself
        focus: true
        Keys.onEscapePressed: Ai.shown = false

        // Ctrl+P pins or unpins, Ctrl+R reloads the sidebar (as its Reload chip)
        Shortcut {
            sequence: "Ctrl+P"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: Ai.pinned = !Ai.pinned
        }
        Shortcut {
            sequence: "Ctrl+R"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: Ai.reloadSidebar()
        }
        // Ctrl+N starts a new conversation, Ctrl+H toggles the history list
        Shortcut {
            sequence: "Ctrl+N"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: root.startOver()
        }
        Shortcut {
            sequence: "Ctrl+H"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: root.view = root.view === "past" ? "talk" : "past"
        }
        Shortcut {
            sequence: "Ctrl+M"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: Ai.cycleEngine(Ai.tab)
        }

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
                text: Ai.ollama(Ai.tab) ? "OLLAMA" : Ai.codex(Ai.tab) ? "CODEX" : "CLAUDE"
                icon: Ai.ollama(Ai.tab)
                    ? Qt.resolvedUrl("icons/ollama.svg")
                    : Ai.codex(Ai.tab)
                        ? Qt.resolvedUrl("icons/codex.svg")
                        : Qt.resolvedUrl("icons/claude.svg")
                control: headControls
                labelClickable: Ai.codexAvailable && !root.session.busy
                onLabelClicked: Ai.cycleEngine(Ai.tab)
            }

            Component {
                id: headControls
                Row {
                    spacing: Theme.spaceXs
                    FlyoutChip {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "󰑓"
                        text: "Reload"
                        enabled: !Ai.busy && !Ai.asking
                        onClicked: Ai.reloadSidebar()
                    }
                    FlyoutChip {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "󰐃"
                        text: Ai.pinned ? "Pinned" : "Pin"
                        selected: Ai.pinned
                        onClicked: Ai.pinned = !Ai.pinned
                    }
                    IconButton {
                        icon: "󰅖"
                        onClicked: Ai.shown = false
                    }
                }
            }

            FlyoutSegmented {
                model: [
                    { value: "chat", text: "Chat" + ((Ai.chat.unseen || Ai.chatCodex.unseen || Ai.chatOllama.unseen) && Ai.tab !== "chat" ? " ●" : "") },
                    { value: "code", text: "Code" + ((Ai.code.unseen || Ai.codeCodex.unseen || Ai.codeOllama.unseen) && Ai.tab !== "code" ? " ●" : "") }]
                current: Ai.tab
                onPicked: v => Ai.setTab(v)
            }

            AiUsage {
                visible: hasReading
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
                historyShown: root.view === "past"
                onEscapePressed: Ai.shown = false
                onNewConversation: root.startOver()
                onShowPast: root.view = "past"
                onTogglePast: root.view = root.view === "past" ? "talk" : "past"
            }
        }
    }

    // files dragged in (a file manager's) attach to this tab's next message
    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: drop => {
            if (drop.hasUrls) Ai.attachFiles(drop.urls)
            drop.accept()
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.channelWidth
            visible: drop.containsDrag
            radius: Theme.panelFrameRadius
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.85)
            border.width: Theme.borderWidth * 2
            border.color: Theme.accent

            Text {
                anchors.centerIn: parent
                text: "󰁦  Drop to attach"
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontTitle
            }
        }
    }

    // looking at a tab is reading it
    Connections {
        target: root.session
        function onUnseenChanged() { if (root.open && root.session.unseen) root.session.unseen = false }
    }
}
