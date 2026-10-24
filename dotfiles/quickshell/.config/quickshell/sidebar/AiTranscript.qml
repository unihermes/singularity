// Singularity - Quickshell
// ~/.config/quickshell/sidebar/AiTranscript.qml
//
// A conversation's rows (ClaudeSession.entries): what you sent in a field
// with its attachments under it, Claude's replies as markdown you can
// select, each tool call as a line (a click opens what it did), errors and
// notes. Follows the end while it's in view; scrolling up stops that.

import QtQuick
import "../services"
import "../flyouts"

Item {
    id: root

    required property var session
    property bool available: true
    property string tab: "chat"

    function esc(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    // a tool's input and output as styled text, a diff's lines coloured
    function styled(body, result) {
        var out = []
        String(body || "").split("\n").slice(0, 200).forEach(l => {
            var c = l[0] === "+" ? Theme.good : l[0] === "-" ? Theme.alert
                : l.indexOf("@@") === 0 ? Theme.subtext : Theme.text
            out.push("<font color='" + c + "'>" + (esc(l) || "&nbsp;") + "</font>")
        })
        if (result) {
            if (out.length > 0) out.push("<font color='" + Theme.muted + "'>──</font>")
            String(result).split("\n").slice(0, 60).forEach(l => out.push(esc(l) || "&nbsp;"))
        }
        return out.join("<br>")
    }

    readonly property string emptyText: !available ? "Claude Code isn't installed. Install it (the claude-code package) and sign in with `claude` once."
        : tab === "chat" ? "Ask anything. Attach a screenshot, the clipboard or the selected text with 󰐕 below."
        : tab === "desktop" ? "Ask for a change to this desktop: the bar, a flyout, a keybind, a colour. Claude works on a copy of the repo; nothing changes until you apply it."
        : "Claude Code in the folder above. It asks before it runs a command or edits a file, unless you change that under the box."

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

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: Theme.spaceL
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

            width: list.width - Theme.scrollGutter
            height: loader.height

            Loader {
                id: loader
                width: parent.width
                sourceComponent: entry.kind === "user" ? userRow
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
                id: replyRow
                TextEdit {
                    width: loader.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.MarkdownText
                    text: entry.text
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
                            text: entry.detail
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
