// Singularity - Quickshell
// ~/.config/quickshell/sidebar/AiComposer.qml
//
// Where a message is written: what's attached to it (a click takes one
// off), the box (Enter sends, Shift+Enter is a new line, Ctrl+L or /clear
// starts over), then a line with
// 󰐕 for attaching, the model and, on Code, the permission mode (each a
// click to the next), what Claude is doing, and Send or Stop.

import QtQuick
import "../services"
import "../flyouts"

Column {
    id: root

    required property var session
    signal escapePressed()
    // Ctrl+L or Ctrl+N, or /clear or /new sent on its own
    signal newConversation()

    property bool attaching: false

    function focusInput() { input.forceActiveFocus() }

    function submit() {
        if (/^\/(clear|new)\s*$/.test(input.text.trim())) {
            input.text = ""
            root.newConversation()
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
                        : Ai.tab === "code" ? "Ask Claude Code…"
                        : root.session.empty ? "Ask Claude…" : "Reply…"
                    color: Theme.textDisabled
                    font: input.font
                }

                Keys.onEscapePressed: root.escapePressed()
                Keys.onPressed: event => {
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
            FlyoutChip {
                text: Ai.label(Ai.modelChoices, Ai.models[Ai.tab] || "")
                onClicked: Ai.cycleModel()
            }
            FlyoutChip {
                visible: Ai.tab === "code"
                text: Ai.label(Ai.modeChoices, Ai.code.mode)
                selected: Ai.code.mode !== "default"
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
