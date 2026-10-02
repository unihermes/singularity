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

    sectioned: true

    title: "Window Rules"
    description: "How each app's windows open, and each workspace's layout."


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

    // a floating window's size: natural, presets in pixels, and shares of
    // the screen ("60% 60%", which hyprland.lua turns into monitor_w*0.6)
    readonly property var sizes: ["", "640 400", "800 500", "960 540", "1240 690", "1440 900", "1600 900",
        "50% 50%", "60% 60%", "80% 80%"]
    function validSize(v) { return /^\d+%? \d+%?$/.test(v || "") }
    function sizeLabel(v) {
        if (v === "") return "Natural"
        if (v === "custom") return "Custom…"
        var p = v.split(" ")
        return p[0] === p[1] && p[0].slice(-1) === "%" ? p[0] + " of the screen" : p[0] + " × " + p[1]
    }
    function sizeHint(v) {
        return v === "" ? "Whatever the app asks for" : v.indexOf("%") >= 0 ? "A share of the screen it opens on" : "Pixels, centred"
    }

    readonly property var glyphs: ({
        drag: String.fromCodePoint(0xF01DD),
        pattern: String.fromCodePoint(0xF0451),
        rename: String.fromCodePoint(0xF03EB),
    })
    readonly property var opensHints: ({
        tiled: "Takes its place in the layout",
        float: "Floats over the others",
        full: "Covers the bar too; monocle only",
        pin: "Floats above, on every workspace",
    })

    // the rule being renamed, given a custom size, and dragged (by index);
    // the Add a rule… row open
    property int renaming: -1
    property int customFor: -1
    property int dragFrom: -1
    property int dragTo: -1
    property bool adding: false

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

    // which rule is expanded, by what it matches, so adding one on top
    // doesn't open a different one
    property string openKey: ""
    function ruleKey(rule) { return (rule.class || "") + "\n" + (rule.title || "") }

    // a search for one of a rule's settings unfolds the top rule, so there
    // is a field on screen to ring
    onHighlightChanged: {
        if (openKey === "" && rules.length > 0
                && ["Name", "Opens as", "Size", "Workspace"].indexOf(highlight) >= 0)
            openKey = ruleKey(rules[0])
    }

    // a rule's settings in one line, for its row
    function summary(rule) {
        var size = rule.size ? " " + (rule.size.split(" ")[0] === rule.size.split(" ")[1] && rule.size.indexOf("%") >= 0
            ? rule.size.split(" ")[0] : rule.size.replace(" ", "×")) : ""
        var parts = [rule.pin ? "On top" + size : rule.fullscreen ? "Fullscreen"
            : rule.float ? "Float" + size : "Tiled"]
        if (rule.workspace) parts.push("workspace " + rule.workspace)
        if (rule.fullscreen && (rule.pin || rule.float)) parts.push("fullscreen")
        return parts.join(" · ")
    }

    // the row under a point in the rules list, for a drag; -1 past the ends
    function ruleAt(y) {
        for (var i = 0; i < ruleRepeater.count; i++) {
            var it = ruleRepeater.itemAt(i)
            if (it && y >= it.y && y < it.y + it.height) return i
        }
        return y < 0 ? 0 : rules.length - 1
    }

    function moveRule(from, to) {
        var next = rules.slice()
        var r = next.splice(from, 1)[0]
        next.splice(to, 0, r)
        save(next, describe(r) + " moved " + (to < from ? "up" : "down"))
    }

    // one choice for float, fullscreen and on top, which overlap
    function setOpensAs(index, v) {
        save(rules.map((r, i) => i !== index ? r : Object.assign({}, r,
            { float: v === "float", fullscreen: v === "full", pin: v === "pin" })),
            describe(rules[index]) + " updated")
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
        if (validSize(r.size)) out.size = r.size
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
        var rule = normalise({ class: cls })
        save([rule].concat(rules), "Rule added for " + cls)
        openKey = ruleKey(rule)
        return true
    }

    function setRule(index, key, value) {
        save(rules.map((r, i) => {
            if (i !== index) return r
            var n = Object.assign({}, r)
            if (value === "" || value === undefined) delete n[key]
            else n[key] = value
            return n
        }), key !== "label" ? describe(rules[index]) + " updated"
            : value ? "Renamed to " + value : "Name cleared")
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

    FlyoutHeading { text: "RULES" + "  " + page.rules.length }

    SettingsNote { text: "Higher rules win where two disagree; drag to reorder" }

    // The rules, and the Add a rule… row under them. In a Column of their
    // own so a drag can find the row under the pointer.
    Column {
        id: rulesList
        width: parent.width

        FlyoutRow {
            visible: page.rules.length === 0
            enabled: false
            label: "No rules yet"
        }

        Repeater {
            id: ruleRepeater
            model: page.rules

            Column {
                id: ruleCol
                required property var modelData
                required property int index
                readonly property var rule: modelData
                readonly property bool expanded: page.openKey === page.ruleKey(rule)
                readonly property int open: page.openCount(rule)
                readonly property string opensAs: rule.pin ? "pin" : rule.fullscreen ? "full" : rule.float ? "float" : "tiled"

                width: parent.width

                FlyoutRow {
                    id: ruleRow
                    label: page.describe(ruleCol.rule)
                    leadingIcon: page.glyphs.drag
                    highlighted: ruleCol.expanded
                    trailing: (ruleCol.open > 0 ? ruleCol.open + " open  ·  " : "")
                        + (ruleCol.rule.regex ? page.glyphs.pattern + "  " : "")
                        + page.summary(ruleCol.rule) + "  " + (ruleCol.expanded ? "󰅀" : "󰅂")
                    onActivated: {
                        page.openKey = ruleCol.expanded ? "" : page.ruleKey(ruleCol.rule)
                        page.renaming = -1
                    }

                    // where a dragged rule would land: a line on this row's top or bottom edge
                    Rectangle {
                        visible: page.dragTo === ruleCol.index && page.dragFrom !== ruleCol.index
                        width: parent.width
                        height: Theme.indicatorWidth
                        y: page.dragTo < page.dragFrom ? 0 : parent.height - height
                        color: Theme.accent
                    }

                    // the handle: dragged up or down the list, dropped on release
                    MouseArea {
                        x: ruleRow.highlighted ? Theme.spaceM : 0
                        width: Theme.iconCell
                        height: parent.height
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        preventStealing: true
                        onPressed: page.dragFrom = ruleCol.index
                        onPositionChanged: mouse => {
                            if (pressed) page.dragTo = page.ruleAt(mapToItem(rulesList, mouse.x, mouse.y).y)
                        }
                        onReleased: {
                            if (page.dragTo >= 0 && page.dragTo !== page.dragFrom) page.moveRule(page.dragFrom, page.dragTo)
                            page.dragFrom = -1
                            page.dragTo = -1
                        }
                        onCanceled: { page.dragFrom = -1; page.dragTo = -1 }
                    }
                }

                SettingsIndent {
                    visible: ruleCol.expanded

                    // what a named or pattern rule really matches
                    SettingsField {
                        visible: !!(ruleCol.rule.regex || ruleCol.rule.title || ruleCol.rule.label)
                        label: "Matches"
                        hint: ruleCol.rule.regex ? "A pattern; edited in window-rules.json" : ""
                    }
                    Text {
                        visible: !!(ruleCol.rule.regex || ruleCol.rule.title || ruleCol.rule.label)
                        width: parent.width
                        text: {
                            var r = ruleCol.rule, parts = []
                            if (r.class) parts.push("class " + (r.regex ? "~ " : "= ") + r.class)
                            if (r.title) parts.push("title " + (r.regex ? "~ " : "= ") + r.title)
                            return parts.join("   ")
                        }
                        wrapMode: Text.WrapAnywhere
                        color: Theme.subtext
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontSmall
                    }

                    // the list's name for it, renamed in place; empty goes back to the class
                    SettingsField {
                        visible: page.renaming !== ruleCol.index
                        label: "Name"
                        hint: "What the list calls it"

                        Row {
                            anchors.right: parent.right
                            spacing: Theme.spaceS

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: page.describe(ruleCol.rule)
                                color: Theme.textStrong
                                font.family: Theme.fontText
                                font.weight: Theme.weightBody
                                font.pixelSize: Theme.fontBody
                            }
                            IconButton {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: page.glyphs.rename
                                onClicked: {
                                    page.renaming = ruleCol.index
                                    nameInput.text = ruleCol.rule.label || ""
                                    Qt.callLater(nameInput.forceFocus)
                                }
                            }
                        }
                    }

                    Item {
                        visible: page.renaming === ruleCol.index
                        width: parent.width
                        height: nameInput.implicitHeight

                        FlyoutInput {
                            id: nameInput
                            anchors.left: parent.left
                            anchors.right: nameSave.left
                            anchors.rightMargin: Theme.spaceM
                            echoPassword: false
                            placeholder: ruleCol.rule.class || ruleCol.rule.title || ""
                            hints: ["Enter save"]
                            onAccepted: nameSave.clicked()
                            onEscapePressed: page.renaming = -1
                        }
                        FlyoutChip {
                            id: nameSave
                            anchors.right: nameCancel.left
                            anchors.rightMargin: Theme.spaceS
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Save"
                            selected: true
                            onClicked: {
                                var name = nameInput.text.trim()
                                page.renaming = -1
                                if (name !== (ruleCol.rule.label || "")) page.setRule(ruleCol.index, "label", name)
                            }
                        }
                        FlyoutChip {
                            id: nameCancel
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Cancel"
                            onClicked: page.renaming = -1
                        }
                    }

                    SettingsField {
                        label: "Opens as"
                        hint: page.opensHints[ruleCol.opensAs]

                        FlyoutSegmented {
                            anchors.right: parent.right
                            fill: false
                            enabled: !AtomicFileWrite.busy
                            model: [{ value: "tiled", text: "Tiled" }, { value: "float", text: "Float" },
                                { value: "full", text: "Fullscreen" }, { value: "pin", text: "On top" }]
                            current: ruleCol.opensAs
                            onPicked: v => page.setOpensAs(ruleCol.index, v)
                        }
                    }

                    SettingsField {
                        visible: ruleCol.opensAs === "float" || ruleCol.opensAs === "pin"
                        label: "Size"
                        hint: page.sizeHint(ruleCol.rule.size || "")

                        SettingsDropdown {
                            anchors.right: parent.right
                            width: Theme.fit(200)
                            // the presets, plus a size from the file that's none of them
                            model: page.sizes.concat(page.sizes.indexOf(ruleCol.rule.size || "") < 0
                                && page.customFor !== ruleCol.index ? [ruleCol.rule.size] : []).concat(["custom"])
                            current: page.customFor === ruleCol.index ? "custom" : ruleCol.rule.size || ""
                            labelFor: v => page.sizeLabel(v)
                            onPicked: v => {
                                if (v === "custom") {
                                    page.customFor = ruleCol.index
                                    var parts = (ruleCol.rule.size || "").split(" ")
                                    customW.text = parts[0] || ""
                                    customH.text = parts[1] || ""
                                    Qt.callLater(customW.forceFocus)
                                } else {
                                    page.customFor = -1
                                    page.setRule(ruleCol.index, "size", v)
                                }
                            }
                        }
                    }

                    // a size of its own: pixels, or a percentage of the screen
                    Item {
                        visible: page.customFor === ruleCol.index && (ruleCol.opensAs === "float" || ruleCol.opensAs === "pin")
                        width: parent.width
                        height: customW.implicitHeight

                        Row {
                            anchors.right: parent.right
                            spacing: Theme.spaceM

                            FlyoutInput {
                                id: customW
                                width: Theme.fit(120)
                                echoPassword: false
                                placeholder: "width"
                                onAccepted: customApply.clicked()
                                onEscapePressed: page.customFor = -1
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "×"
                                color: Theme.subtext
                                font.family: Theme.fontText
                                font.weight: Theme.weightBody
                                font.pixelSize: Theme.fontBody
                            }
                            FlyoutInput {
                                id: customH
                                width: Theme.fit(120)
                                echoPassword: false
                                placeholder: "height"
                                onAccepted: customApply.clicked()
                                onEscapePressed: page.customFor = -1
                            }
                            FlyoutChip {
                                id: customApply
                                anchors.verticalCenter: parent.verticalCenter
                                readonly property string size: customW.text.trim() + " " + customH.text.trim()
                                text: "Apply"
                                selected: enabled
                                enabled: page.validSize(size)
                                onClicked: {
                                    if (!page.validSize(size)) return
                                    page.customFor = -1
                                    page.setRule(ruleCol.index, "size", size)
                                }
                            }
                        }
                    }

                    SettingsNote {
                        visible: page.customFor === ruleCol.index && (ruleCol.opensAs === "float" || ruleCol.opensAs === "pin")
                        text: "Pixels, or a percentage of the screen: 1000 × 70%"
                    }

                    SettingsField {
                        label: "Workspace"
                        hint: "Where it opens; Any is wherever you are"

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

                    FlyoutChip {
                        text: "󰆴 Remove rule"
                        confirmText: "Remove " + page.describe(ruleCol.rule) + "?"
                        enabled: !AtomicFileWrite.busy
                        onClicked: {
                            page.openKey = ""
                            page.removeRule(ruleCol.index)
                        }
                    }
                }
            }
        }

        // a rule for one more app: by its class, or picked from the open ones
        FlyoutRow {
            label: "Add a rule…"
            highlighted: page.adding
            trailing: "󰐕"
            onActivated: {
                page.adding = !page.adding
                if (page.adding) Qt.callLater(classInput.forceFocus)
            }
        }

        SettingsIndent {
            visible: page.adding

            Item {
                width: parent.width
                height: classInput.implicitHeight

                FlyoutInput {
                    id: classInput
                    anchors.left: parent.left
                    anchors.right: addChip.left
                    anchors.rightMargin: Theme.spaceM
                    echoPassword: false
                    placeholder: "window class, e.g. org.pwmt.zathura"
                    onAccepted: addChip.clicked()
                    onEscapePressed: page.adding = false
                }
                FlyoutChip {
                    id: addChip
                    anchors.right: addCancel.left
                    anchors.rightMargin: Theme.spaceS
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Add"
                    selected: enabled
                    enabled: !AtomicFileWrite.busy && page.typed !== ""
                    onClicked: if (page.addRule(page.typed)) { classInput.text = ""; page.adding = false }
                }
                FlyoutChip {
                    id: addCancel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Cancel"
                    onClicked: page.adding = false
                }
            }

            SettingsNote {
                readonly property int n: page.openCount({ class: page.typed })
                visible: page.typed !== ""
                text: n > 0 ? n + " open window" + (n === 1 ? "" : "s") + " match"
                    : "No open window matches; the class must be exact"
                color: n > 0 ? Theme.good : Theme.subtext
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
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WORKSPACE LAYOUTS" }

    Repeater {
        model: Settings.workspaceCount

        SettingsField {
            id: wsField
            required property int index
            readonly property string key: String(index + 1)
            readonly property string mode: page.layouts[key] || ""
            label: "Workspace " + key
            hint: mode === "monocle" ? "Always monocle" : mode === "dwindle" ? "Always tiled"
                : index === 0 ? "Kept when SUPER+M switches the rest" : "Follows SUPER+M"

            FlyoutSegmented {
                anchors.right: parent.right
                fill: false
                enabled: !AtomicFileWrite.busy
                model: [{ value: "", text: "Follow" }, { value: "monocle", text: "Monocle" }, { value: "dwindle", text: "Tiled" }]
                current: wsField.mode
                onPicked: v => page.setLayout(wsField.key, v)
            }
        }
    }
}
