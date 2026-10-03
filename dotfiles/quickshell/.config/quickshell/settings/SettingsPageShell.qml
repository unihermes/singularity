// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageShell.qml
//
// Alacritty's look, with a preview of it, and the aliases in ~/.bashrc.
//
// Two different kinds of instant, and the page says which is which.
// Alacritty watches its own config, so a change there shows in every open
// terminal the moment it's written. .bashrc is only read when a shell
// starts, so alias edits apply to new terminals -- the ones already open
// keep what they had until `source ~/.bashrc`.
//
// Both are line edits, like the other pages: a TOML key's value inside its
// [table], or one `alias name='...'` line. Everything else in either file is
// left as it was.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Terminal"
    description: "How Alacritty looks, and your shell aliases."

    readonly property string home: Quickshell.env("HOME")
    readonly property string alacrittyPath:
        (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/alacritty/alacritty.toml"
    readonly property string bashrcPath: home + "/.bashrc"

    // --- alacritty -----------------------------------------------------------

    // "table.key" -> raw TOML value text
    property var toml: ({})

    // Line-based: tracks the current [table] header and reads `key = value`
    // lines under it. Inline tables and arrays aren't looked into -- nothing
    // this page sets lives in one.
    function parseToml(text) {
        var out = {}, table = ""
        text.split("\n").forEach(line => {
            var l = line.replace(/\s+#.*$/, "").trim()
            var m
            if ((m = /^\[([^\]]+)\]$/.exec(l))) table = m[1].trim()
            else if ((m = /^([A-Za-z0-9_-]+)\s*=\s*(.+)$/.exec(l))) out[(table ? table + "." : "") + m[1]] = m[2]
        })
        return out
    }

    function tomlValue(path, fallback) {
        var raw = toml[path]
        if (raw === undefined) return fallback
        if (/^".*"$/.test(raw)) return raw.slice(1, -1)
        if (raw === "true" || raw === "false") return raw === "true"
        var n = Number(raw)
        return isNaN(n) ? raw : n
    }

    function tomlLiteral(v) {
        if (typeof v === "boolean") return v ? "true" : "false"
        if (typeof v === "number") return Number.isInteger(v) ? v.toFixed(1) : String(Math.round(v * 100) / 100)
        return JSON.stringify(v)
    }

    // Set key in [table], replacing its line, or adding it under the table
    // header (and the header at the end of the file if there isn't one).
    function setToml(table, key, value, message) {
        alacrittyFile.reload()
        alacrittyFile.waitForJob()
        var lines = alacrittyFile.text().split("\n")
        var cur = "", headerAt = -1, lastInTable = -1
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            var m = /^\[([^\]]+)\]/.exec(l)
            if (m) { cur = m[1].trim(); if (cur === table) { headerAt = i; lastInTable = i } continue }
            if (cur !== table) continue
            if (l !== "" && !l.startsWith("#")) lastInTable = i
            var km = new RegExp("^(\\s*" + key + "\\s*=\\s*)([^#]*?)(\\s*(#.*)?)$").exec(lines[i])
            if (km) {
                lines[i] = km[1] + tomlLiteral(value) + km[3]
                return writeFile(alacrittyPath, lines.join("\n"), message, false)
            }
        }
        var entry = key + " = " + tomlLiteral(value)
        if (headerAt < 0) lines.push("", "[" + table + "]", entry)
        else lines.splice(lastInTable + 1, 0, entry)
        writeFile(alacrittyPath, lines.join("\n"), message, false)
    }

    FileView {
        id: alacrittyFile
        path: page.alacrittyPath
        blockLoading: true
        printErrors: false
    }

    // --- aliases -------------------------------------------------------------

    // [{ name, value, line }]
    property var aliases: []

    function parseAliases(text) {
        var out = []
        text.split("\n").forEach((line, i) => {
            var m = /^\s*alias\s+([A-Za-z0-9_.:-]+)=(?:'([^']*)'|"((?:[^"\\]|\\.)*)"|(\S+))\s*$/.exec(line)
            if (m) out.push({ name: m[1], value: m[2] !== undefined ? m[2] : m[3] !== undefined ? m[3] : m[4], line: i })
        })
        return out
    }

    // single quotes can't hold a single quote: close, escape one, reopen
    function shQuote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    function addAlias(name, value) {
        name = name.trim()
        if (!/^[A-Za-z0-9_.:-]+$/.test(name)) { say("An alias name is letters, digits and _ . : - only", true); return false }
        if (value.trim() === "") { say("The alias needs a command", true); return false }
        bashrcFile.reload()
        bashrcFile.waitForJob()
        var text = bashrcFile.text()
        var lines = text.split("\n")
        var current = parseAliases(text)
        var line = "alias " + name + "=" + shQuote(value.trim())
        var existing = current.find(a => a.name === name)
        if (existing) {
            lines[existing.line] = line
        } else if (current.length > 0) {
            lines.splice(current[current.length - 1].line + 1, 0, line)
        } else {
            // before a trailing blank line, so the file still ends the same way
            var at = lines.length && lines[lines.length - 1] === "" ? lines.length - 1 : lines.length
            lines.splice(at, 0, line)
        }
        writeFile(bashrcPath, lines.join("\n"), (existing ? "Changed " : "Added ") + name + ", in new terminals", true)
        return true
    }

    function removeAlias(a) {
        bashrcFile.reload()
        bashrcFile.waitForJob()
        var lines = bashrcFile.text().split("\n")
        var fresh = parseAliases(lines.join("\n")).find(x => x.name === a.name && x.line === a.line)
        if (!fresh) { say("~/.bashrc changed on disk; nothing removed", true); reread(); return }
        lines.splice(a.line, 1)
        writeFile(bashrcPath, lines.join("\n"), "Removed " + a.name + ", in new terminals", true)
    }

    FileView {
        id: bashrcFile
        path: page.bashrcPath
        blockLoading: true
        printErrors: false
    }

    // --- shared --------------------------------------------------------------

    // .bashrc edits are checked with `bash -n` first. The callers build the
    // whole file from a read made just before, so a second write can't be
    // queued behind the first -- it would be built on the text the first one
    // is about to replace.
    function writeFile(path, text, message, checkBash) {
        if (AtomicFileWrite.busy) { say("Still writing the last change", true); return }
        AtomicFileWrite.write({
            path: path,
            transform: () => text,
            check: checkBash ? "bash" : "",
            done: (status, detail) => {
                if (status === "ok" || status === "unchanged") page.say(message, false)
                else if (status === "syntax") page.say("Not written, bash -n says: " + (detail.split("\n")[0] || "syntax error").replace(/^.*?: line/, "line"), true)
                else page.say("Couldn't write the file", true)
                page.reread()
            }
        })
    }

    function reread() {
        alacrittyFile.reload()
        alacrittyFile.waitForJob()
        toml = parseToml(alacrittyFile.text())
        bashrcFile.reload()
        bashrcFile.waitForJob()
        aliases = parseAliases(bashrcFile.text())
    }

    Component.onCompleted: reread()

    // --- layout --------------------------------------------------------------

    // style = { shape = "Beam", blinking = "On" } is an inline table, so
    // it's read by pattern rather than parsed
    readonly property string cursorRaw: String(toml["cursor.style"] || "")
    readonly property string cursorShape: (/shape\s*=\s*"(\w+)"/.exec(cursorRaw) || [, "Block"])[1]
    readonly property string cursorBlinking: (/blinking\s*=\s*"(\w+)"/.exec(cursorRaw) || [, "Off"])[1]

    function setCursor(shape, blinking) {
        // written as a plain string value so setToml's line replace fits it
        alacrittyFile.reload()
        alacrittyFile.waitForJob()
        var lines = alacrittyFile.text().split("\n")
        var cur = ""
        for (var i = 0; i < lines.length; i++) {
            var m = /^\s*\[([^\]]+)\]/.exec(lines[i])
            if (m) { cur = m[1].trim(); continue }
            if (cur === "cursor" && /^\s*style\s*=/.test(lines[i])) {
                lines[i] = 'style = { shape = "' + shape + '", blinking = "' + blinking + '" }'
                writeFile(alacrittyPath, lines.join("\n"), "Cursor: " + shape + (blinking === "Off" ? "" : ", blinking"), false)
                return
            }
        }
        // no style line: add one through the generic path
        var at = lines.findIndex(l => /^\s*\[cursor\]/.test(l))
        if (at < 0) lines.push("", "[cursor]", 'style = { shape = "' + shape + '", blinking = "' + blinking + '" }')
        else lines.splice(at + 1, 0, 'style = { shape = "' + shape + '", blinking = "' + blinking + '" }')
        writeFile(alacrittyPath, lines.join("\n"), "Cursor: " + shape, false)
    }


    readonly property real fontSize: Number(tomlValue("font.size", 11.25))
    // Settings' rather than this file's, so looks and styles can set it;
    // AppearanceSync writes it into the config alacritty.toml imports
    readonly property real opacityNow: Settings.terminalOpacity / 100
    // the opacity while the level is being dragged, written on release
    property real opacityDragged: -1
    readonly property real opacityShown: opacityDragged >= 0 ? opacityDragged : opacityNow
    readonly property bool blinking: cursorBlinking === "On" || cursorBlinking === "Always"

    FlyoutHeading { text: "ALACRITTY" }

    // A terminal as it will look: the wallpaper through the background at
    // the opacity, the prompt in the look's colours at the font size, and
    // the cursor's shape and blink.
    Rectangle {
        id: term
        width: parent.width
        height: Theme.fit(150)
        radius: Theme.radiusInner
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.frameStroke
        clip: true

        Image {
            anchors.fill: parent
            anchors.margins: Theme.borderWidth
            fillMode: Image.PreserveAspectCrop
            source: "file://" + page.home + "/.local/state/singularity/current-wallpaper"
            sourceSize.width: 640
            cache: false
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.borderWidth
            color: Theme.base
            opacity: page.opacityShown
        }

        // points to pixels, as Alacritty sizes its font
        readonly property real px: page.fontSize * 96 / 72

        Column {
            x: Theme.spaceL
            y: Theme.spaceM
            spacing: 0

            component Line: Text {
                font.family: "UbuntuMono Nerd Font Mono"
                font.pixelSize: term.px
                color: Theme.text
                textFormat: Text.PlainText
            }
            component Path: Rectangle {
                width: pathText.implicitWidth + term.px * 0.6
                height: pathText.implicitHeight
                radius: Theme.radiusSmall
                color: Theme.accent
                Line {
                    id: pathText
                    anchors.centerIn: parent
                    text: "~/Git/singularity"
                    color: Theme.textOnAccent
                }
            }

            Path {}
            Line { text: "❯ ls" }
            Line { text: "dotfiles  README.md  tools" }
            Line { text: " " }
            Path {}
            Row {
                Line { id: promptChar; text: "❯ " }
                Rectangle {
                    readonly property real cell: promptChar.implicitWidth / 2
                    anchors.bottom: page.cursorShape === "Underline" ? promptChar.bottom : undefined
                    anchors.verticalCenter: page.cursorShape === "Underline" ? undefined : promptChar.verticalCenter
                    width: page.cursorShape === "Beam" ? Math.max(2, term.px * 0.12) : cell
                    height: page.cursorShape === "Underline" ? Math.max(2, term.px * 0.1) : promptChar.implicitHeight * 0.9
                    color: Theme.textStrong
                    opacity: page.blinking && blinkTimer.off ? 0 : 1
                }
            }
        }

        Timer {
            id: blinkTimer
            property bool off: false
            interval: 600
            repeat: true
            running: page.blinking && term.visible && page.visible
            onTriggered: off = !off
            onRunningChanged: off = false
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spaceM
            text: "Alacritty, as it will look"
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontCaption
        }
    }

    SettingsField {
        label: "Font size"
        hint: "In points"
        FlyoutStepper {
            anchors.right: parent.right
            width: Theme.fit(170)
            readonly property real current: page.fontSize
            value: Math.round(current * 2)
            minimum: 12
            maximum: 64
            valueWidth: 56
            displayValue: current.toFixed(1)
            onStepped: delta => page.setToml("font", "size", (value + delta) / 2, "Font size " + ((value + delta) / 2).toFixed(1))
        }
    }

    // 30% to solid, in steps of 5
    SettingsField {
        label: "Opacity"
        lookKey: "terminalOpacity"
        hint: page.opacityShown >= 1 ? "Solid" : "The wallpaper shows through the background"

        Row {
            anchors.right: parent.right
            spacing: Theme.sp(10)

            Slider {
                width: Theme.fit(220)
                anchors.verticalCenter: parent.verticalCenter
                value: (page.opacityShown - 0.3) / 0.7 * 100
                onMoved: v => page.opacityDragged = Math.round((0.3 + v / 100 * 0.7) * 20) / 20
                onReleased: {
                    var v = page.opacityDragged
                    if (v >= 0 && Math.abs(v - page.opacityNow) > 0.001)
                        Settings.set("terminalOpacity", v * 100)
                    page.opacityDragged = -1
                }
            }
            Text {
                width: Theme.fs(52)
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: Math.round(page.opacityShown * 100) + "%"
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
        }
    }

    SettingsField {
        label: "Cursor"
        hint: page.blinking ? "Blinks while the terminal has focus" : "Steady"
    }

    // each tile draws its cursor between two letters
    SettingsTiles {
        columns: 3
        tileHeight: Theme.fs(64)
        model: ["Block", "Beam", "Underline"].map(v => ({ value: v, text: v }))
        current: page.cursorShape
        onPicked: v => page.setCursor(v, page.cursorBlinking)
        art: Component {
            Row {
                id: art
                readonly property string shape: parent ? parent.value : ""
                spacing: 1
                Text {
                    id: letterA
                    text: "a"
                    color: Theme.text
                    font.family: "UbuntuMono Nerd Font Mono"
                    font.pixelSize: Theme.fs(20)
                }
                Item {
                    width: art.shape === "Beam" ? 2 : letterA.implicitWidth
                    height: letterA.implicitHeight
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: art.shape === "Underline" ? letterA.implicitHeight * 0.12 : letterA.implicitHeight * 0.08
                        width: parent.width
                        height: art.shape === "Underline" ? 2 : letterA.implicitHeight * 0.84
                        color: Theme.textStrong
                    }
                }
                Text {
                    text: "b"
                    color: Theme.text
                    font.family: "UbuntuMono Nerd Font Mono"
                    font.pixelSize: Theme.fs(20)
                }
            }
        }
    }

    SettingsField {
        label: "Blinking"

        Switch {
            anchors.right: parent.right
            checked: page.blinking
            onToggled: page.setCursor(page.cursorShape, page.blinking ? "Off" : "On")
        }
    }

    // --- aliases ---------------------------------------------------------------

    // the alias open under its row (its index), or -1; adding opens the last row
    property int openAlias: -1
    property bool addingAlias: false

    // A name and a command, and Save / Cancel: an alias being edited, or a
    // new one.
    component AliasEditor: Item {
        id: ed
        property string name: ""
        property string command: ""
        property bool isNew: false
        signal done()

        width: parent ? parent.width : 0
        height: nameIn.implicitHeight

        // filled from the file each time it opens
        onVisibleChanged: if (visible) {
            nameIn.text = ed.name
            cmdIn.text = ed.command
        }

        function save() {
            if (page.addAlias(nameIn.text, cmdIn.text)) {
                // a rename leaves the old line; take it out
                if (!ed.isNew && nameIn.text.trim() !== ed.name) {
                    var old = page.aliases.find(a => a.name === ed.name)
                    if (old) Qt.callLater(() => page.removeAlias(old))
                }
                ed.done()
            }
        }
        function focus() { (ed.isNew ? nameIn : cmdIn).forceFocus() }

        FlyoutInput {
            id: nameIn
            anchors.left: parent.left
            width: Theme.fit(150)
            echoPassword: false
            placeholder: "name"
            onAccepted: cmdIn.forceFocus()
            onEscapePressed: ed.done()
        }
        FlyoutInput {
            id: cmdIn
            anchors.left: nameIn.right
            anchors.leftMargin: Theme.spaceM
            anchors.right: saveChip.left
            anchors.rightMargin: Theme.spaceM
            echoPassword: false
            placeholder: "command, e.g. git status"
            onAccepted: ed.save()
            onEscapePressed: ed.done()
        }
        FlyoutChip {
            id: saveChip
            anchors.right: cancelChip.left
            anchors.rightMargin: Theme.spaceS
            anchors.verticalCenter: parent.verticalCenter
            text: ed.isNew ? "Add" : "Save"
            selected: true
            enabled: !AtomicFileWrite.busy && nameIn.text.trim() !== "" && cmdIn.text.trim() !== ""
            onClicked: ed.save()
        }
        FlyoutChip {
            id: cancelChip
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Cancel"
            onClicked: ed.done()
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "BASH ALIASES" + (page.aliases.length > 0 ? "  " + page.aliases.length : "") }

    SettingsNote { text: "New terminals pick them up; open ones need source ~/.bashrc" }

    Repeater {
        model: page.aliases

        Column {
            id: al
            required property var modelData
            required property int index
            readonly property bool isOpen: page.openAlias === index

            width: parent ? parent.width : 0

            FlyoutRow {
                label: al.modelData.name
                note: al.modelData.value
                highlighted: al.isOpen
                trailing: al.isOpen ? "󰅀" : "󰅂"
                onActivated: {
                    page.addingAlias = false
                    page.openAlias = al.isOpen ? -1 : al.index
                    if (page.openAlias === al.index) Qt.callLater(editor.focus)
                }
            }

            SettingsIndent {
                visible: al.isOpen

                AliasEditor {
                    id: editor
                    name: al.modelData.name
                    command: al.modelData.value
                    onDone: page.openAlias = -1
                }

                FlyoutChip {
                    text: "󰆴 Remove alias"
                    confirmText: "Remove " + al.modelData.name + "?"
                    enabled: !AtomicFileWrite.busy
                    onClicked: {
                        page.openAlias = -1
                        page.removeAlias(al.modelData)
                    }
                }
            }
        }
    }

    FlyoutRow {
        label: "Add an alias…"
        trailing: "󰐕"
        highlighted: page.addingAlias
        onActivated: {
            page.openAlias = -1
            page.addingAlias = !page.addingAlias
            if (page.addingAlias) Qt.callLater(newAlias.focus)
        }
    }

    SettingsIndent {
        visible: page.addingAlias

        AliasEditor {
            id: newAlias
            isNew: true
            onDone: page.addingAlias = false
        }
    }
}
