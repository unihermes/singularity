// Singularity - Quickshell
// ~/.config/quickshell/sidebar/AiComposer.qml
//
// Where a message is written: what's attached to it (a click takes one
// off), the slash commands matching a / typed at the start (the sidebar's
// own: /clear, /new, /model, /mode, /past, /compact; then the CLI's), the
// box (Enter sends, Shift+Enter is a new line, Ctrl+L or /clear starts
// over), then a line with
// 󰐕 for attaching, Claude or Codex (Chat and Code), the model and, on
// Code, the permission mode (each a click to the next), what it's doing,
// and Send or Stop.

import QtQuick
import "../services"
import "../flyouts"

Column {
    id: root

    required property var session
    signal escapePressed()
    // Ctrl+L or Ctrl+N, or /clear or /new sent on its own
    signal newConversation()
    // /past
    signal showPast()

    property bool attaching: false

    function focusInput() { input.forceActiveFocus() }

    // --- slash commands ------------------------------------------------------
    // The sidebar's own, run here; then the CLI's, sent on as a message.
    readonly property var ownCommands: [
        { name: "clear", hint: "Start a new conversation" },
        { name: "new", hint: "Start a new conversation" },
        { name: "model", hint: Ai.codex(Ai.tab) ? Ai.codexModels.map(c => c.value).concat(["default"]).join(", ")
            : "opus, sonnet, haiku or default", takes: true },
        { name: "mode", hint: "ask, edits, plan or auto", takes: true, tab: "code" },
        { name: "past", hint: "Earlier conversations", notTab: "desktop" },
        { name: "compact", hint: "Summarise the conversation so far" }
    ].filter(c => (!c.tab || c.tab === Ai.tab) && c.notTab !== Ai.tab)
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
    property int pick: 0
    onQueryChanged: pick = 0

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
            var pick = Ai.codex(Ai.tab)
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
        if (cmd === "past" && Ai.tab !== "desktop") {
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
                width: attRow.implicitWidth + Theme.spaceM * 2
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
                        visible: att.modelData.kind !== "image"
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅌"
                        color: Theme.subtext
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontIconSize
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
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
        visible: root.matches.length > 0
        width: parent.width

        Repeater {
            model: root.matches
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
                    text: "/" + cmdRow.modelData.name
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
                        root.choose(cmdRow.modelData)
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
                        : Ai.tab === "desktop" ? "Ask for a change to the desktop…"
                        : Ai.tab === "code" ? (Ai.codex("code") ? "Ask Codex…" : "Ask Claude Code…")
                        : root.session.empty ? (Ai.codex("chat") ? "Ask Codex…" : "Ask Claude…") : "Reply…"
                    color: Theme.textDisabled
                    font: input.font
                }

                Keys.onEscapePressed: {
                    if (root.matches.length > 0) input.text = ""
                    else root.escapePressed()
                }
                Keys.onPressed: event => {
                    if (root.matches.length > 0) {
                        var n = root.matches.length
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                            root.pick = (root.pick + (event.key === Qt.Key_Down ? 1 : n - 1)) % n
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Tab || ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                && !(event.modifiers & Qt.ShiftModifier))) {
                            event.accepted = true
                            root.choose(root.matches[Math.min(root.pick, n - 1)])
                            return
                        }
                    }
                    if ((event.modifiers & Qt.ControlModifier)
                            && (event.key === Qt.Key_L || event.key === Qt.Key_N)) {
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

    // attach, model, mode, what it's doing, send or stop
    Item {
        width: parent.width
        height: Theme.controlSize

        Row {
            id: left
            spacing: Theme.spaceS
            anchors.verticalCenter: parent.verticalCenter

            IconButton {
                icon: "󰐕"
                lit: root.attaching
                enabled: Ai.available
                onClicked: root.attaching = !root.attaching
            }
            // Claude or Codex, on Chat and Code
            FlyoutChip {
                visible: Ai.tab !== "desktop" && Ai.codexAvailable
                text: Ai.codex(Ai.tab) ? "Codex" : "Claude"
                enabled: !root.session.busy
                onClicked: Ai.setEngine(Ai.tab, Ai.codex(Ai.tab) ? "claude" : "codex")
            }
            FlyoutChip {
                text: Ai.modelText(Ai.tab)
                onClicked: Ai.cycleModel()
            }
            FlyoutChip {
                visible: Ai.tab === "code"
                text: Ai.label(Ai.modeChoices, Ai.codeMode)
                selected: Ai.codeMode !== "default"
                onClicked: Ai.cycleMode()
            }
        }

        Text {
            anchors.left: left.right
            anchors.leftMargin: Theme.spaceM
            anchors.right: send.left
            anchors.rightMargin: Theme.spaceM
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: root.session.asks.length > 0 ? "Waiting for you"
                : root.session.busy ? root.session.activity || "Working"
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

        IconButton {
            id: send
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: root.session.busy ? "󰓛" : "󰒊"
            lit: !root.session.busy && (input.text.trim() !== "" || root.session.attachments.length > 0)
            enabled: Ai.available
            onClicked: root.session.busy ? root.session.stop() : root.submit()
        }
    }
}
