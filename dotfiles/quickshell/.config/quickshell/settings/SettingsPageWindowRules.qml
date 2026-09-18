// Singularity - Quickshell
// ~/.config/quickshell/SettingsPageWindowRules.qml
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
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    title: "Window Rules"
    description: "How each app's windows and popouts open, saved to ~/.config/singularity/window-rules.json. Applies to windows opened after a change."

    readonly property string rulesPath:
        (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/singularity/window-rules.json"

    // [{ label, class, title, regex, float, size, workspace (0 = any), fullscreen, pin }]
    property var rules: []
    // [{ class, title }] of the windows open right now
    property var openWindows: []

    readonly property var sizes: ["", "960 540", "1240 690"]

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
            workspace: ws >= 1 && ws <= 5 ? ws : 0,
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

    // A write already running when another change comes in would ignore
    // being started again and drop it, so the change is held and written,
    // as whatever the rules are by then, the moment the first one exits.
    function save(next, message) {
        rules = next
        writeProc.message = message
        if (writeProc.running) {
            writeProc.pending = true
            return
        }
        write()
    }

    // Resolved first: the file is a stow symlink into the repo, and moving
    // the temp file onto the link would replace the link with a plain file,
    // quietly cutting the page off from the copy the repo tracks.
    function write() {
        writeProc.command = ["sh", "-c",
            't=$(readlink -f -- "$1") && mkdir -p "${t%/*}" && printf "%s\\n" "$2" > "$t.tmp" && mv -f -- "$t.tmp" "$t" && hyprctl reload config-only >/dev/null',
            "sh", rulesPath, JSON.stringify(rules, null, 2)]
        writeProc.running = true
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

    Component.onCompleted: clientsProc.running = true

    FileView {
        path: page.rulesPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                var data = JSON.parse(text())
                page.rules = Array.isArray(data) ? data.filter(r => r && (r.class || r.title)).map(page.normalise) : []
            } catch (e) {
                page.rules = []
                page.say("window-rules.json isn't valid JSON, so no rules are shown", true)
            }
        }
    }

    Process {
        id: writeProc
        property string message: ""
        property bool pending: false
        onExited: code => {
            if (pending) {
                pending = false
                page.write()
                return
            }
            page.say(code === 0 ? message : "Couldn't write " + page.rulesPath, code !== 0)
        }
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.openWindows = JSON.parse(text).map(c => ({ class: c.class || "", title: c.title || "" }))
                } catch (e) {}
            }
        }
    }

    // windows come and go while the page is open
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: clientsProc.running = true
    }

    FlyoutHeading { text: "ADD A RULE" }

    Item {
        width: parent.width
        height: Theme.fs(26)

        FlyoutInput {
            id: classInput
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.right: addChip.left
            anchors.rightMargin: 12
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
            enabled: !writeProc.running && page.typed !== ""
            onClicked: if (page.addRule(page.typed)) classInput.text = ""
        }
    }

    Text {
        readonly property int n: page.openCount({ class: page.typed })
        x: 4
        width: parent.width - 8
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
            spacing: 4
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

    Item { width: 1; height: 8 }

    Text {
        x: 4
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
            spacing: 6

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
                    enabled: !writeProc.running
                    onClicked: page.removeRule(ruleCol.index)
                }
            }

            // what the rule actually matches, whenever the heading is a label
            // or a pattern rather than the plain class
            Text {
                x: 4
                width: parent.width - 8
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

                Row {
                    anchors.right: parent.right
                    spacing: 4
                    Repeater {
                        model: [{ label: "Auto", value: false }, { label: "Float", value: true }]
                        FlyoutChip {
                            required property var modelData
                            text: modelData.label
                            enabled: !ruleCol.rule.pin
                            selected: ruleCol.floats === modelData.value
                            onClicked: if (!selected) page.setRule(ruleCol.index, "float", modelData.value)
                        }
                    }
                }
            }

            SettingsField {
                visible: ruleCol.floats
                label: "Size"
                hint: "Natural is whatever size the app asks for"

                Row {
                    anchors.right: parent.right
                    spacing: 4
                    Repeater {
                        // the presets, plus whatever the file holds if it's none of them
                        model: page.sizes.concat(page.sizes.indexOf(ruleCol.rule.size || "") < 0 ? [ruleCol.rule.size] : [])
                        FlyoutChip {
                            required property var modelData
                            text: modelData === "" ? "Natural" : modelData.replace(" ", "×")
                            selected: (ruleCol.rule.size || "") === modelData
                            onClicked: if (!selected) page.setRule(ruleCol.index, "size", modelData)
                        }
                    }
                }
            }

            SettingsField {
                label: "Workspace"
                hint: "Where it opens; Any means wherever you are"

                Row {
                    anchors.right: parent.right
                    spacing: 4
                    Repeater {
                        model: [0, 1, 2, 3, 4, 5]
                        FlyoutChip {
                            required property var modelData
                            text: modelData === 0 ? "Any" : String(modelData)
                            selected: ruleCol.rule.workspace === modelData
                            onClicked: if (!selected) page.setRule(ruleCol.index, "workspace", modelData)
                        }
                    }
                }
            }

            SettingsField {
                label: "Open fullscreen"
                hint: "Covers the whole display, bar included"

                Row {
                    anchors.right: parent.right
                    spacing: 4
                    Repeater {
                        model: [false, true]
                        FlyoutChip {
                            required property var modelData
                            text: modelData ? "On" : "Off"
                            selected: ruleCol.rule.fullscreen === modelData
                            onClicked: if (!selected) page.setRule(ruleCol.index, "fullscreen", modelData)
                        }
                    }
                }
            }

            SettingsField {
                label: "Always on top"
                hint: "Pinned: floats above other windows and stays on every workspace"

                Row {
                    anchors.right: parent.right
                    spacing: 4
                    Repeater {
                        model: [false, true]
                        FlyoutChip {
                            required property var modelData
                            text: modelData ? "On" : "Off"
                            selected: ruleCol.rule.pin === modelData
                            onClicked: if (!selected) page.setRule(ruleCol.index, "pin", modelData)
                        }
                    }
                }
            }

            Item { width: 1; height: 8 }
        }
    }
}
