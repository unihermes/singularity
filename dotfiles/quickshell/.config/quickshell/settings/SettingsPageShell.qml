// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageShell.qml
//
// The terminal (Alacritty or Ghostty), its look with a preview, and
// ~/.bash_aliases; this machine's own copies (link.sh). Font size and cursor
// go to both terminals' configs. Terminal changes show at once (Alacritty
// watches, Ghostty is told to reload); aliases apply to new shells. All are
// line edits; the rest of each file is untouched.

import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Terminal"
    description: "Which terminal opens, how it looks, and your shell aliases."

    readonly property string home: Quickshell.env("HOME")
    readonly property string alacrittyPath:
        (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/alacritty/alacritty.toml"
    readonly property string ghosttyPath:
        (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/ghostty/config.ghostty"
    readonly property bool ghostty: Settings.terminalApp === "ghostty"
    readonly property string appName: Settings.choiceLabel(Settings.terminalApp)
    readonly property string aliasesPath: home + "/.bash_aliases"

    // --- alacritty -----------------------------------------------------------

    // "table.key" -> raw TOML value text
    property var toml: ({})

    // line-based: `key = value` under the current [table]; inline tables
    // and arrays aren't read
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

    // sets key in [table], adding the line (and header) if missing; run on
    // the file as it is when the write runs
    function tomlSet(text, table, key, value) {
        var lines = text.split("\n")
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
                return lines.join("\n")
            }
        }
        var entry = key + " = " + tomlLiteral(value)
        if (headerAt < 0) lines.push("", "[" + table + "]", entry)
        else lines.splice(lastInTable + 1, 0, entry)
        return lines.join("\n")
    }

    // --- ghostty -------------------------------------------------------------

    // key -> value, the last one set winning, as Ghostty reads it. Only
    // whole-line comments: a # in a value (a colour) is the value's.
    property var kv: ({})

    function parseKv(text) {
        var out = {}
        text.split("\n").forEach(line => {
            var m = /^\s*([a-z0-9-]+)\s*=\s*(.*?)\s*$/.exec(line)
            if (m) out[m[1]] = m[2]
        })
        return out
    }

    // Each key's last line replaced, or the key added at the end.
    function kvSet(text, values) {
        var lines = text.split("\n")
        for (var key in values) {
            var at = -1
            for (var i = 0; i < lines.length; i++)
                if (new RegExp("^\\s*" + key + "\\s*=").test(lines[i])) at = i
            var entry = key + " = " + values[key]
            if (at >= 0) lines[at] = entry
            else lines.splice(lines.length && lines[lines.length - 1] === "" ? lines.length - 1 : lines.length, 0, entry)
        }
        return lines.join("\n")
    }

    // --- both ----------------------------------------------------------------

    // one change to each terminal's config; a missing config is left alone
    function writeBoth(alacritty, ghostty, message) {
        var left = 2, failed = false
        var finish = status => {
            if (status === "write" || status === "syntax") failed = true
            if (--left > 0) return
            page.say(failed ? "Couldn't write the file" : message, failed)
            page.reread()
        }
        AtomicFileWrite.write({ path: alacrittyPath, done: finish,
                                transform: text => text === "" ? null : alacritty(text) })
        AtomicFileWrite.write({ path: ghosttyPath, done: finish, after: "pkill -USR2 -x ghostty; true",
                                transform: text => text === "" ? null : ghostty(text) })
    }

    function setFontSize(size) {
        writeBoth(text => tomlSet(text, "font", "size", size),
                  text => kvSet(text, { "font-size": String(size) }),
                  "Font size " + size.toFixed(1))
    }

    readonly property var ghosttyCursors: ({ Block: "block", Beam: "bar", Underline: "underline" })

    // Alacritty's style = { shape = "Beam", blinking = "On" } is an inline
    // table, so its line is rewritten whole rather than through tomlSet.
    function setCursor(shape, blinking) {
        var style = 'style = { shape = "' + shape + '", blinking = "' + blinking + '" }'
        writeBoth(text => {
            var lines = text.split("\n")
            var cur = ""
            for (var i = 0; i < lines.length; i++) {
                var m = /^\s*\[([^\]]+)\]/.exec(lines[i])
                if (m) { cur = m[1].trim(); continue }
                if (cur === "cursor" && /^\s*style\s*=/.test(lines[i])) {
                    lines[i] = style
                    return lines.join("\n")
                }
            }
            var at = lines.findIndex(l => /^\s*\[cursor\]/.test(l))
            if (at < 0) lines.push("", "[cursor]", style)
            else lines.splice(at + 1, 0, style)
            return lines.join("\n")
        }, text => kvSet(text, { "cursor-style": ghosttyCursors[shape],
                                 "cursor-style-blink": blinking === "Off" || blinking === "Never" ? "false" : "true" }),
        "Cursor: " + shape + (blinking === "Off" ? "" : ", blinking"))
    }

    FileView {
        id: alacrittyFile
        path: page.alacrittyPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: ghosttyFile
        path: page.ghosttyPath
        blockLoading: true
        printErrors: false
    }

    // whether Ghostty can be picked yet: terminal.sh opens Alacritty until
    // it's installed
    property bool ghosttyInstalled: true
    Process {
        running: true
        command: ["sh", "-c", "command -v ghostty"]
        onExited: code => page.ghosttyInstalled = code === 0
    }

    // --- aliases -------------------------------------------------------------

    // [{ name, value, line }]
    property var aliases: []

    function parseAliases(text) {
        var out = []
        text.split("\n").forEach((line, i) => {
            var m = /^\s*alias\s+([A-Za-z0-9_.:-]+)=(?:'([^']*)'|"((?:[^"\\]|\\.)*)"|(\S+))\s*$/.exec(line)
            // the command as the shell would see it, quotes and escapes
            // undone, since a save writes it back single-quoted
            if (m) out.push({ name: m[1], line: i, value: m[2] !== undefined ? m[2]
                : m[3] !== undefined ? m[3].replace(/\\(["\\$`])/g, "$1")
                : m[4].replace(/\\(.)/g, "$1") })
        })
        return out
    }

    // single quotes can't hold a single quote: close, escape one, reopen
    function shQuote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    // oldName renames that alias in place, in the same write
    function addAlias(name, value, oldName) {
        name = name.trim()
        if (!/^[A-Za-z0-9_.:-]+$/.test(name)) { say("An alias name is letters, digits and _ . : - only", true); return false }
        if (value.trim() === "") { say("The alias needs a command", true); return false }
        aliasesFile.reload()
        aliasesFile.waitForJob()
        var text = aliasesFile.text()
        var lines = text.split("\n")
        var current = parseAliases(text)
        var line = "alias " + name + "=" + shQuote(value.trim())
        var existing = current.find(a => a.name === name)
        var old = oldName && oldName !== name ? current.find(a => a.name === oldName) : null
        if (existing) {
            lines[existing.line] = line
            if (old) lines.splice(old.line, 1)
        } else if (old) {
            lines[old.line] = line
        } else if (current.length > 0) {
            lines.splice(current[current.length - 1].line + 1, 0, line)
        } else {
            // before a trailing blank line, so the file still ends the same way
            var at = lines.length && lines[lines.length - 1] === "" ? lines.length - 1 : lines.length
            lines.splice(at, 0, line)
        }
        writeFile(aliasesPath, lines.join("\n"), (old ? "Renamed " + oldName + " to " + name
            : existing ? "Changed " + name : "Added " + name) + ", in new terminals", true)
        return true
    }

    function removeAlias(a) {
        aliasesFile.reload()
        aliasesFile.waitForJob()
        var lines = aliasesFile.text().split("\n")
        var fresh = parseAliases(lines.join("\n")).find(x => x.name === a.name && x.line === a.line)
        if (!fresh) { say("~/.bash_aliases changed on disk; nothing removed", true); reread(); return }
        lines.splice(a.line, 1)
        writeFile(aliasesPath, lines.join("\n"), "Removed " + a.name + ", in new terminals", true)
    }

    FileView {
        id: aliasesFile
        path: page.aliasesPath
        blockLoading: true
        printErrors: false
    }

    // --- shared --------------------------------------------------------------

    // alias files are `bash -n` checked; built from a fresh read, so not queued
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
        ghosttyFile.reload()
        ghosttyFile.waitForJob()
        kv = parseKv(ghosttyFile.text())
        aliasesFile.reload()
        aliasesFile.waitForJob()
        aliases = parseAliases(aliasesFile.text())
    }

    Component.onCompleted: reread()

    // --- layout --------------------------------------------------------------

    // the picked terminal's values, in Alacritty's words
    readonly property string cursorRaw: String(toml["cursor.style"] || "")
    readonly property string cursorShape: ghostty
        ? ({ bar: "Beam", underline: "Underline" })[kv["cursor-style"]] || "Block"
        : (/shape\s*=\s*"(\w+)"/.exec(cursorRaw) || [, "Block"])[1]
    // unset, Ghostty blinks
    readonly property string cursorBlinking: ghostty
        ? (kv["cursor-style-blink"] === "false" ? "Off" : "On")
        : (/blinking\s*=\s*"(\w+)"/.exec(cursorRaw) || [, "Off"])[1]

    readonly property real fontSize: ghostty ? Number(kv["font-size"] || 12) : Number(tomlValue("font.size", 11.25))
    // Settings' rather than the configs', so looks and styles can set it;
    // AppearanceSync writes it into the config each terminal imports
    readonly property real opacityNow: Settings.terminalOpacity / 100
    // the opacity while the level is being dragged, written on release
    property real opacityDragged: -1
    readonly property real opacityShown: opacityDragged >= 0 ? opacityDragged : opacityNow
    readonly property bool blinking: cursorBlinking === "On" || cursorBlinking === "Always"

    FlyoutHeading { text: "TERMINAL APP" }

    SettingsField {
        label: "Terminal"
        hint: page.ghostty && !page.ghosttyInstalled
            ? "Ghostty isn't installed, so Alacritty opens until it is"
            : "Opens on SUPER+Return and from the shell"
        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: Settings.choices.terminalApp.map(v => ({ value: v, text: Settings.choiceLabel(v) }))
            current: Settings.terminalApp
            onPicked: v => Settings.set("terminalApp", v)
        }
    }

    FlyoutHeading { text: page.appName.toUpperCase() }

    // the terminal as it will look: background opacity, prompt, font, cursor
    ClippingRectangle {
        id: term
        width: parent.width
        height: Theme.fit(150)
        radius: Theme.radiusInner
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.frameStroke

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: "file://" + page.home + "/.local/state/singularity/current-wallpaper"
            sourceSize.width: 640
            cache: false
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.base
            opacity: page.opacityShown
        }

        // points to pixels, as both terminals size their font
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
            text: page.appName + ", as it will look"
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
            onStepped: delta => page.setFontSize((value + delta) / 2)
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
            if (page.addAlias(nameIn.text, cmdIn.text, ed.isNew ? "" : ed.name)) ed.done()
        }
        function focusField() { (ed.isNew ? nameIn : cmdIn).forceFocus() }

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
                    if (page.openAlias === al.index) Qt.callLater(editor.focusField)
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
            if (page.addingAlias) Qt.callLater(newAlias.focusField)
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
