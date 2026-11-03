// Singularity - Quickshell
// ~/.config/quickshell/sidebar/AiTranscript.qml
//
// A conversation's rows (ClaudeSession.entries): what you sent in a field
// with its attachments under it, Claude's replies as markdown you can
// select (Markdown.js; fenced code in a box of its own with Copy, an
// artifact as a card that opens it in a window), each
// tool call as a line (a click opens what it did), errors and notes.
// Follows the end while it's in view; scrolling up stops that.

import Quickshell
import QtQuick
import "../services"
import "../services/Markdown.js" as Markdown
import "../flyouts"

Item {
    id: root

    required property var session
    property bool available: true
    property string tab: "chat"

    // a tool's input and output as styled text, a diff's lines coloured
    function styled(body, result) {
        var out = []
        String(body || "").split("\n").slice(0, 200).forEach(l => {
            var c = l[0] === "+" ? Theme.good : l[0] === "-" ? Theme.alert
                : l.indexOf("@@") === 0 ? Theme.subtext : Theme.text
            out.push("<font color='" + c + "'>" + (Markdown.esc(l) || "&nbsp;") + "</font>")
        })
        if (result) {
            if (out.length > 0) out.push("<font color='" + Theme.muted + "'>──</font>")
            String(result).split("\n").slice(0, 60).forEach(l => out.push(Markdown.esc(l) || "&nbsp;"))
        }
        return out.join("<br>")
    }

    readonly property string emptyText: !available ? "Claude Code isn't installed. Install it (the claude-code package) and sign in with `claude` once."
        : tab === "chat" ? (Ai.codex("chat") ? "Ask Codex anything" : "Ask anything") + ". Attach a screenshot, the clipboard or the selected text with 󰐕 below."
        : (Ai.codex("code") ? "Codex" : "Claude Code") + " in the folder above. It asks before it runs a command or edits a file, unless you change that under the box."

    Text {
        visible: root.session.empty
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.emptyText
        color: Theme.subtext
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontSmall
    }

    // the colours the markdown's rich text is drawn in
    readonly property var ink: ({
        text: String(Theme.text), strong: String(Theme.textStrong), muted: String(Theme.subtext),
        accent: String(Theme.accent), codeFill: String(Theme.overlay), codeInk: String(Theme.textStrong),
        rule: String(Theme.stroke)
    })

    // a reply's prose
    Component {
        id: textPart
        TextEdit {
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.RichText
            text: Markdown.html(parent.part.text, root.ink)
            color: Theme.text
            selectionColor: Theme.selectedStroke
            selectedTextColor: Theme.hasAccent ? Theme.textOnAccent : Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
            onLinkActivated: link => Qt.openUrlExternally(link)

            HoverHandler {
                cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
            }
        }
    }

    // a reply's fenced code: its language and Copy over it, in a box of its own
    Component {
        id: codePart
        Rectangle {
            id: block
            readonly property var part: parent.part
            property bool copied: false
            height: codeHead.height + codeText.implicitHeight + Theme.spaceS + Theme.spaceM
            radius: Theme.radiusInner
            color: Theme.base
            border.width: Theme.borderWidth
            border.color: Theme.stroke

            Item {
                id: codeHead
                width: parent.width
                height: Theme.rowHeightDense
                Text {
                    x: Theme.spaceM
                    anchors.verticalCenter: parent.verticalCenter
                    text: block.part.lang || "code"
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontCaption
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceM
                    anchors.verticalCenter: parent.verticalCenter
                    text: block.copied ? "󰄬 Copied" : "󰆏 Copy"
                    color: copyMouse.containsMouse ? Theme.textStrong : Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontCaption
                    MouseArea {
                        id: copyMouse
                        anchors.fill: parent
                        anchors.margins: -Theme.spaceS
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["wl-copy", "--", block.part.code])
                            block.copied = true
                            copiedTimer.restart()
                        }
                    }
                    Timer {
                        id: copiedTimer
                        interval: 1500
                        onTriggered: block.copied = false
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Theme.borderWidth
                    color: Theme.stroke
                }
            }

            TextEdit {
                id: codeText
                x: Theme.spaceM
                y: codeHead.height + Theme.spaceS
                width: parent.width - Theme.spaceM * 2
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.WrapAnywhere
                textFormat: TextEdit.PlainText
                text: block.part.code
                color: Theme.textStrong
                selectionColor: Theme.selectedStroke
                selectedTextColor: Theme.hasAccent ? Theme.textOnAccent : Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    // a reply's artifact: a card that opens it in a window (Ai.openArtifact),
    // in the browser, or copies its source; "Writing" until its fence closes
    Component {
        id: artifactPart
        Rectangle {
            id: card
            readonly property var part: parent.part
            readonly property var kinds: ({
                html: ["󰌝", "HTML"], react: ["󰜈", "React"], svg: ["󰜡", "SVG"],
                mermaid: ["󰙅", "Diagram"], markdown: ["󰍔", "Document"], md: ["󰍔", "Document"]
            })
            readonly property var kind: kinds[part.type] || ["󰈔", part.type]
            property bool copied: false
            height: Theme.spaceM * 2 + Theme.rowHeightDense * 2 + Theme.spaceS
            radius: Theme.radiusInner
            color: Theme.base
            border.width: Theme.borderWidth
            border.color: Theme.stroke

            Text {
                id: kindGlyph
                x: Theme.spaceM
                y: Theme.spaceM
                width: Theme.iconCell
                height: Theme.rowHeightDense
                verticalAlignment: Text.AlignVCenter
                text: card.kind[0]
                color: Theme.accent
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontBody
            }
            Text {
                anchors.left: kindGlyph.right
                anchors.leftMargin: Theme.spaceS
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceM
                y: Theme.spaceM
                height: Theme.rowHeightDense
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: card.part.title || "Artifact"
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }

            Text {
                x: Theme.spaceM
                y: Theme.spaceM + Theme.rowHeightDense + Theme.spaceS
                height: Theme.rowHeightDense
                verticalAlignment: Text.AlignVCenter
                text: card.part.done ? card.kind[1] : card.kind[1] + " · Writing…"
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontCaption
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceM
                y: Theme.spaceM + Theme.rowHeightDense + Theme.spaceS
                height: Theme.rowHeightDense
                spacing: Theme.spaceL
                visible: card.part.done

                Repeater {
                    model: [
                        { label: "󰏌 Open", act: "open" },
                        { label: "󰖟 Browser", act: "browser" },
                        { label: card.copied ? "󰄬 Copied" : "󰆏 Copy", act: "copy" }
                    ]
                    Text {
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: actMouse.containsMouse ? Theme.textStrong : Theme.subtext
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontCaption
                        MouseArea {
                            id: actMouse
                            anchors.fill: parent
                            anchors.margins: -Theme.spaceS
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (parent.modelData.act === "copy") {
                                    Quickshell.execDetached(["wl-copy", "--", card.part.code])
                                    card.copied = true
                                    artifactCopied.restart()
                                } else Ai.openArtifact(card.part, parent.modelData.act === "browser")
                            }
                        }
                    }
                }
            }
            Timer {
                id: artifactCopied
                interval: 1500
                onTriggered: card.copied = false
            }
        }
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.session.entries

        property bool follow: true
        onMovementEnded: follow = atYEnd
        onCountChanged: if (follow) Qt.callLater(positionViewAtEnd)
        onContentHeightChanged: if (follow && !moving) Qt.callLater(positionViewAtEnd)
        // a fresh conversation starts at the end again
        Connections {
            target: root.session
            function onSessionIdChanged() { list.follow = true }
        }

        delegate: Item {
            id: entry
            required property int index
            required property string kind
            required property string text
            required property string note
            required property string images
            required property string name
            required property string detail
            required property string body
            required property string result
            required property string phase
            required property bool streaming
            required property bool open

            // a run of tool calls sits close together; anything else gets room
            readonly property real gap: index === 0 ? 0
                : kind === "tool" && (root.session.entries.get(index - 1) || {}).kind === "tool" ? Theme.spaceXs : Theme.spaceL

            width: list.width - Theme.scrollGutter
            height: loader.height + gap

            Loader {
                id: loader
                y: entry.gap
                width: parent.width
                sourceComponent: entry.kind === "user" ? userRow
                    : entry.kind === "reasoning" ? reasoningRow
                    : entry.kind === "assistant" ? replyRow
                    : entry.kind === "tool" ? toolRow
                    : noteRow
            }

            Component {
                id: userRow
                Rectangle {
                    width: loader.width
                    height: userCol.implicitHeight + Theme.spaceM * 2
                    radius: Theme.radiusInner
                    color: Theme.fieldFill
                    border.width: Theme.controlBorder(Theme.stroke)
                    border.color: Theme.controlStroke(Theme.stroke)

                    Column {
                        id: userCol
                        x: Theme.spaceL
                        y: Theme.spaceM
                        width: parent.width - Theme.spaceL * 2
                        spacing: Theme.spaceS

                        Text {
                            text: "YOU"
                            color: Theme.subtext
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontCaption
                        }

                        TextEdit {
                            visible: entry.text !== ""
                            width: parent.width
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            text: entry.text
                            color: Theme.textStrong
                            selectionColor: Theme.selectedStroke
                            selectedTextColor: Theme.hasAccent ? Theme.textOnAccent : Theme.textStrong
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontBody
                        }

                        Row {
                            visible: entry.images !== ""
                            spacing: Theme.spaceS
                            Repeater {
                                model: entry.images === "" ? [] : entry.images.split("\n")
                                Image {
                                    required property string modelData
                                    height: Theme.fit(56)
                                    width: Math.min(Theme.fit(120), implicitWidth * height / Math.max(1, implicitHeight))
                                    fillMode: Image.PreserveAspectCrop
                                    source: "file://" + modelData
                                    asynchronous: true
                                    sourceSize.height: Theme.fit(112)
                                }
                            }
                        }

                        Text {
                            visible: entry.note !== ""
                            width: parent.width
                            elide: Text.ElideRight
                            text: "󰁦 " + entry.note
                            color: Theme.subtext
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontCaption
                        }
                    }
                }
            }

            Component {
                id: reasoningRow
                Column {
                    width: loader.width
                    spacing: Theme.spaceS

                    Text {
                        text: "THINKING"
                        color: Theme.subtext
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontCaption
                    }

                    Item {
                        width: parent.width
                        height: reasoningText.implicitHeight

                        Rectangle {
                            width: Theme.borderWidth
                            height: parent.height
                            color: Theme.muted
                        }
                        TextEdit {
                            id: reasoningText
                            x: Theme.spaceL
                            width: parent.width - x
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.PlainText
                            text: entry.text
                            color: Theme.text
                            opacity: 0.75
                            selectionColor: Theme.selectedStroke
                            selectedTextColor: Theme.hasAccent ? Theme.textOnAccent : Theme.textStrong
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontSmall
                        }
                    }
                }
            }

            Component {
                id: replyRow
                Column {
                    width: loader.width
                    spacing: Theme.spaceS

                    Text {
                        text: "REPLY"
                        color: Theme.accent
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontCaption
                    }

                    Item {
                        width: parent.width
                        height: replyContent.implicitHeight

                        Rectangle {
                            width: Theme.borderWidth
                            height: parent.height
                            color: Theme.accent
                        }
                        Column {
                            id: replyContent
                            x: Theme.spaceL
                            width: parent.width - x
                            spacing: Theme.spaceM
                            Repeater {
                                model: Markdown.split(entry.text)
                                Loader {
                                    required property var modelData
                                    width: parent.width
                                    sourceComponent: modelData.kind === "code" ? codePart
                                        : modelData.kind === "artifact" ? artifactPart : textPart
                                    property var part: modelData
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: toolRow
                Column {
                    width: loader.width
                    spacing: Theme.spaceXs

                    Item {
                        width: parent.width
                        height: Theme.rowHeightDense

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: -Theme.spaceS
                            radius: Theme.radiusInner
                            color: toolMouse.containsMouse ? Theme.hoverFill : "transparent"
                        }

                        Text {
                            id: stateGlyph
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.iconCell
                            text: entry.phase === "running" ? spinner.frames[spinner.frame]
                                : entry.phase === "error" ? "󰅖"
                                : entry.phase === "stopped" ? "󰓛"
                                : entry.name === "TodoWrite" ? "󰄵" : "󰄬"
                            color: entry.phase === "error" ? Theme.alert
                                : entry.phase === "running" ? Theme.accent : Theme.muted
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontSmall
                        }

                        Text {
                            anchors.left: stateGlyph.right
                            anchors.right: chev.left
                            anchors.rightMargin: Theme.spaceS
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideMiddle
                            text: root.session.oneLine(entry.detail)
                            color: toolMouse.containsMouse ? Theme.textStrong : Theme.subtext
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontSmall
                        }

                        Text {
                            id: chev
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: entry.body !== "" || entry.result !== ""
                            text: entry.open ? "󰅀" : "󰅂"
                            color: Theme.muted
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontSmall
                        }

                        MouseArea {
                            id: toolMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: chev.visible
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.session.entries.setProperty(entry.index, "open", !entry.open)
                        }

                        Timer {
                            id: spinner
                            readonly property var frames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
                            property int frame: 0
                            interval: 90
                            repeat: true
                            running: entry.phase === "running"
                            onTriggered: frame = (frame + 1) % frames.length
                        }
                    }

                    // what it did, open
                    Rectangle {
                        visible: entry.open
                        width: parent.width
                        height: visible ? detailText.implicitHeight + Theme.spaceM * 2 : 0
                        radius: Theme.radiusInner
                        color: Theme.fieldFill

                        TextEdit {
                            id: detailText
                            x: Theme.spaceM
                            y: Theme.spaceM
                            width: parent.width - Theme.spaceM * 2
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.WrapAnywhere
                            textFormat: TextEdit.RichText
                            text: entry.open ? root.styled(entry.body, entry.result) : ""
                            color: Theme.text
                            selectionColor: Theme.selectedStroke
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontCaption
                        }
                    }
                }
            }

            Component {
                id: noteRow
                Text {
                    width: loader.width
                    wrapMode: Text.Wrap
                    horizontalAlignment: entry.kind === "note" ? Text.AlignHCenter : Text.AlignLeft
                    text: (entry.kind === "error" ? "󰀦  " : "") + entry.text
                    color: entry.kind === "error" ? Theme.alert : Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }
            }
        }
    }

    ScrollBar {
        flickable: list
        anchors.right: parent.right
    }
}
