// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutInput.qml
//
// A single-line text field sized like a FlyoutRow. `bleed` runs the frame
// past its edges so text lines up with row labels in a flyout; `glyph` and
// `hints` make it a search box. Its panel must hold keyboard focus, or a
// layer surface gets no keys.

import QtQuick
import "../services"

Item {
    id: root

    property string placeholder: ""
    property alias text: field.text
    property bool echoPassword: true
    property bool bleed: false
    property bool borderless: false
    property string glyph: ""
    property int glyphSize: Theme.fontIconSize
    property bool glyphQuiet: false
    property string actionGlyph: ""
    property string actionLabel: ""
    property bool actionActive: false
    property var hints: []
    readonly property bool focused: field.activeFocus

    signal accepted()
    signal actionClicked()
    // Arrow keys and Escape, for fields that drive a list below them. Emitted
    // from the field itself because it holds focus -- the list never sees a
    // key event while the cursor is here.
    signal upPressed()
    signal downPressed()
    // Left and Right too, but only when this is set (a grid or a row of
    // items); otherwise they move the text cursor as usual
    property bool sidewaysKeys: false
    signal leftPressed()
    signal rightPressed()
    signal escapePressed()
    signal tabPressed()
    signal backTabPressed()
    signal shiftDeletePressed()
    // Shift+Enter, for a field whose list has a second action on a row
    // (the launcher's file mode opens the containing folder with it)
    signal shiftReturnPressed()
    // Ctrl or Alt chords reported instead of handled, by name: "ctrl+p",
    // "alt+1", "ctrl+up" (the launcher's pin, row and rail keys)
    property var chordKeys: []
    signal chordPressed(string name)
    // Backspace with nothing left to delete
    signal emptyBackspace()
    property int textSize: Theme.fontBody

    function takeChord(event, key) {
        var m = event.modifiers
        var pre = (m & Qt.ControlModifier) ? "ctrl+" : (m & Qt.AltModifier) ? "alt+" : ""
        if (pre === "" || chordKeys.indexOf(pre + key) === -1) return false
        chordPressed(pre + key)
        event.accepted = true
        return true
    }

    width: parent ? parent.width : 0
    implicitHeight: Theme.rowHeightTall

    function forceFocus() {
        field.forceActiveFocus()
        field.selectAll()
    }

    // After inserting text programmatically: keep typing where the insert
    // left off rather than with the whole field selected, which the next
    // keystroke would replace.
    function moveToEnd() {
        field.forceActiveFocus()
        field.cursorPosition = field.text.length
    }

    Rectangle {
        id: well
        visible: !root.borderless
        readonly property color edge: field.activeFocus ? Theme.strokeFocus : Theme.stroke
        anchors.fill: parent
        anchors.leftMargin: root.bleed ? -Theme.spaceS : 0
        anchors.rightMargin: root.bleed ? -Theme.spaceS : 0
        radius: Theme.radiusInner
        color: Theme.fieldFill
        border.width: Theme.controlBorder(edge)
        border.color: Theme.controlStroke(edge)

        ControlEdge { stroke: well.edge; sunken: true; radius: well.radius }
    }

    // the glyph and the hints are outside the text, but still the field
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: field.forceActiveFocus()
    }

    Item {
        id: glyphCell
        visible: root.glyph !== ""
        x: Theme.spaceL
        width: visible ? Math.max(Theme.iconCell, root.glyphSize + Theme.spaceS) : 0
        height: parent.height

        Text {
            anchors.centerIn: parent
            text: root.glyph
            color: field.activeFocus && !root.glyphQuiet ? Theme.accent : Theme.subtext
            font.family: Theme.fontIcon
            font.pixelSize: root.glyphSize
        }
    }

    Row {
        id: hintRow
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceXl

        Repeater {
            model: root.hints

            Text {
                required property string modelData
                text: modelData.toUpperCase()
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontEyebrow
                font.letterSpacing: 1
            }
        }
    }

    Text {
        anchors.left: field.left
        anchors.right: field.right
        anchors.verticalCenter: parent.verticalCenter
        visible: field.text === ""
        text: root.placeholder
        elide: Text.ElideRight
        color: Theme.subtext
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: root.textSize
    }

    TextInput {
        id: field
        anchors.fill: parent
        anchors.leftMargin: root.glyph !== "" ? glyphCell.x + glyphCell.width + Theme.spaceM
            : Theme.spaceXs + (root.bleed ? 0 : Theme.spaceS)
        anchors.rightMargin: root.actionGlyph !== "" ? action.width + Theme.spaceS
            : root.hints.length > 0 ? hintRow.width + Theme.spaceL + Theme.spaceXl
            : Theme.spaceXs + (root.bleed ? 0 : Theme.spaceS)
        verticalAlignment: TextInput.AlignVCenter
        // text scrolled out of view past either end stays inside the frame
        clip: true
        color: Theme.textStrong
        selectionColor: Theme.selectedStroke
        selectedTextColor: Theme.hasAccent ? Theme.textOnAccent : Theme.textStrong

        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: root.textSize
        echoMode: root.echoPassword ? TextInput.Password : TextInput.Normal
        // the panel is dismissed by click-off or Escape, so Enter is the only
        // key this needs to act on itself
        onAccepted: root.accepted()
        Keys.onUpPressed: event => { if (!root.takeChord(event, "up")) root.upPressed() }
        Keys.onDownPressed: event => { if (!root.takeChord(event, "down")) root.downPressed() }
        Keys.onLeftPressed: event => {
            if (root.sidewaysKeys && !(event.modifiers & Qt.ShiftModifier)) root.leftPressed()
            else event.accepted = false
        }
        Keys.onRightPressed: event => {
            if (root.sidewaysKeys && !(event.modifiers & Qt.ShiftModifier)) root.rightPressed()
            else event.accepted = false
        }
        Keys.onEscapePressed: root.escapePressed()
        Keys.onTabPressed: root.tabPressed()
        Keys.onBacktabPressed: root.backTabPressed()
        Keys.onPressed: event => {
            var k = event.key
            var name = k >= Qt.Key_A && k <= Qt.Key_Z ? String.fromCharCode(k).toLowerCase()
                : k >= Qt.Key_0 && k <= Qt.Key_9 ? String(k - Qt.Key_0) : ""
            if (name !== "" && root.takeChord(event, name)) return
            if (k === Qt.Key_Backspace && field.text === "") root.emptyBackspace()
            if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                root.shiftDeletePressed()
                event.accepted = true
            }
            // caught here rather than in onAccepted, which can't tell a
            // plain Enter from a shifted one
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    && (event.modifiers & Qt.ShiftModifier)) {
                root.shiftReturnPressed()
                event.accepted = true
            }
        }
    }

    Item {
        id: action
        visible: root.actionGlyph !== ""
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.controlSize + Theme.spaceS

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.borderWidth
            height: parent.height - Theme.spaceM * 2
            color: Theme.stroke
        }
        Text {
            anchors.centerIn: parent
            text: root.actionGlyph
            color: root.actionActive ? Theme.accent : actionMouse.containsMouse ? Theme.textStrong : Theme.subtext
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
        }
        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: root.actionLabel
            onClicked: root.actionClicked()
        }
    }
}
