// Where a message is written: what's attached to it (a click takes one
// off), the slash commands matching a / typed at the start (the sidebar's
// own: /clear, /new, /model, /mode, /past, /compact; then the CLI's), the
// box (Enter sends, Shift+Enter is a new line, Ctrl+L or /clear starts
// over; ! runs a shell command) under a line saying what it's doing,
// then a line with 󰐕 for attaching, the model, reasoning and, on Code,
// the permission mode, and Send or Stop.

import QtQuick
import "../services"
import "../flyouts"

Column {
    id: root

    required property var session
    signal escapePressed()
    // Ctrl+L (or Ctrl+N, from AiSidebar), or /clear or /new sent on its own
    signal newConversation()
    // /past
    signal showPast()
    signal togglePast()
    property bool historyShown: false

    property bool attaching: false
    property bool choosingModel: false
    property bool choosingReasoning: false
    onSessionChanged: { choosingModel = false; choosingReasoning = false }

    function modelValues() { return Ai.modelChoicesFor(Ai.tab).map(c => c.value) }
    function focusInput() { input.forceActiveFocus() }
    // typing that started elsewhere in the sidebar lands here
    function typeInto(text) {
        input.forceActiveFocus()
        input.insert(input.cursorPosition, text)
    }

    // --- slash commands ------------------------------------------------------
    // The sidebar's own, run here; then the CLI's, sent on as a message.
    readonly property var ownCommands: [
        { name: "clear", hint: "Start a new conversation" },
        { name: "new", hint: "Start a new conversation" },
        { name: "model", hint: Ai.ollama(Ai.tab) ? Ai.ollamaModels.map(c => c.value).join(", ") : Ai.codex(Ai.tab) ? Ai.codexModels.map(c => c.value).concat(["default"]).join(", ")
            : "opus, sonnet, haiku or default", takes: true },
        { name: "mode", hint: "ask, edits, plan or auto", takes: true, tab: "code" },
        { name: "past", hint: "Earlier conversations" },
        { name: "compact", hint: "Summarise the conversation so far" }
    ].filter(c => !c.tab || c.tab === Ai.tab)
    readonly property var commands: ownCommands.concat(root.session.slashCommands
        .filter(n => !ownCommands.some(c => c.name === n))
        .map(n => ({ name: n, hint: "Claude Code" })))
    // what's typed after a lone /, while there's no space yet; null otherwise
    readonly property var query: {
        var m = input.text.match(/^\/(\S*)$/)
        return m ? m[1].toLowerCase() : null
    }
    readonly property var matches: query === null ? []
        : commands.filter(c => c.name.toLowerCase().indexOf(query) === 0).slice(0, 8)
    readonly property var shellQuery: {
        var m = input.text.match(/^!([^\n]*)$/)
        return m ? m[1].replace(/^\s+/, "").toLowerCase() : null
    }
    readonly property var commonShellCommands: ["git status", "git diff", "git log --oneline -10",
        "ls", "pwd", "rg ", "find ", "cat ", "npm test", "python3 "]
    readonly property var shellMatches: shellQuery === null ? [] : Ai.commandHistory.concat(commonShellCommands)
        .filter((c, i, all) => all.indexOf(c) === i && c.toLowerCase().indexOf(shellQuery) === 0
            && c.toLowerCase() !== shellQuery)
        .slice(0, 8).map(c => ({ name: c, hint: Ai.commandHistory.indexOf(c) !== -1 ? "Recent" : "Suggested" }))
    readonly property var suggestions: shellQuery !== null ? shellMatches : matches
    property int pick: 0
    property bool suggestionsDismissed: false
    onQueryChanged: { pick = 0; suggestionsDismissed = false }
    onShellQueryChanged: { pick = 0; suggestionsDismissed = false }

    function chooseShell(c) {
        input.text = "!" + c.name
        input.cursorPosition = input.text.length
        suggestionsDismissed = true
    }

    // the picked command into the box: run at once when it needs nothing more
    function choose(c) {
        if (c.takes) {
            input.text = "/" + c.name + " "
            input.cursorPosition = input.text.length
        } else {
            input.text = "/" + c.name
            submit()
        }
    }

    readonly property var modelWords: ({ opus: "opus", sonnet: "sonnet", haiku: "haiku", default: "" })
    readonly property var modeWords: ({ ask: "default", edits: "acceptEdits", plan: "plan", auto: "auto" })

    function submit() {
        var t = input.text.trim()
        var m = t.match(/^\/(\S+)\s*(.*)$/)
        var cmd = m ? m[1].toLowerCase() : "", arg = m ? m[2].trim().toLowerCase() : ""
        if (cmd === "clear" || cmd === "new") {
            input.text = ""
            root.newConversation()
            return
        }
        if (cmd === "model") {
            // Claude's aliases, or one of Codex's by slug or name
            var pick = Ai.ollama(Ai.tab) ? Ai.ollamaModels.find(c => c.value.toLowerCase() === arg) : Ai.codex(Ai.tab)
                ? (arg === "default" ? { value: "" } : Ai.codexModels.find(c => c.value.toLowerCase() === arg || c.text.toLowerCase() === arg))
                : (arg in modelWords ? { value: modelWords[arg] } : null)
            if (pick) {
                input.text = ""
                Ai.setModel(Ai.modelKey(Ai.tab), pick.value)
                return
            }
        }
        if (cmd === "mode" && Ai.tab === "code" && arg in modeWords) {
            input.text = ""
            Ai.setCodeMode(modeWords[arg])
            return
        }
        if (cmd === "past") {
            input.text = ""
            root.showPast()
            return
        }
        if (Ai.send(input.text)) input.text = ""
    }

    width: parent ? parent.width : 0
    spacing: Theme.spaceM

    // what goes with the next message
    Flow {
        visible: root.session.attachments.length > 0
        width: parent.width
        spacing: Theme.spaceS

        Repeater {
            model: root.session.attachments

            Rectangle {
                id: att
                required property var modelData
                required property int index
                width: Math.min(parent.width, attachmentLabel.implicitWidth
                    + (preview.visible ? preview.width : attachmentGlyph.implicitWidth)
                    + attRow.spacing + Theme.spaceM * 2)
                height: Theme.fit(36)
                radius: Theme.radiusInner
                color: attMouse.containsMouse ? Theme.hoverFill : Theme.fieldFill
                border.width: Theme.controlBorder(attMouse.containsMouse ? Theme.strokeHover : Theme.stroke)
                border.color: Theme.controlStroke(attMouse.containsMouse ? Theme.strokeHover : Theme.stroke)

                Row {
                    id: attRow
                    x: Theme.spaceM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spaceM

                    Image {
                        id: preview
                        visible: att.modelData.kind === "image"
                        anchors.verticalCenter: parent.verticalCenter
                        height: att.height - Theme.spaceS * 2
                        width: visible ? Math.min(Theme.fit(56), implicitWidth * height / Math.max(1, implicitHeight)) : 0
                        fillMode: Image.PreserveAspectCrop
                        source: visible ? "file://" + att.modelData.path : ""
                        sourceSize.height: Theme.fit(64)
                        asynchronous: true
                    }
                    Text {
                        id: attachmentGlyph
                        visible: att.modelData.kind !== "image"
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅌"
                        color: Theme.subtext
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontIconSize
                    }
                    Text {
                        id: attachmentLabel
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, Math.min(implicitWidth, att.width - Theme.spaceM * 2
                            - x))
                        elide: Text.ElideMiddle
                        text: attMouse.containsMouse ? "Remove"
                            : att.modelData.label + (att.modelData.kind === "text"
                                ? "  " + att.modelData.text.split("\n").length
                                    + (att.modelData.text.split("\n").length === 1 ? " line" : " lines") : "")
                        color: attMouse.containsMouse ? Theme.textStrong : Theme.text
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontSmall
                    }
                }

                MouseArea {
                    id: attMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.session.unattach(att.index)
                }
            }
        }
    }

    // the slash commands matching what's typed: ↑↓ pick, Tab or Enter take
    Column {
        visible: !root.suggestionsDismissed && root.suggestions.length > 0
        width: parent.width

        Repeater {
            model: root.suggestions
            Rectangle {
                id: cmdRow
                required property var modelData
                required property int index
                readonly property bool lit: index === root.pick
                width: parent.width
                height: Theme.rowHeightDense
                radius: Theme.radiusInner
                color: lit || cmdMouse.containsMouse ? Theme.hoverFill : "transparent"

                Text {
                    id: cmdName
                    x: Theme.spaceM
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.shellQuery !== null ? "!" : "/") + cmdRow.modelData.name
                    width: Math.min(implicitWidth, parent.width * 0.7)
                    elide: Text.ElideRight
                    color: cmdRow.lit ? Theme.textStrong : Theme.text
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }
                Text {
                    anchors.left: cmdName.right
                    anchors.leftMargin: Theme.spaceM
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceM
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: cmdRow.modelData.hint
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontCaption
                }
                MouseArea {
                    id: cmdMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.shellQuery !== null) root.chooseShell(cmdRow.modelData)
                        else root.choose(cmdRow.modelData)
                        input.forceActiveFocus()
                    }
                }
            }
        }
    }

    // 󰐕's choices
    FlyoutChipLine {
        visible: root.attaching
        chips: [
            { icon: "󰩭", text: "Area", act: "area" },
            { icon: "󰖯", text: "Window", act: "window" },
            { icon: "󰍹", text: "Screen", act: "screen" },
            { icon: "󰅌", text: "Paste", act: "clipboard" },
            { icon: "󰆒", text: "Selected", act: "selection" }]
        onPicked: act => {
            root.attaching = false
            Ai.capture(act)
        }
    }

    ListView {
        visible: root.choosingModel
        width: parent.width
        height: visible ? Math.min(contentHeight, Theme.rowHeightDense * 5) : 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Ai.modelChoicesFor(Ai.tab)
        delegate: FlyoutRow {
            required property var modelData
            width: ListView.view.width - Theme.scrollGutter
            label: modelData.text
            highlighted: modelData.value === (Ai.models[Ai.modelKey(Ai.tab)] || "")
            onActivated: {
                Ai.setModel(Ai.modelKey(Ai.tab), modelData.value)
                root.choosingModel = false
                root.focusInput()
            }
        }
        ScrollBar { flickable: parent; anchors.right: parent.right }
    }

    ListView {
        visible: root.choosingReasoning
        width: parent.width
        height: visible ? Math.min(contentHeight, Theme.rowHeightDense * 5) : 0
        clip: true
        model: Ai.codex(Ai.tab) ? ["", "low", "medium", "high", "xhigh", "max", "ultra"] : ["", "low", "medium", "high", "xhigh", "max"]
        delegate: FlyoutRow {
            required property string modelData
            width: ListView.view.width - Theme.scrollGutter
            label: modelData === "" ? "Default" : modelData[0].toUpperCase() + modelData.slice(1)
            highlighted: modelData === (Ai.reasoning[Ai.modelKey(Ai.tab)] || "")
            onActivated: {
                Ai.setReasoning(Ai.modelKey(Ai.tab), modelData)
                root.choosingReasoning = false
                root.focusInput()
            }
        }
        ScrollBar { flickable: parent; anchors.right: parent.right }
    }

    // Status and conversation actions share the line above the input.
    Item {
        width: parent.width
        height: actions.height
        Text {
            anchors.left: parent.left
            anchors.right: actions.left
            anchors.rightMargin: Theme.spaceXs
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.session.asks.length > 0 ? "Waiting for you"
                : root.session.busy ? root.session.oneLine(root.session.activity) || "Working"
                : root.session.contextWindow > 0 && root.session.contextUsed >= root.session.contextWindow / 100
                    ? Math.round(root.session.contextUsed / root.session.contextWindow * 100) + "% of context"
                    : ""
            color: root.session.busy ? Theme.text : Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontCaption
            opacity: root.session.busy ? pulse.value : 1

            QtObject {
                id: pulse
                property real value: 1
            }
            SequentialAnimation {
                running: root.session.busy
                loops: Animation.Infinite
                onRunningChanged: if (!running) pulse.value = 1
                NumberAnimation { target: pulse; property: "value"; to: 0.45; duration: Theme.durPulse }
                NumberAnimation { target: pulse; property: "value"; to: 1; duration: Theme.durPulse }
            }
        }

        Row {
            id: actions
            anchors.right: parent.right
            spacing: Theme.spaceXs
            FlyoutChip {
                icon: "󰝒"
                text: "New"
                enabled: !root.session.empty || root.session.sessionId !== ""
                onClicked: root.newConversation()
            }
            FlyoutChip {
                icon: "󰋚"
                text: "History"
                selected: root.historyShown
                onClicked: root.togglePast()
            }
        }
    }

    // the box
    Rectangle {
        id: well
        readonly property color edge: input.activeFocus ? Theme.strokeFocus : Theme.stroke
        width: parent.width
        height: Math.min(Math.max(input.implicitHeight, Theme.fontBody * 1.4) + Theme.spaceM * 2,
                         Theme.fit(200))
        radius: Theme.radiusInner
        color: Theme.fieldFill
        border.width: Theme.controlBorder(edge)
        border.color: Theme.controlStroke(edge)

        ControlEdge { stroke: well.edge; sunken: true; radius: well.radius }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: input.forceActiveFocus()
        }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: Theme.spaceM
            anchors.leftMargin: Theme.spaceL
            contentWidth: width
            contentHeight: input.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            function ensureVisible(r) {
                if (contentY >= r.y) contentY = r.y
                else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height
            }

            TextEdit {
                id: input
                width: flick.width
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                color: Theme.textStrong
                selectionColor: Theme.selectedStroke
                selectedTextColor: Theme.hasAccent ? Theme.textOnAccent : Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
                enabled: Ai.available
                onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)

                Text {
                    visible: input.text === ""
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.session.busy ? "Working…"
                        : Ai.ollama(Ai.tab) ? "Ask Ollama…"
                        : Ai.tab === "code" ? (Ai.codex("code") ? "Ask Codex…" : "Ask Claude Code…")
                        : root.session.empty ? (Ai.codex("chat") ? "Ask Codex…" : "Ask Claude…") : "Reply…"
                    color: Theme.textDisabled
                    font: input.font
                }

                Keys.onEscapePressed: {
                    if (!root.suggestionsDismissed && root.suggestions.length > 0) root.suggestionsDismissed = true
                    else root.escapePressed()
                }
                Keys.onPressed: event => {
                    var list = root.choosingModel ? root.modelValues() : []
                    if (list.length > 0) {
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                            var at = Math.max(0, list.indexOf(Ai.models[Ai.modelKey(Ai.tab)] || ""))
                            Ai.setModel(Ai.modelKey(Ai.tab), list[(at + (event.key === Qt.Key_Down ? 1 : list.length - 1)) % list.length])
                            event.accepted = true
                            return
                        }
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                            root.choosingModel = false
                            event.accepted = true
                            return
                        }
                    }
                    if (!root.suggestionsDismissed && root.suggestions.length > 0) {
                        var n = root.suggestions.length
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                            root.pick = (root.pick + (event.key === Qt.Key_Down ? 1 : n - 1)) % n
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Tab || (root.shellQuery === null && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                && !(event.modifiers & Qt.ShiftModifier))) {
                            event.accepted = true
                            if (root.shellQuery !== null) root.chooseShell(root.suggestions[Math.min(root.pick, n - 1)])
                            else root.choose(root.suggestions[Math.min(root.pick, n - 1)])
                            return
                        }
                    }
                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_L) {
                        event.accepted = true
                        root.newConversation()
                        return
                    }
                    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) return
                    if (event.modifiers & Qt.ShiftModifier) return
                    event.accepted = true
                    root.submit()
                }
            }
        }

        ScrollBar { flickable: flick; anchors.right: parent.right; anchors.rightMargin: 2 }
    }

    // attach, model, reasoning, mode, send or stop
    Item {
        width: parent.width
        height: Math.max(Theme.controlSize, composerControls.implicitHeight)

        Flow {
            id: composerControls
            width: Math.max(0, parent.width - send.width - Theme.spaceM)
            spacing: Theme.spaceS
            anchors.verticalCenter: parent.verticalCenter

            IconButton {
                icon: "󰐕"
                lit: root.attaching
                enabled: Ai.available
                onClicked: root.attaching = !root.attaching
            }
            FlyoutChip {
                width: Math.min(implicitWidth, composerControls.width)
                text: Ai.modelText(Ai.tab) + (root.choosingModel ? " ▴" : " ▾")
                onClicked: { if (Ai.ollama(Ai.tab)) Ai.refreshOllama(); root.choosingModel = !root.choosingModel; root.choosingReasoning = false }
            }
            FlyoutChip {
                visible: !Ai.ollama(Ai.tab)
                text: "Reasoning: " + (Ai.reasoning[Ai.modelKey(Ai.tab)] || "Default") + " ▾"
                enabled: !root.session.busy
                onClicked: { root.choosingReasoning = !root.choosingReasoning; root.choosingModel = false }
            }
            FlyoutChip {
                visible: Ai.tab === "code"
                text: Ai.label(Ai.modeChoices, Ai.codeMode)
                selected: Ai.codeMode !== "default"
                onClicked: Ai.cycleMode()
            }
        }

        IconButton {
            id: send
            anchors.right: parent.right
            anchors.top: parent.top
            icon: root.session.busy ? "󰓛" : "󰒊"
            lit: !root.session.busy && (input.text.trim() !== "" || root.session.attachments.length > 0)
            enabled: Ai.available
            onClicked: root.session.busy ? root.session.stop() : root.submit()
        }
    }
}
