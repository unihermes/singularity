// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageWindowRules.qml
//
// Every per-app and popout window rule: float and size, workspace,
// fullscreen and pin.
//
// Saved to ~/.config/singularity/window-rules.json -- the repo's
// dotfiles/singularity package, so the defaults (volume control, Thunar,
// file dialogs, picture-in-picture...) ship with it and show up here like
// any rule you add. hyprland.lua reads the file on every load and turns each
// entry into hl.window_rule() calls placed after its own rules; every change
// here writes the file and reloads Hyprland. Rules apply to windows as they
// open -- ones already open keep what they had until they are reopened.
// New rules go on top, and where two rules disagree the higher one wins.
//
// Rules added here match one class, literally. The shipped popout entries
// match on title patterns instead ("regex": true), which this page shows and
// keeps but doesn't edit -- that's the one thing still done in the file.

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    title: "Window Rules"
    description: "Which layout each workspace uses, and how each app's windows and popouts open. Saved to window-rules.json and workspace-layouts.json in ~/.config/singularity. Rules apply to windows opened after a change."

    readonly property string rulesPath:
        (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/singularity/window-rules.json"

    // [{ label, class, title, regex, float, size, workspace (0 = any), fullscreen, pin }]
    property var rules: []
    // [{ class, title }] of the windows open right now
    // Event-driven: shell.qml refreshes the toplevels on every window
    // open/close, so this follows windows coming and going without polling.
    readonly property var openWindows: Hyprland.toplevels.values.map(tl => ({
        class: (tl.lastIpcObject && tl.lastIpcObject.class) || "",
        title: tl.title || ""
    }))

    readonly property var sizes: ["", "960 540", "1240 690"]

    // Workspaces pinned to one layout whatever SUPER+M says, as
    // { "1": "monocle", "3": "dwindle" }. hyprland.lua reads the file on
    // load; a workspace not listed follows SUPER+M.
    readonly property string layoutsPath:
        (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/singularity/workspace-layouts.json"
    property var layouts: ({})

    // Set one workspace's pin ("" to unpin) on top of whatever the file
    // holds when the write runs, so a pin set by hand isn't lost.
    function setLayout(ws, mode) {
        var key = String(ws)
        AtomicFileWrite.write({
            path: layoutsPath,
            transform: text => {
                var cur = {}
                try { cur = text.trim() === "" ? {} : JSON.parse(text) } catch (e) { return null }
                if (typeof cur !== "object" || Array.isArray(cur)) return null
                if (mode === "") delete cur[key]
                else cur[key] = mode
                return JSON.stringify(cur, null, 2) + "\n"
            },
            refusal: "workspace-layouts.json isn't valid JSON; fix it by hand first",
            after: "hyprctl reload config-only >/dev/null",
            done: (status, detail) => {
                if (status === "ok" || status === "unchanged")
                    page.say("Workspace " + key + (mode === "" ? " follows SUPER+M"
                        : " pinned to " + (mode === "monocle" ? "monocle" : "tiled")), false)
                else page.say(status === "refused" ? detail : "Couldn't write " + page.layoutsPath, true)
                layoutsFile.reload()
            }
        })
    }

    readonly property string typed: classInput.text.trim()
    readonly property var suggestions: {
        var q = typed.toLowerCase()
        var seen = {}
        return openWindows.map(w => w.class).filter(c => {
            if (!c || seen[c] || c === "org.quickshell") return false
            seen[c] = true
            return !rules.some(r => !r.regex && r.class === c && !r.title)
                && (q === "" || c.toLowerCase().indexOf(q) >= 0)
        })
    }

    // Test one field the way Hyprland does: the whole string has to match,
    // "negative:" inverts, and an inline (?i) -- which JS regexes don't
    // take -- becomes the i flag.
    function fieldMatches(pattern, regex, value) {
        if (!pattern) return true
        if (!regex) return value === pattern
        var negative = pattern.indexOf("negative:") === 0
        var p = negative ? pattern.slice(9) : pattern
        var flags = p.indexOf("(?i)") >= 0 ? "i" : ""
        try {
            var hit = new RegExp("^(?:" + p.replace("(?i)", "") + ")$", flags).test(value)
            return negative ? !hit : hit
        } catch (e) {
            return false
        }
    }

    // A rule naming no class never reaches Quickshell's own windows --
    // hyprland.lua adds that exclusion -- so it isn't counted here either.
    function openCount(rule) {
        return openWindows.filter(w => (rule.class || w.class !== "org.quickshell")
            && fieldMatches(rule.class, rule.regex, w.class)
            && fieldMatches(rule.title, rule.regex, w.title)).length
    }

    function describe(rule) {
        return rule.label || rule.class || rule.title
    }

    function normalise(r) {
        var ws = Math.floor(Number(r.workspace) || 0)
        var out = {
            float: !!r.float,
            workspace: ws >= 1 && ws <= Settings.workspaceCount ? ws : 0,
            fullscreen: !!r.fullscreen,
            pin: !!r.pin,
        }
        // only carried when set, so the file stays as short as it was written
        if (r.label) out.label = String(r.label)
        if (r.class) out.class = String(r.class)
        if (r.title) out.title = String(r.title)
        if (r.regex) out.regex = true
        if (/^\d+ \d+$/.test(r.size || "")) out.size = r.size
        return out
    }

    // The file as the page would write it: every rule normalised, so a
    // file hand-edited into a different but equivalent shape still compares
    // equal. null for a file that won't parse.
    function parseRules(text) {
        if (text.trim() === "") return []
        try {
            var data = JSON.parse(text)
            return Array.isArray(data) ? data.filter(r => r && (r.class || r.title)).map(normalise) : null
        } catch (e) {
            return null
        }
    }

    // Each change is made against the rules the page is showing, so it only
    // goes to disk if the file still holds exactly those. A rule added by
    // hand, or a `git pull`, while the page was open used to be overwritten
    // by the next click; now that click is refused and the page reloads to
    // show what's really there. Changes queue behind each other in
    // AtomicFileWrite, and each one's `base` is the previous one's result,
    // so a quick run of clicks still lands in order.
    function save(next, message) {
        var base = JSON.stringify(rules)
        rules = next
        AtomicFileWrite.write({
            path: rulesPath,
            transform: text => {
                var onDisk = parseRules(text)
                if (onDisk === null || JSON.stringify(onDisk) !== base) return null
                return JSON.stringify(next, null, 2) + "\n"
            },
            refusal: "window-rules.json changed on disk; reloaded it, nothing written",
            after: "hyprctl reload config-only >/dev/null",
            done: (status, detail) => {
                if (status === "ok" || status === "unchanged") { page.say(message, false); return }
                page.say(status === "refused" ? detail : "Couldn't write " + page.rulesPath, true)
                rulesFile.reload()
            }
        })
    }

    function addRule(cls) {
        cls = cls.trim()
        if (cls === "") return false
        if (rules.some(r => !r.regex && r.class === cls && !r.title)) {
            say(cls + " already has a rule", true)
            return false
        }
        // on top: newest first, and nearer the top wins a conflict
        save([normalise({ class: cls })].concat(rules), "Rule added for " + cls)
        return true
    }

    function setRule(index, key, value) {
        save(rules.map((r, i) => {
            if (i !== index) return r
            var n = Object.assign({}, r)
            if (value === "" || value === undefined) delete n[key]
            else n[key] = value
            return n
        }), describe(rules[index]) + " updated")
    }

    function removeRule(index) {
        var name = describe(rules[index])
        save(rules.filter((r, i) => i !== index), "Rule for " + name + " removed")
    }

    FileView {
        id: rulesFile
        path: page.rulesPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            var parsed = page.parseRules(text())
            page.rules = parsed || []
            if (parsed === null) page.say("window-rules.json isn't valid JSON, so no rules are shown", true)
        }
    }

    FileView {
        id: layoutsFile
        path: page.layoutsPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            try { page.layouts = JSON.parse(text()) || {} } catch (e) { page.layouts = {} }
        }
        onLoadFailed: page.layouts = {}
    }

    FlyoutHeading { text: "WORKSPACE LAYOUTS" }

    Repeater {
        model: Settings.workspaceCount

        SettingsField {
            id: wsField
            required property int index
            readonly property string key: String(index + 1)
            readonly property string mode: page.layouts[key] || ""
            label: "Workspace " + key
            hint: index === 0 ? "Pinned workspaces keep their layout when SUPER+M switches the rest" : ""

            SettingsDropdown {
                anchors.right: parent.right
                enabled: !AtomicFileWrite.busy
                model: ["", "monocle", "dwindle"]
                current: wsField.mode
                labelFor: v => ({ "": "Follow SUPER+M", "monocle": "Monocle", "dwindle": "Tiled" })[v]
                onPicked: v => page.setLayout(wsField.key, v)
            }
        }
    }

    FlyoutHeading { text: "ADD A RULE" }

    Item {
        width: parent.width
        height: Theme.rowHeightTall

        FlyoutInput {
            id: classInput
            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceS
            anchors.right: addChip.left
            anchors.rightMargin: Theme.spaceXl
            anchors.verticalCenter: parent.verticalCenter
            echoPassword: false
            placeholder: "window class, e.g. org.pwmt.zathura"
            onAccepted: addChip.clicked()
        }
        FlyoutChip {
            id: addChip
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "+ Add"
            enabled: !AtomicFileWrite.busy && page.typed !== ""
            onClicked: if (page.addRule(page.typed)) classInput.text = ""
        }
    }

    Text {
        readonly property int n: page.openCount({ class: page.typed })
        x: Theme.spaceS
        width: parent.width - Theme.spaceS * 2
        visible: page.typed !== ""
        text: n > 0 ? n + " open window" + (n === 1 ? "" : "s") + " match"
            : "No open windows match -- the class has to be exact"
        color: n > 0 ? Theme.good : Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }

    SettingsField {
        visible: page.suggestions.length > 0
        label: "Open now"
        hint: "Pick an app instead of typing its class"

        Flow {
            anchors.right: parent.right
            width: parent.width
            spacing: Theme.spaceS
            layoutDirection: Qt.RightToLeft

            Repeater {
                model: page.suggestions
                FlyoutChip {
                    required property var modelData
                    text: modelData
                    onClicked: classInput.text = modelData
                }
            }
        }
    }

    Item { width: 1; height: Theme.spaceL }

    Text {
        x: Theme.spaceS
        visible: page.rules.length === 0
        text: "No rules yet."
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }

    Repeater {
        model: page.rules

        Column {
            id: ruleCol
            required property var modelData
            required property int index
            readonly property var rule: modelData
            readonly property bool floats: rule.float || rule.pin

            width: parent.width
            spacing: Theme.spaceM

            Item {
                width: parent.width
                height: Math.max(heading.implicitHeight, removeChip.height)

                FlyoutHeading {
                    id: heading
                    anchors.left: parent.left
                    anchors.right: removeChip.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.describe(ruleCol.rule).toUpperCase() + " · " + page.openCount(ruleCol.rule) + " OPEN"
                }
                FlyoutChip {
                    id: removeChip
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Remove"
                    enabled: !AtomicFileWrite.busy
                    onClicked: page.removeRule(ruleCol.index)
                }
            }

            // what the rule actually matches, whenever the heading is a label
            // or a pattern rather than the plain class
            Text {
                x: Theme.spaceS
                width: parent.width - Theme.spaceS * 2
                visible: text !== ""
                text: {
                    var r = ruleCol.rule
                    if (!r.regex && !r.title && !r.label) return ""
                    var parts = []
                    if (r.class) parts.push("class " + (r.regex ? "~ " : "= ") + r.class)
                    if (r.title) parts.push("title " + (r.regex ? "~ " : "= ") + r.title)
                    return parts.join("   ")
                }
                wrapMode: Text.WrapAnywhere
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }

            SettingsField {
                label: "Layout"
                hint: "Auto follows the current layout: full screen in monocle, tiled in dwindle"

                FlyoutSegmented {
                    anchors.right: parent.right
                    fill: false
                    model: [{ text: "Auto", value: false }, { text: "Float", value: true }]
                    enabled: !ruleCol.rule.pin
                    current: ruleCol.floats
                    onPicked: v => page.setRule(ruleCol.index, "float", v)
                }
            }

            SettingsField {
                visible: ruleCol.floats
                label: "Size"
                hint: "Natural is whatever size the app asks for"

                FlyoutSegmented {
                    anchors.right: parent.right
                    fill: false
                    // the presets, plus whatever the file holds if it's none of them
                    model: page.sizes.concat(page.sizes.indexOf(ruleCol.rule.size || "") < 0 ? [ruleCol.rule.size] : [])
                    labelFor: v => v === "" ? "Natural" : v.replace(" ", "×")
                    current: ruleCol.rule.size || ""
                    onPicked: v => page.setRule(ruleCol.index, "size", v)
                }
            }

            SettingsField {
                label: "Workspace"
                hint: "Where it opens; Any means wherever you are"

                SettingsDropdown {
                    anchors.right: parent.right
                    width: Theme.fit(160)
                    // Any, then every workspace the bar shows
                    model: [0].concat(Array.from({ length: Settings.workspaceCount }, (_, i) => i + 1))
                    current: ruleCol.rule.workspace || 0
                    labelFor: v => v === 0 ? "Any" : "Workspace " + v
                    onPicked: v => page.setRule(ruleCol.index, "workspace", v)
                }
            }

            SettingsField {
                label: "Open fullscreen"
                hint: "Covers the whole display, bar included"

                Switch {
                    anchors.right: parent.right
                    checked: ruleCol.rule.fullscreen === true
                    onToggled: page.setRule(ruleCol.index, "fullscreen", !checked)
                }
            }

            SettingsField {
                label: "Always on top"
                hint: "Pinned: floats above other windows and stays on every workspace"

                Switch {
                    anchors.right: parent.right
                    checked: ruleCol.rule.pin === true
                    onToggled: page.setRule(ruleCol.index, "pin", !checked)
                }
            }

            Item { width: 1; height: Theme.spaceL }
        }
    }
}
