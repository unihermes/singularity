// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutInput.qml
//
// A single-line text field sized like a FlyoutRow: a Wi-Fi passphrase, a
// prompt, and every text setting on the Settings pages.
//
// `bleed` runs the frame out past the field's own edges, as a FlyoutRow's
// hover fill does, so the typed text lines up with the row labels above it
// in a flyout. On a Settings page it stays within its bounds, so its edges
// line up with the chips and switches beside it.
//
// A search box is the same field with a `glyph` in front, lit while it has
// focus, and key `hints` at its far end: the launcher's and Settings'.
//
// The panel it sits in must ask for keyboard focus (FlyoutPanel.wantsKeyboard)
// -- a layer-shell surface gets no key events at all otherwise, and the field
// would look focused while silently dropping every keystroke.

import QtQuick
import "../services"

Item {
    id: root

    property string placeholder: ""
    property alias text: field.text
    property bool echoPassword: true
    property bool bleed: false
    property string glyph: ""
    property var hints: []
    readonly property bool focused: field.activeFocus

    signal accepted()
    // Arrow keys and Escape, for fields that drive a list below them. Emitted
    // from the field itself because it holds focus -- the list never sees a
    // key event while the cursor is here.
    signal upPressed()
    signal downPressed()
    signal escapePressed()
    signal tabPressed()
    signal backTabPressed()
    signal shiftDeletePressed()
    // Shift+Enter, for a field whose list has a second action on a row
    // (the launcher's file mode opens the containing folder with it)
    signal shiftReturnPressed()

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
        width: visible ? Theme.iconCell : 0
        height: parent.height

        Text {
            anchors.centerIn: parent
            text: root.glyph
            color: field.activeFocus ? Theme.accent : Theme.subtext
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
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
        color: Theme.textDisabled
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }

    TextInput {
        id: field
        anchors.fill: parent
        anchors.leftMargin: root.glyph !== "" ? glyphCell.x + glyphCell.width + Theme.spaceM
            : Theme.spaceXs + (root.bleed ? 0 : Theme.spaceS)
        anchors.rightMargin: root.hints.length > 0 ? hintRow.width + Theme.spaceL + Theme.spaceXl
            : Theme.spaceXs + (root.bleed ? 0 : Theme.spaceS)
        verticalAlignment: TextInput.AlignVCenter
        // text scrolled out of view past either end stays inside the frame
        clip: true
        color: Theme.textStrong
        selectionColor: Theme.muted
        selectedTextColor: Theme.textStrong

        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
        echoMode: root.echoPassword ? TextInput.Password : TextInput.Normal
        // the panel is dismissed by click-off or Escape, so Enter is the only
        // key this needs to act on itself
        onAccepted: root.accepted()
        Keys.onUpPressed: root.upPressed()
        Keys.onDownPressed: root.downPressed()
        Keys.onEscapePressed: root.escapePressed()
        Keys.onTabPressed: root.tabPressed()
        Keys.onBacktabPressed: root.backTabPressed()
        Keys.onPressed: event => {
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
}
