// Singularity - Quickshell
// ~/.config/quickshell/sidebar/AiAsk.qml
//
// A permission prompt from Claude Code or Codex (their sessions' asks):
// what it wants to do and the command or plan in full, then Allow, the
// CLI's own "don't ask again" (all edits, that command, or Codex's for this
// session), and Deny. A plan is approved or
// sent back; Claude's questions are answered by picking an option each.

import QtQuick
import "../services"
import "../flyouts"

Column {
    id: root

    property var ask: null
    required property var session

    readonly property string tool: ask ? ask.tool : ""
    readonly property bool plan: tool === "ExitPlanMode"
    readonly property bool question: tool === "AskUserQuestion"
    readonly property var questions: question && ask.input.questions ? ask.input.questions : []

    // question -> the picked label(s), for AskUserQuestion
    property var picks: ({})
    onAskChanged: picks = ({})
    readonly property bool answered: questions.every(q => picks[q.question] !== undefined && picks[q.question] !== "")

    function pick(q, label) {
        var p = Object.assign({}, picks)
        if (q.multiSelect) {
            var have = (p[q.question] || "").split(", ").filter(s => s !== "")
            var at = have.indexOf(label)
            if (at === -1) have.push(label)
            else have.splice(at, 1)
            p[q.question] = have.join(", ")
        } else {
            p[q.question] = label
        }
        picks = p
    }

    // the CLI's suggestion, in words
    readonly property string alwaysText: {
        var s = ask && ask.suggestions.length > 0 ? ask.suggestions[0] : null
        if (!s) return ""
        if (s.type === "setMode" && s.mode === "acceptEdits") return "Allow all edits"
        if (s.type === "session") return "Allow for this session"
        if (s.type === "addRules") return "Always allow"
        return "Don't ask again"
    }

    width: parent ? parent.width : 0
    spacing: Theme.spaceM

    Row {
        width: parent.width
        spacing: Theme.spaceM

        Text {
            text: root.plan ? "󰙅" : root.question ? "󰘥" : "󰒃"
            color: Theme.accent
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
        }
        Text {
            width: parent.width - Theme.iconCell - parent.spacing
            elide: Text.ElideMiddle
            text: root.plan ? "Claude has a plan" : root.question ? "Claude asks"
                : root.ask ? "Allow: " + root.ask.title : ""
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightStrong
            font.pixelSize: Theme.fontBody
        }
    }

    // the command, or the plan, in full
    Rectangle {
        visible: !root.question && root.ask !== null && root.ask.detail !== ""
        width: parent.width
        height: Math.min(detailText.implicitHeight + Theme.spaceM * 2, Theme.fit(root.plan ? 260 : 120))
        radius: Theme.radiusInner
        color: Theme.fieldFill
        clip: true

        Flickable {
            id: detailFlick
            anchors.fill: parent
            anchors.margins: Theme.spaceM
            contentHeight: detailText.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            TextEdit {
                id: detailText
                width: detailFlick.width
                readOnly: true
                selectByMouse: true
                wrapMode: root.plan ? TextEdit.Wrap : TextEdit.WrapAnywhere
                textFormat: root.plan ? TextEdit.MarkdownText : TextEdit.PlainText
                text: root.ask ? root.ask.detail : ""
                color: Theme.text
                selectionColor: Theme.selectedStroke
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: root.plan ? Theme.fontSmall : Theme.fontCaption
            }
        }

        ScrollBar { flickable: detailFlick; anchors.right: parent.right; anchors.rightMargin: 2 }
    }

    // AskUserQuestion: each question with its options as chips
    Repeater {
        model: root.questions

        Column {
            id: q
            required property var modelData
            width: root.width
            spacing: Theme.spaceS

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: q.modelData.question
                color: Theme.text
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }

            Flow {
                width: parent.width
                spacing: Theme.spaceS

                Repeater {
                    model: q.modelData.options || []

                    FlyoutChip {
                        required property var modelData
                        text: modelData.label
                        selected: (root.picks[q.modelData.question] || "").split(", ").indexOf(modelData.label) !== -1
                        onClicked: root.pick(q.modelData, modelData.label)
                    }
                }
            }
        }
    }

    Row {
        spacing: Theme.spaceM

        FlyoutChip {
            icon: "󰄬"
            text: root.plan ? "Approve" : root.question ? "Answer" : "Allow"
            enabled: !root.question || root.answered
            onClicked: {
                if (root.question)
                    root.session.answer(root.ask.id, "allow",
                        Object.assign({}, root.ask.input, { answers: root.picks }))
                else root.session.answer(root.ask.id, "allow")
            }
        }
        FlyoutChip {
            visible: !root.plan && !root.question && root.alwaysText !== ""
            text: root.alwaysText
            onClicked: root.session.answer(root.ask.id, "always")
        }
        FlyoutChip {
            icon: "󰅖"
            text: root.plan ? "Keep planning" : root.question ? "Skip" : "Deny"
            onClicked: root.session.answer(root.ask.id, "deny", null,
                root.plan ? "The user wants to keep planning. Ask what to change, or refine the plan."
                : root.question ? "The user skipped the question. Carry on with your best judgement."
                : "The user said no to this. Ask before trying something else.")
        }
    }
}
