// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageWindowRules.qml
//
// How each app's windows open, and its popups.
//
// Apps: every app with a rule or a size windows.lua remembers, one row each.
// An app opens As left -- the way it was last left (filled, fullscreen or
// its size; ~/.local/state/singularity/window-sizes.json), starting at its
// own size or filled the first time ("own" on its rule) -- or always Float,
// Fullscreen or On top. Popups and dialogs: the switches windows.lua reads
// from popups.json, and the rules that match windows by title.
//
// Saved to ~/.local/state/singularity/window-rules.json. Until the first
// change that file doesn't exist and the page shows the defaults the repo
// ships (volume control, Thunar, file dialogs, picture-in-picture...) from
// ~/.config/singularity/window-rules.defaults.json; the first change copies
// them into the state file with it, and from then on they are rules like any
// other. windows.lua reads the same file, with the same fallback, on every
// load and turns each entry into hl.window_rule() calls placed after its own
// rules; every change here writes the file and reloads Hyprland. Rules apply to windows as they
// open -- ones already open keep what they had until they are reopened.
// New rules go on top of the file, and where two rules disagree the higher
// one wins.
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


    readonly property string rulesPath: Settings.stateDir + "/window-rules.json"
    readonly property string defaultsPath:
        (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/singularity/window-rules.defaults.json"

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
    // the screen ("60% 60%", which windows.lua turns into monitor_w*0.6)
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
        pattern: String.fromCodePoint(0xF0451),
        rename: String.fromCodePoint(0xF03EB),
    })
    readonly property var opensHints: ({
        left: "How you last left it",
        tiled: "Fills the screen in monocle, tiles in dwindle",
        float: "Floats over the others, always this size",
        full: "Always covers the bar too; monocle only",
        pin: "Floats above, on every workspace",
    })

    // the rule being renamed and given a custom size (by index); the Add a
    // rule… row open
    property int renaming: -1
    property int customFor: -1
    property bool adding: false

    // What windows.lua remembers, by class (popups' entries are keyed
    // "popout:…" and aren't listed). Only windows.lua writes the file;
    // Forget goes through it, since it holds the sizes in memory.
    readonly property string sizesPath: Settings.stateDir + "/window-sizes.json"
    property var remembered: ({})
    function memOf(cls) {
        var e = remembered[cls]
        if (!e || typeof e !== "object") return null
        return e.normal || e.wide || e.tall || null
    }
    function memWords(m) {
        if (!m) return ""
        if (m.fullscreen) return "Fullscreen"
        if (m.fill) return "Filled"
        return Math.round(m.fw * 100) + "% × " + Math.round(m.fh * 100) + "%"
    }
    function forget(cls, name) {
        Quickshell.execDetached(["hyprctl", "eval", "forgetSize(" + JSON.stringify(cls) + ")"])
        say("Forgot how " + name + " was left", false)
    }

    // The Apps list: each class rule, then each remembered app no rule
    // matches. { index (into rules, -1 for none), cls }
    readonly property var appEntries: {
        var out = []
        rules.forEach((r, i) => { if (r.class && !r.title) out.push({ index: i, cls: r.class }) })
        Object.keys(remembered).forEach(c => {
            if (c.indexOf("popout:") === 0) return
            if (!rules.some(r => r.class && !r.title && fieldMatches(r.class, r.regex, c)))
                out.push({ index: -1, cls: c })
        })
        return out
    }
    readonly property var titleEntries: rules.map((r, i) => ({ index: i, cls: r.class || "" })).filter(e => !!rules[e.index].title)

    // The popup switches, as { block, over, remember }, each on unless false.
    readonly property string popupsPath: Settings.stateDir + "/popups.json"
    property var popupOpts: ({ block: true, over: true, remember: true })
    function setPopupOpt(key, on) {
        AtomicFileWrite.write({
            path: popupsPath,
            transform: text => {
                var cur = {}
                try { cur = text.trim() === "" ? {} : JSON.parse(text) } catch (e) { return null }
                if (typeof cur !== "object" || Array.isArray(cur)) return null
                cur[key] = on
                return JSON.stringify(cur, null, 2) + "\n"
            },
            refusal: "popups.json isn't valid JSON; fix it by hand first",
            after: "hyprctl reload config-only >/dev/null",
            done: (status, detail) => {
                if (status !== "ok" && status !== "unchanged")
                    page.say(status === "refused" ? detail : "Couldn't write " + page.popupsPath, true)
                popupsFile.reload()
            }
        })
    }

    // Workspaces pinned to one layout whatever SUPER+M says, as
    // { "1": "monocle", "3": "dwindle" }. windows.lua reads the file on
    // load; a workspace not listed follows SUPER+M.
    readonly property string layoutsPath: Settings.stateDir + "/workspace-layouts.json"
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
    // windows.lua adds that exclusion -- so it isn't counted here either.
    function openCount(rule) {
        return openWindows.filter(w => (rule.class || w.class !== "org.quickshell")
            && fieldMatches(rule.class, rule.regex, w.class)
            && fieldMatches(rule.title, rule.regex, w.title)).length
    }

    // its name, else its app's name for a plain class, else what it matches
    function describe(rule) {
        if (rule.label) return rule.label
        if (rule.class && !rule.regex && !rule.title) return Apps.nameForWindow(rule.class, "")
        return rule.class || rule.title
    }

    // which rule is expanded, by what it matches, so adding one on top
    // doesn't open a different one
    property string openKey: ""
    function ruleKey(rule) { return (rule.class || "") + "\n" + (rule.title || "") }

    // a search for one of a rule's settings unfolds the top rule, so there
    // is a field on screen to ring
    onHighlightChanged: {
        if (openKey === "" && appEntries.length > 0
                && ["Name", "Opens", "First time", "Last left", "Size", "Workspace"].indexOf(highlight) >= 0)
            openKey = entryKey(appEntries[0])
    }
    function entryKey(e) { return e.index >= 0 ? ruleKey(rules[e.index]) : "\n\n" + e.cls }

    // a rule's settings in one line, for its row
    function summary(rule) {
        var size = rule.size ? " " + (rule.size.split(" ")[0] === rule.size.split(" ")[1] && rule.size.indexOf("%") >= 0
            ? rule.size.split(" ")[0] : rule.size.replace(" ", "×")) : ""
        var parts = [rule.pin ? "On top" + size : rule.fullscreen ? "Fullscreen"
            : rule.float ? "Float" + size : rule.title ? "Fills"
            : memWords(memOf(rule.class)) || (rule.own ? "Own size" : "Fills")]
        if (rule.workspace) parts.push("workspace " + rule.workspace)
        if (rule.fullscreen && (rule.pin || rule.float)) parts.push("fullscreen")
        return parts.join(" · ")
    }

    // one choice for float, fullscreen and on top, which overlap; "left"
    // and "tiled" are none of them
    function setOpensAs(index, v) {
        save(rules.map((r, i) => i !== index ? r : Object.assign({}, r,
            { float: v === "float", fullscreen: v === "full", pin: v === "pin" })),
            describe(rules[index]) + " updated")
    }

    // A change to an app with no rule yet: the rule is made with it, As
    // left from its own size like before.
    function setEntry(e, key, value) {
        if (e.index >= 0) {
            if (key === "opens") setOpensAs(e.index, value)
            else setRule(e.index, key, value)
            return
        }
        var r = { class: e.cls, own: true }
        if (key === "opens") { r.float = value === "float"; r.fullscreen = value === "full"; r.pin = value === "pin" }
        else r[key] = value
        r = normalise(r)
        save([r].concat(rules), "Rule added for " + e.cls)
        openKey = ruleKey(r)
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
        if (r.own) out.own = true
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
        // in parseRules' shape, key order included, so the next save's
        // comparison with the file holds
        next = next.map(normalise)
        rules = next
        AtomicFileWrite.write({
            path: rulesPath,
            transform: text => {
                // no state file yet: the page was showing the defaults
                var onDisk = parseRules(text === "" ? defaultsFile.text() : text)
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
        onLoadFailed: {
            var parsed = page.parseRules(defaultsFile.text())
            page.rules = parsed || []
        }
    }

    FileView {
        id: defaultsFile
        path: page.defaultsPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: sizesFile
        path: page.sizesPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { page.remembered = JSON.parse(text()) || {} } catch (e) { page.remembered = {} }
        }
        onLoadFailed: page.remembered = {}
    }

    FileView {
        id: popupsFile
        path: page.popupsPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            var d = {}
            try { d = JSON.parse(text()) || {} } catch (e) { d = {} }
            page.popupOpts = { block: d.block !== false, over: d.over !== false, remember: d.remember !== false }
        }
        onLoadFailed: page.popupOpts = { block: true, over: true, remember: true }
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

    FlyoutHeading { text: "APPS" + "  " + page.appEntries.length }

    SettingsNote { text: "Apps with a rule or a remembered size" }

    Column {
        width: parent.width

        FlyoutRow {
            visible: page.appEntries.length === 0
            enabled: false
            label: "No apps yet"
        }

        Repeater {
            model: page.appEntries
            delegate: entryDelegate
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
    FlyoutHeading { text: "POPUPS AND DIALOGS" }

    SettingsField {
        label: "Block the window they came from"
        hint: "Until the popup is closed or made a window"

        Switch {
            anchors.right: parent.right
            checked: page.popupOpts.block
            onToggled: page.setPopupOpt("block", !page.popupOpts.block)
        }
    }
    SettingsField {
        label: "Open over their window"
        hint: "Centred on it, not the screen"

        Switch {
            anchors.right: parent.right
            checked: page.popupOpts.over
            onToggled: page.setPopupOpt("over", !page.popupOpts.over)
        }
    }
    SettingsField {
        label: "Remember their sizes"
        hint: "Per app and title, like the apps' own"

        Switch {
            anchors.right: parent.right
            checked: page.popupOpts.remember
            onToggled: page.setPopupOpt("remember", !page.popupOpts.remember)
        }
    }

    SettingsSubhead { visible: page.titleEntries.length > 0; caption: "Matched by title" }

    Column {
        width: parent.width

        Repeater {
            model: page.titleEntries
            delegate: entryDelegate
        }
    }

    // One app or title rule: its row, and its settings under it when open.
    // An app with no rule yet (only a remembered size) gets one the moment
    // anything but Forget is changed.
    Component {
        id: entryDelegate

        Column {
            id: entry
            required property var modelData
            readonly property var e: modelData
            readonly property var rule: e.index >= 0 ? page.rules[e.index] : null
            readonly property bool byTitle: !!(rule && rule.title)
            readonly property bool expanded: page.openKey === page.entryKey(e)
            readonly property int open: page.openCount(rule || { class: e.cls })
            readonly property var mem: byTitle ? null : page.memOf(e.cls)
            readonly property string opensAs: rule && rule.pin ? "pin" : rule && rule.fullscreen ? "full"
                : rule && rule.float ? "float" : byTitle ? "tiled" : "left"
            readonly property string first: rule && !rule.own ? "fill" : "own"

            width: parent.width

            FlyoutRow {
                label: entry.rule ? page.describe(entry.rule) : Apps.nameForWindow(entry.e.cls, "")
                highlighted: entry.expanded
                trailing: (entry.open > 0 ? entry.open + " open  ·  " : "")
                    + (entry.rule && entry.rule.regex ? page.glyphs.pattern + "  " : "")
                    + (entry.rule ? page.summary(entry.rule) : page.memWords(entry.mem))
                    + "  " + (entry.expanded ? "󰅀" : "󰅂")
                onActivated: {
                    page.openKey = entry.expanded ? "" : page.entryKey(entry.e)
                    page.renaming = -1
                }
            }

            SettingsIndent {
                visible: entry.expanded

                Text {
                    width: parent.width
                    text: {
                        var r = entry.rule || { class: entry.e.cls }, parts = []
                        if (r.class) parts.push("class " + (r.regex ? "~ " : "= ") + r.class)
                        if (r.title) parts.push("title " + (r.regex ? "~ " : "= ") + r.title)
                        return parts.join("   ") + (r.regex ? "  (a pattern; edited in window-rules.json)" : "")
                    }
                    wrapMode: Text.WrapAnywhere
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }

                // the list's name for it, renamed in place; empty goes back to the class
                SettingsField {
                    visible: !!entry.rule && page.renaming !== entry.e.index
                    label: "Name"
                    hint: "What the list calls it"

                    Row {
                        anchors.right: parent.right
                        spacing: Theme.spaceS

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.rule ? page.describe(entry.rule) : ""
                            color: Theme.textStrong
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontBody
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: page.glyphs.rename
                            onClicked: {
                                page.renaming = entry.e.index
                                nameInput.text = entry.rule.label || ""
                                Qt.callLater(nameInput.forceFocus)
                            }
                        }
                    }
                }

                Item {
                    visible: !!entry.rule && page.renaming === entry.e.index
                    width: parent.width
                    height: nameInput.implicitHeight

                    FlyoutInput {
                        id: nameInput
                        anchors.left: parent.left
                        anchors.right: nameSave.left
                        anchors.rightMargin: Theme.spaceM
                        echoPassword: false
                        placeholder: entry.rule ? entry.rule.class || entry.rule.title || "" : ""
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
                            if (name !== (entry.rule.label || "")) page.setRule(entry.e.index, "label", name)
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
                    label: "Opens"
                    hint: page.opensHints[entry.opensAs]

                    FlyoutSegmented {
                        anchors.right: parent.right
                        fill: false
                        enabled: !AtomicFileWrite.busy
                        model: [{ value: entry.byTitle ? "tiled" : "left", text: entry.byTitle ? "Fills" : "As left" },
                            { value: "float", text: "Float" }, { value: "full", text: "Fullscreen" }, { value: "pin", text: "On top" }]
                        current: entry.opensAs
                        onPicked: v => page.setEntry(entry.e, "opens", v)
                    }
                }

                SettingsField {
                    visible: entry.opensAs === "left"
                    label: "First time"
                    hint: "Before there's anything to remember"

                    FlyoutSegmented {
                        anchors.right: parent.right
                        fill: false
                        enabled: !AtomicFileWrite.busy
                        model: [{ value: "own", text: "Own size" }, { value: "fill", text: "Filled" }]
                        current: entry.first
                        onPicked: v => page.setEntry(entry.e, "own", v === "own" ? true : "")
                    }
                }

                SettingsField {
                    visible: entry.opensAs === "left"
                    label: "Last left"
                    hint: entry.mem ? "Opens like this next time" : "Nothing yet; how it's left is remembered"

                    Row {
                        anchors.right: parent.right
                        spacing: Theme.spaceM
                        visible: !!entry.mem

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.memWords(entry.mem)
                            color: Theme.textStrong
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontBody
                        }
                        FlyoutChip {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Forget"
                            confirmText: "Forget?"
                            onClicked: page.forget(entry.e.cls, entry.rule ? page.describe(entry.rule) : Apps.nameForWindow(entry.e.cls, ""))
                        }
                    }
                }

                SettingsField {
                    visible: entry.opensAs === "float" || entry.opensAs === "pin"
                    label: "Size"
                    hint: page.sizeHint(entry.rule ? entry.rule.size || "" : "")

                    SettingsDropdown {
                        anchors.right: parent.right
                        width: Theme.fit(200)
                        readonly property string size: entry.rule ? entry.rule.size || "" : ""
                        // the presets, plus a size from the file that's none of them
                        model: page.sizes.concat(page.sizes.indexOf(size) < 0
                            && page.customFor !== entry.e.index ? [size] : []).concat(["custom"])
                        current: page.customFor === entry.e.index ? "custom" : size
                        labelFor: v => page.sizeLabel(v)
                        onPicked: v => {
                            if (v === "custom") {
                                page.customFor = entry.e.index
                                var parts = size.split(" ")
                                customW.text = parts[0] || ""
                                customH.text = parts[1] || ""
                                Qt.callLater(customW.forceFocus)
                            } else {
                                page.customFor = -1
                                page.setEntry(entry.e, "size", v)
                            }
                        }
                    }
                }

                // a size of its own: pixels, or a percentage of the screen
                Item {
                    visible: page.customFor === entry.e.index && entry.e.index >= 0
                        && (entry.opensAs === "float" || entry.opensAs === "pin")
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
                                page.setEntry(entry.e, "size", size)
                            }
                        }
                    }
                }

                SettingsNote {
                    visible: page.customFor === entry.e.index && entry.e.index >= 0
                        && (entry.opensAs === "float" || entry.opensAs === "pin")
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
                        current: entry.rule ? entry.rule.workspace || 0 : 0
                        labelFor: v => v === 0 ? "Any" : "Workspace " + v
                        onPicked: v => page.setEntry(entry.e, "workspace", v)
                    }
                }

                FlyoutChip {
                    visible: !!entry.rule
                    text: "󰆴 Remove rule"
                    confirmText: entry.rule ? "Remove " + page.describe(entry.rule) + "?" : ""
                    enabled: !AtomicFileWrite.busy
                    onClicked: {
                        page.openKey = ""
                        page.removeRule(entry.e.index)
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
