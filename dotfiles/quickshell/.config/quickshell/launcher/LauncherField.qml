// Singularity - Quickshell
// ~/.config/quickshell/launcher/LauncherField.qml
//
// The launcher's search field, in whichever layout: the mode's glyph, the
// query, and the keys, handed to `view` (the layout): the arrows to
// move(dx, dy), Enter and its variants to current(). Ctrl+P pins the
// current app; a layout's own chords (`view.chords`) go to view.chord().

import QtQuick
import "../services"
import "../flyouts"

FlyoutInput {
    id: f

    required property var launcher
    required property var view

    height: Theme.rowHeightTall + Theme.spaceM
    echoPassword: false
    glyph: launcher.glyphs[launcher.mode]
    placeholder: launcher.blended ? "Search apps, files, clipboard and sums" : launcher.placeholders[launcher.mode]
    sidewaysKeys: view.sideways === true
    chordKeys: ["ctrl+p"].concat(view.chords || [])

    Component.onCompleted: launcher.field = f

    function clear() { text = "" }

    // a calculator syntax row: replaces the word being typed
    function insertAtWord(insert) {
        text = text.replace(/[a-zA-Z][a-zA-Z0-9]*$/, "") + insert
        Qt.callLater(moveToEnd)
    }

    onTextChanged: launcher.typed(text)
    onAccepted: {
        var c = view.current()
        if (c) launcher.activate(c.item, c.kind)
    }
    onShiftReturnPressed: {
        var c = view.current()
        if (c) launcher.activateAlt(c.item, c.kind)
    }
    onShiftDeletePressed: {
        var c = view.current()
        if (c) launcher.remove(c.item, c.kind)
    }
    onDownPressed: view.move(0, 1)
    onUpPressed: view.move(0, -1)
    onLeftPressed: view.move(-1, 0)
    onRightPressed: view.move(1, 0)
    onEscapePressed: launcher.requestClose()
    onTabPressed: launcher.stepMode(1)
    onBackTabPressed: launcher.stepMode(-1)
    onChordPressed: name => {
        if (name === "ctrl+p") {
            var c = view.current()
            if (c && c.kind === "app") Apps.togglePin(c.item)
        } else view.chord(name)
    }
    // Spotlight narrowed to one kind widens again
    onEmptyBackspace: if (launcher.layout === "spotlight" && launcher.mode !== "apps") launcher.setMode("apps")
}
