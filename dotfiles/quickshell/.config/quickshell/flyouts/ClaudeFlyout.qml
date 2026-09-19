// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ClaudeFlyout.qml
//
// The Claude module's flyout: the conversation, what it has changed so far,
// and the box to ask in. Changes pile up in a staging copy until Apply
// (services/ClaudeShell.qml), so the diff here is the whole review -- there
// is no other step between it and the live desktop.
//
// Takes the keyboard the moment it opens, like the launcher: the point is
// to press SUPER+I and start typing.

import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "claude"
    menuWidth: 440
    keyboardExclusive: open

    property bool showDiff: false

    readonly property var diffLines: {
        if (!showDiff) return []
        var l = ClaudeShell.diff.split("\n")
        // a rewritten file can run to thousands of lines; the flyout is a
        // glance, the full thing is one `claude-shell.sh diff` away
        return l.length > 1500 ? l.slice(0, 1500).concat(["… " + (l.length - 1500) + " more lines"]) : l
    }

    onOpenChanged: {
        if (!open) return
        ClaudeShell.unseen = false
        Qt.callLater(prompt.forceFocus)
    }

    Connections {
        target: ClaudeShell
        function onUnseenChanged() { if (root.open) ClaudeShell.unseen = false }
        function onHasChangesChanged() { if (!ClaudeShell.hasChanges) root.showDiff = false }
    }

    function displayPath(p) {
        return p === ".live/appearance.json" ? "Shell settings" : p
    }

    FlyoutHeading {
        text: "CLAUDE" + (ClaudeShell.cost > 0 ? "  $" + ClaudeShell.cost.toFixed(2) : "")
    }

    FlyoutRow {
        visible: !ClaudeShell.available
        label: "claude-code isn't installed"
        enabled: false
    }

    // ---- conversation -----------------------------------------------

    Text {
        visible: ClaudeShell.available && ClaudeShell.transcript.length === 0
        width: parent.width
        wrapMode: Text.Wrap
        text: "Ask for a change to your desktop, or a question about it. Claude works on a "
            + "copy of the repo; nothing goes live until you apply it."
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }

    Item {
        visible: ClaudeShell.transcript.length > 0
        width: parent.width
        height: convo.height

        ListView {
            id: convo
            width: parent.width - Theme.spaceL
            height: Math.min(contentHeight, Theme.row(22) * 14)
            clip: true
            spacing: Theme.spaceM
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: ClaudeShell.transcript
            onCountChanged: Qt.callLater(positionViewAtEnd)

            delegate: Row {
                id: entry
                required property var modelData
                readonly property string kind: modelData.kind
                width: convo.width
                spacing: Theme.spaceM

                Text {
                    id: mark
                    text: entry.kind === "user" ? "›"
                        : entry.kind === "tool" ? "󰏫"
                        : entry.kind === "error" ? "󰀦" : "󰚩"
                    color: entry.kind === "error" ? Theme.alert
                        : entry.kind === "user" ? Theme.textStrong : Theme.subtext
                    font.family: Theme.fontIcon
                    font.pixelSize: entry.kind === "tool" ? Theme.fontSmall : Theme.fontBody
                }

                Text {
                    width: entry.width - mark.width - entry.spacing
                    text: entry.modelData.text
                    wrapMode: Text.Wrap
                    // a tool line is one step of many; the reply is what matters
                    maximumLineCount: entry.kind === "tool" ? 1 : 1000
                    elide: Text.ElideMiddle
                    color: entry.kind === "user" ? Theme.textStrong
                        : entry.kind === "tool" ? Theme.subtext
                        : entry.kind === "error" ? Theme.alert : Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: entry.kind === "tool" ? Theme.fontSmall : Theme.fontBody
                }
            }
        }

        ScrollBar {
            flickable: convo
            anchors.right: parent.right
        }
    }

    FlyoutRow {
        visible: ClaudeShell.running
        label: ClaudeShell.activity || "Working"
        trailing: "󰔟"
        busy: true
        enabled: false
    }

    FlyoutRow {
        visible: ClaudeShell.running
        label: "Stop"
        trailing: "󰓛"
        onActivated: ClaudeShell.stop()
    }

    // ---- changes ----------------------------------------------------

    FlyoutHeading {
        visible: ClaudeShell.hasChanges
        text: "CHANGES  " + ClaudeShell.files.length
    }

    Repeater {
        model: ClaudeShell.files

        Item {
            id: fileRow
            required property var modelData
            width: parent.width
            height: Theme.row(22)

            Text {
                anchors.left: parent.left
                anchors.right: counts.left
                anchors.rightMargin: Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                text: root.displayPath(fileRow.modelData.path)
                elide: Text.ElideLeft
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }

            Row {
                id: counts
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceM

                Text {
                    text: "+" + fileRow.modelData.added
                    color: Theme.good
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                }
                Text {
                    text: "−" + fileRow.modelData.removed
                    color: Theme.alert
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                }
            }
        }
    }

    Item {
        visible: root.showDiff && ClaudeShell.hasChanges
        width: parent.width
        height: diffView.height

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -Theme.spaceS
            radius: Theme.radiusInner
            color: Theme.fieldFill
        }

        ListView {
            id: diffView
            x: Theme.spaceXs
            width: parent.width - Theme.spaceL - Theme.spaceXs
            height: Math.min(contentHeight, Theme.row(18) * 18)
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: root.diffLines

            delegate: Text {
                required property string modelData
                readonly property string c: modelData.charAt(0)
                readonly property bool header: modelData.indexOf("diff --git") === 0
                    || modelData.indexOf("+++") === 0 || modelData.indexOf("---") === 0
                    || modelData.indexOf("index ") === 0 || modelData.indexOf("new file") === 0
                    || modelData.indexOf("deleted file") === 0
                // the diff --git line names the file; the rest of the header is noise
                // its own flag, not `visible`: that also reads the ListView's
                // culling, which feeds back into the height
                readonly property bool shown: !header || modelData.indexOf("diff --git") === 0
                visible: shown
                height: shown ? implicitHeight : 0
                width: diffView.width
                text: modelData.indexOf("diff --git") === 0
                    ? root.displayPath((modelData.match(/ b\/(.*)$/) || [0, modelData])[1])
                    : modelData
                wrapMode: Text.WrapAnywhere
                color: modelData.indexOf("diff --git") === 0 ? Theme.textStrong
                    : c === "@" ? Theme.subtext
                    : c === "+" ? Theme.good
                    : c === "-" ? Theme.alert : Theme.text
                font.bold: modelData.indexOf("diff --git") === 0
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }
        }

        ScrollBar {
            flickable: diffView
            anchors.right: parent.right
        }
    }

    FlyoutRow {
        visible: ClaudeShell.hasChanges
        label: root.showDiff ? "Hide diff" : "Show diff"
        trailing: root.showDiff ? "󰅃" : "󰅀"
        onActivated: root.showDiff = !root.showDiff
    }

    FlyoutRow {
        visible: ClaudeShell.hasChanges
        label: ClaudeShell.applying ? "Applying..." : "Apply changes"
        trailing: "󰄬"
        enabled: !ClaudeShell.running && !ClaudeShell.applying
        onActivated: ClaudeShell.apply()
    }

    FlyoutRow {
        visible: ClaudeShell.hasChanges || ClaudeShell.transcript.length > 0
        label: ClaudeShell.hasChanges ? "Discard" : "New conversation"
        trailing: ClaudeShell.hasChanges ? "󰅖" : "󰐕"
        onActivated: ClaudeShell.discard()
    }

    FlyoutDivider {
        visible: ClaudeShell.available
    }

    FlyoutInput {
        id: prompt
        visible: ClaudeShell.available
        echoPassword: false
        placeholder: ClaudeShell.running ? "Working..."
            : ClaudeShell.transcript.length > 0 ? "Follow up..." : "Ask Claude to change something..."
        onAccepted: {
            if (ClaudeShell.running) return
            ClaudeShell.ask(text)
            text = ""
        }
        onEscapePressed: root.requestClose()
    }
}
