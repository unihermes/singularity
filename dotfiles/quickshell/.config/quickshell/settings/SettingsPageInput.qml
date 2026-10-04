// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageInput.qml
//
// Keyboard, mouse and touchpad: the `input = { }` table in hyprland.lua, with
// changes made here kept in the state directory's hyprland.json.
//
// Every change is written to the file and followed by a config reload, which
// is what applies it -- there's no separate live path. `hyprctl keyword`
// refuses to run under the Lua config, and a reload already re-reads every
// input option, so writing first is both the only way that sticks and
// effectively instant. The writes go through HyprLuaWrite, so each one is
// syntax-checked, backed up, and checked against `hyprctl configerrors`.
//
// Values are read from the file, not from Hyprland: the page shows what's
// configured, which is what survives a restart. A key the file doesn't set
// shows Hyprland's default and is added on first change.
//
// Layouts, variants and the common XKB options are shown by name, from
// xkeyboard-config's evdev.lst; kb_layout and kb_variant are written
// together so the two comma lists can't fall out of line.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services/HyprTables.js" as HyprTables
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Input"
    description: "Keyboard, mouse and touchpad, kept on this machine."

    property var conf: ({ found: false, fields: {}, touchpad: {} })

    // Hyprland's own defaults, for keys the file leaves out
    readonly property var defaults: ({
        kb_layout: "us", kb_variant: "", kb_options: "", repeat_rate: 25, repeat_delay: 600, numlock_by_default: false,
        follow_mouse: 1, sensitivity: 0, accel_profile: "", left_handed: false,
        natural_scroll: false, disable_while_typing: true, scroll_factor: 1, tap_to_click: true,
        clickfinger_behavior: false, drag_lock: false, middle_button_emulation: false,
    })

    function field(sub, key) {
        var o = HyprLuaWrite.override(sub ? ["input", sub] : ["input"], key)
        if (o !== undefined) return { editable: true, value: o }
        var table = sub === "touchpad" ? conf.touchpad : conf.fields
        var f = table[key]
        return f === undefined ? { editable: true, value: defaults[key], unset: true } : f
    }

    function value(sub, key) { return field(sub, key).value }

    function set(sub, key, v, message) {
        HyprLuaWrite.setLocal([[sub ? ["input", sub] : ["input"], key, v]], message, page.reported)
    }

    // several keys in one write, so one reload applies them together
    function setMany(pairs, message) {
        HyprLuaWrite.setLocal(pairs.map(p => [["input"], p[0], p[1]]), message, page.reported)
    }

    function reported(ok, msg) { page.say(msg, !ok) }

    function reread() {
        luaFile.reload()
        luaFile.waitForJob()
        conf = HyprTables.readInput(luaFile.text())
        if (!conf.found) say("No input = { } table inside hl.config in hyprland.lua", true)
    }

    Component.onCompleted: {
        reread()
        xkbList.running = true
        devices.running = true
    }

    FileView {
        id: luaFile
        path: HyprLuaWrite.confPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: if (!HyprLuaWrite.busy) page.reread()
    }

    // --- layouts -------------------------------------------------------------

    // { us: "English (US)", … } and { us: [{ value, text }], … } from evdev.lst
    property var layoutNames: ({})
    property var variantsOf: ({})

    Process {
        id: xkbList
        command: ["awk", `/^! / { sec = $2; next }
            sec == "layout" && NF { n = $1; $1 = ""; sub(/^ +/, ""); print "L\\t" n "\\t" $0 }
            sec == "variant" && NF { n = $1; l = $2; sub(/:$/, "", l); $1 = $2 = ""; sub(/^ +/, ""); print "V\\t" l "\\t" n "\\t" $0 }`,
            "/usr/share/X11/xkb/rules/evdev.lst"]
        stdout: StdioCollector {
            onStreamFinished: {
                var names = {}, vars = {}
                text.split("\n").forEach(l => {
                    var f = l.split("\t")
                    if (f[0] === "L" && f.length >= 3) names[f[1]] = f[2]
                    else if (f[0] === "V" && f.length >= 4) (vars[f[1]] = vars[f[1]] || []).push({ value: f[2], text: f[3] })
                })
                page.layoutNames = names
                page.variantsOf = vars
            }
        }
    }

    function layoutName(c) { return layoutNames[c] || c }
    function variantName(c, v) {
        if (v === "") return "Standard"
        var f = (variantsOf[c] || []).find(x => x.value === v)
        return f ? f.text : v
    }

    // [{ c, v }]: kb_layout and kb_variant read side by side
    readonly property var layouts: {
        var cs = String(value("", "kb_layout")).split(",").map(s => s.trim())
        var vs = String(value("", "kb_variant")).split(",").map(s => s.trim())
        return cs.filter(c => c !== "").map((c, i) => ({ c: c, v: vs[i] || "" }))
    }

    function writeLayouts(list, message) {
        var pairs = [["kb_layout", list.map(l => l.c).join(",")],
                     ["kb_variant", list.some(l => l.v !== "") ? list.map(l => l.v).join(",") : ""]]
        // a second layout needs a key to switch to it; one layout doesn't
        var o = options
        if (list.length > 1 && o.sw === "") pairs.push(["kb_options", optionString(Object.assign({}, o, { sw: "grp:alt_shift_toggle" }))])
        else if (list.length <= 1 && o.sw !== "") pairs.push(["kb_options", optionString(Object.assign({}, o, { sw: "" }))])
        setMany(pairs, message)
    }

    property int openLayout: -1
    property bool addingLayout: false
    property string layoutQuery: ""
    readonly property int shownMatches: 6
    // names starting with the search first, then any containing it, or the code itself
    readonly property var layoutMatches: {
        if (!addingLayout) return []
        var q = layoutQuery.trim().toLowerCase()
        var all = Object.keys(layoutNames).filter(c => !layouts.some(l => l.c === c))
            .map(c => ({ c: c, name: layoutNames[c] }))
            .sort((a, b) => a.name.localeCompare(b.name))
        if (q === "") return all
        var starts = [], rest = []
        all.forEach(l => {
            var n = l.name.toLowerCase()
            if (n.startsWith(q) || l.c === q) starts.push(l)
            else if (n.indexOf(q) >= 0) rest.push(l)
        })
        return starts.concat(rest)
    }

    // --- XKB options ---------------------------------------------------------

    readonly property var capsChoices: [
        { value: "", text: "Caps Lock" }, { value: "caps:escape", text: "Escape" }, { value: "ctrl:nocaps", text: "Ctrl" },
        { value: "caps:backspace", text: "Backspace" }, { value: "caps:none", text: "Off" },
    ]
    readonly property var composeChoices: [
        { value: "", text: "None" }, { value: "compose:ralt", text: "Right Alt" },
        { value: "compose:menu", text: "Menu" }, { value: "compose:rctrl", text: "Right Ctrl" },
    ]
    readonly property var switchChoices: [
        { value: "grp:alt_shift_toggle", text: "Alt+Shift" }, { value: "grp:win_space_toggle", text: "Super+Space" },
        { value: "grp:caps_toggle", text: "Caps Lock" },
    ]

    // kb_options split into the parts named on the page and the rest
    readonly property var options: {
        var o = { caps: "", compose: "", sw: "", other: [] }
        String(value("", "kb_options")).split(",").map(s => s.trim()).filter(s => s !== "").forEach(s => {
            if (o.caps === "" && capsChoices.some(c => c.value === s)) o.caps = s
            else if (o.compose === "" && composeChoices.some(c => c.value === s)) o.compose = s
            else if (o.sw === "" && s.startsWith("grp:")) o.sw = s
            else o.other.push(s)
        })
        return o
    }
    function optionString(o) {
        return [o.caps, o.compose, o.sw].concat(o.other).filter(s => s !== "").join(",")
    }
    function setOption(part, v, message) {
        var o = Object.assign({}, options)
        o[part] = v
        set("", "kb_options", optionString(o), message)
    }

    // --- devices -------------------------------------------------------------

    property bool hasTouchpad: true

    Process {
        id: devices
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.hasTouchpad = JSON.parse(text).mice.some(m => /touchpad/i.test(m.name))
                } catch (e) {}
            }
        }
    }

    // --- pieces --------------------------------------------------------------

    component Toggle: SettingsField {
        id: tg
        property string sub: ""
        property string key: ""
        readonly property bool on: page.value(sub, key) === true

        Switch {
            anchors.right: parent.right
            checked: tg.on
            enabled: page.field(tg.sub, tg.key).editable
            onToggled: page.set(tg.sub, tg.key, !tg.on, tg.label + (tg.on ? " off" : " on"))
        }
    }

    // A level over a range in steps, written when the drag ends. `readout`
    // turns a value into the words beside it.
    component Level: SettingsField {
        id: lv
        property string sub: ""
        property string key: ""
        property real min: 0
        property real max: 1
        property real step: 0.1
        // a tick on the track at this value (the device's own speed), or NaN
        property real tickAt: NaN
        property var readout: v => String(v)
        readonly property real current: Number(page.value(sub, key))
        property real dragged: NaN
        readonly property real shown: isNaN(dragged) ? current : dragged

        function snap(v) {
            v = Math.round(v / step) * step
            return Math.round(Math.max(min, Math.min(max, v)) * 1000) / 1000
        }

        Row {
            anchors.right: parent.right
            spacing: Theme.sp(10)

            Item {
                width: Theme.fit(220)
                height: slider.height
                anchors.verticalCenter: parent.verticalCenter

                Slider {
                    id: slider
                    width: parent.width
                    enabled: page.field(lv.sub, lv.key).editable
                    value: (Math.max(lv.min, Math.min(lv.max, lv.shown)) - lv.min) / (lv.max - lv.min) * 100
                    onMoved: v => lv.dragged = lv.snap(lv.min + v / 100 * (lv.max - lv.min))
                    onReleased: {
                        var v = lv.dragged
                        lv.dragged = NaN
                        if (!isNaN(v) && Math.abs(v - lv.current) > 0.0001)
                            page.set(lv.sub, lv.key, v, lv.label + " " + lv.readout(v))
                    }
                }
                Rectangle {
                    visible: !isNaN(lv.tickAt)
                    x: parent.width * (lv.tickAt - lv.min) / (lv.max - lv.min)
                    width: Theme.borderWidth
                    height: parent.height
                    color: Theme.subtext
                    opacity: 0.7
                }
            }
            Text {
                width: Theme.fs(64)
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: lv.readout(lv.shown)
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
        }
    }

    // --- layout --------------------------------------------------------------

    FlyoutHeading { text: "KEYBOARD" }

    // each layout is a row that opens to its variant; the first is the main one
    Repeater {
        model: page.layouts

        Column {
            id: lay
            required property var modelData
            required property int index
            readonly property bool open: page.openLayout === index
            readonly property var variants: [{ value: "", text: "Standard" }].concat(page.variantsOf[modelData.c] || [])
            width: parent.width

            FlyoutRow {
                leadingIcon: "󰌌"
                label: page.layoutName(lay.modelData.c)
                note: lay.modelData.v !== "" ? page.variantName(lay.modelData.c, lay.modelData.v) : lay.modelData.c
                badge: lay.index === 0 && page.layouts.length > 1 ? "Main" : ""
                highlighted: lay.open
                trailing: lay.open ? "󰅀" : "󰅂"
                onActivated: {
                    page.addingLayout = false
                    page.openLayout = lay.open ? -1 : lay.index
                }
            }

            SettingsIndent {
                visible: lay.open

                SettingsField {
                    label: "Variant"
                    hint: lay.variants.length > 1 ? "How the keys are arranged" : "This layout has one arrangement"

                    SettingsDropdown {
                        anchors.right: parent.right
                        width: Theme.fit(260)
                        model: lay.variants.map(v => v.value)
                        labelFor: v => (lay.variants.find(x => x.value === v) || { text: v }).text
                        current: lay.modelData.v
                        onPicked: v => {
                            var list = page.layouts.slice()
                            list[lay.index] = { c: lay.modelData.c, v: v }
                            page.writeLayouts(list, page.layoutName(lay.modelData.c) + ": " + page.variantName(lay.modelData.c, v))
                        }
                    }
                }

                SettingsField {
                    visible: page.layouts.length > 1
                    label: ""
                    searchable: false

                    Row {
                        anchors.right: parent.right
                        spacing: Theme.spaceS

                        FlyoutChip {
                            visible: lay.index > 0
                            text: "Make it the main one"
                            onClicked: {
                                var list = page.layouts.slice()
                                list.splice(lay.index, 1)
                                list.unshift(lay.modelData)
                                page.openLayout = 0
                                page.writeLayouts(list, page.layoutName(lay.modelData.c) + " is the main layout")
                            }
                        }
                        FlyoutChip {
                            text: "Remove"
                            onClicked: {
                                var list = page.layouts.slice()
                                list.splice(lay.index, 1)
                                page.openLayout = -1
                                page.writeLayouts(list, page.layoutName(lay.modelData.c) + " removed")
                            }
                        }
                    }
                }
            }
        }
    }

    FlyoutRow {
        leadingIcon: "󰐕"
        label: "Add a layout…"
        highlighted: page.addingLayout
        trailing: page.addingLayout ? "󰅀" : "󰅂"
        enabled: page.field("", "kb_layout").editable && page.field("", "kb_variant").editable
        onActivated: {
            page.openLayout = -1
            page.addingLayout = !page.addingLayout
            layoutSearch.text = ""
            if (page.addingLayout) Qt.callLater(layoutSearch.forceFocus)
        }
    }

    SettingsIndent {
        visible: page.addingLayout

        FlyoutInput {
            id: layoutSearch
            echoPassword: false
            glyph: "󰍉"
            placeholder: "Search a language or a layout code"
            onTextChanged: page.layoutQuery = text
            onAccepted: if (page.layoutMatches.length > 0) layoutRows.add(page.layoutMatches[0])
            onEscapePressed: page.addingLayout = false
        }

        Repeater {
            id: layoutRows
            function add(l) {
                page.addingLayout = false
                page.writeLayouts(page.layouts.concat([{ c: l.c, v: "" }]), l.name + " added")
            }
            model: page.layoutMatches.slice(0, page.shownMatches)

            FlyoutRow {
                required property var modelData
                label: modelData.name
                note: modelData.c
                onActivated: layoutRows.add(modelData)
            }
        }

        FlyoutRow {
            visible: page.layoutMatches.length > page.shownMatches
            enabled: false
            label: "and " + (page.layoutMatches.length - page.shownMatches) + " more; type to narrow"
        }
        FlyoutRow {
            visible: page.layoutMatches.length === 0
            enabled: false
            label: "No layout matches"
        }
    }

    SettingsField {
        visible: page.layouts.length > 1
        label: "Switch layouts with"
        hint: "Press it to move to the next layout"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: page.switchChoices
            current: page.options.sw
            enabled: page.field("", "kb_options").editable
            onPicked: v => page.setOption("sw", v, "Layouts switch with " + page.switchChoices.find(c => c.value === v).text)
        }
    }

    SettingsField {
        label: "Caps Lock key"
        hint: page.options.caps === "" ? "" : "Caps Lock itself is gone"

        SettingsDropdown {
            anchors.right: parent.right
            width: Theme.fit(180)
            model: page.capsChoices.map(c => c.value)
            labelFor: v => page.capsChoices.find(c => c.value === v).text
            current: page.options.caps
            enabled: page.field("", "kb_options").editable
            onPicked: v => page.setOption("caps", v, v === "" ? "Caps Lock is Caps Lock" : "Caps Lock acts as " + page.capsChoices.find(c => c.value === v).text)
        }
    }

    SettingsField {
        label: "Compose key"
        hint: page.options.compose === "" ? "Types accents in two keys: ' e gives é" : "Then two keys: ' e gives é"

        SettingsDropdown {
            anchors.right: parent.right
            width: Theme.fit(180)
            model: page.composeChoices.map(c => c.value)
            labelFor: v => page.composeChoices.find(c => c.value === v).text
            current: page.options.compose
            enabled: page.field("", "kb_options").editable
            onPicked: v => page.setOption("compose", v, v === "" ? "No compose key" : "Compose key: " + page.composeChoices.find(c => c.value === v).text)
        }
    }

    // anything else in kb_options, as typed; the hint shows the whole string
    SettingsField {
        label: "Other XKB options"
        hint: page.optionString(page.options) !== "" ? "Written as " + page.optionString(page.options)
            : "Comma-separated, as XKB writes them"

        FlyoutInput {
            id: otherOpts
            anchors.right: parent.right
            width: Theme.fit(220)
            echoPassword: false
            placeholder: "none"
            enabled: page.field("", "kb_options").editable
            text: page.options.other.join(",")
            onAccepted: {
                var o = Object.assign({}, page.options)
                o.other = text.split(",").map(s => s.trim()).filter(s => s !== "")
                if (o.other.join(",") !== page.options.other.join(","))
                    page.set("", "kb_options", page.optionString(o), "XKB options set")
            }
            onEscapePressed: text = page.options.other.join(",")

            // typing breaks the binding; put the file's value back after
            // every re-read, which follows every write
            Connections {
                target: page
                function onConfChanged() { otherOpts.text = page.options.other.join(",") }
            }
        }
    }

    SettingsSubhead { caption: "KEY REPEAT" }

    Level {
        key: "repeat_delay"
        label: "Repeat delay"
        hint: "Held this long before it repeats"
        min: 150; max: 1000; step: 50
        readout: v => Math.round(v) + " ms"
    }
    Level {
        key: "repeat_rate"
        label: "Repeat rate"
        hint: "Then this many a second"
        min: 10; max: 80; step: 5
        readout: v => Math.round(v) + "/s"
    }

    // the shell's own key repeat is Hyprland's, so holding a key here
    // shows the two levels above as they are
    SettingsField {
        label: "Try it"
        hint: "Hold a letter down"

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceS

            FlyoutInput {
                id: tryIt
                width: Theme.fit(300)
                echoPassword: false
                placeholder: "hold a key here"
                onEscapePressed: text = ""
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "󰅖"
                onClicked: tryIt.text = ""
            }
        }
    }

    Toggle {
        key: "numlock_by_default"
        label: "Num Lock on at login"
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "MOUSE" }

    Level {
        key: "sensitivity"
        label: "Pointer speed"
        hint: current === 0 ? "The device's own speed"
            : current > 0 ? "Faster than the device's own" : "Slower than the device's own"
        min: -1; max: 1; step: 0.1
        tickAt: 0
        readout: v => (v > 0 ? "+" : v < 0 ? "−" : "") + Math.abs(v).toFixed(1)
    }

    SettingsField {
        label: "Acceleration"
        hint: ({ "": "The device's own curve", adaptive: "Faster moves go further", flat: "The pointer moves as far as the hand" })[page.value("", "accel_profile")] || ""

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: [{ text: "Default", value: "" }, { text: "Adaptive", value: "adaptive" }, { text: "Flat", value: "flat" }]
            current: page.value("", "accel_profile")
            enabled: page.field("", "accel_profile").editable
            onPicked: v => page.set("", "accel_profile", v, "Acceleration: " + (v === "" ? "default" : v))
        }
    }

    // follow_mouse 0..3: what has the keyboard (accent) and what takes the
    // wheel (dashed) when the pointer sits over the right-hand window
    readonly property var followModes: [
        { value: 0, text: "Click", hint: "Click a window to focus it" },
        { value: 1, text: "Always", hint: "Pointing at a window focuses it" },
        { value: 2, text: "Hover scrolls", hint: "Pointing scrolls it, a click focuses" },
        { value: 3, text: "Apart", hint: "A click acts there, the keyboard stays" },
    ]

    SettingsField {
        label: "Focus follows mouse"
        hint: (page.followModes.find(m => m.value === Number(page.value("", "follow_mouse"))) || { hint: "" }).hint
    }

    SettingsTiles {
        enabled: page.field("", "follow_mouse").editable
        model: page.followModes
        current: Number(page.value("", "follow_mouse"))
        onPicked: v => page.set("", "follow_mouse", v, "Focus: " + page.followModes.find(m => m.value === v).text)
        art: Component {
            Item {
                id: scene
                readonly property int mode: parent ? parent.value : 0
                width: Theme.fs(96)
                height: Theme.fs(30)

                Repeater {
                    model: 2
                    Rectangle {
                        required property int index
                        // the right-hand window is under the pointer
                        readonly property bool keyboard: index === 1 ? scene.mode === 1 : scene.mode !== 1
                        readonly property bool wheel: index === 1 && scene.mode >= 2
                        x: index === 0 ? 0 : scene.width * 0.54
                        width: scene.width * 0.46
                        height: scene.height
                        radius: Theme.radiusSmall
                        color: Theme.panel
                        border.width: keyboard ? Theme.borderWidth * 2 : wheel ? 0 : Theme.borderWidth
                        border.color: keyboard ? Theme.accent : Theme.muted

                        Rectangle {
                            x: Theme.spaceXs + 1
                            y: Theme.spaceXs
                            width: parent.width * 0.4
                            height: 2
                            radius: 1
                            color: parent.keyboard ? Theme.accent : Theme.muted
                        }

                        // dashed edge, for the window that takes the wheel
                        Canvas {
                            visible: parent.wheel
                            anchors.fill: parent
                            onPaint: {
                                var c = getContext("2d")
                                c.reset()
                                c.strokeStyle = Theme.accent
                                c.lineWidth = Theme.borderWidth
                                c.setLineDash([3, 2])
                                c.strokeRect(0.5, 0.5, width - 1, height - 1)
                            }
                        }
                    }
                }
                Text {
                    x: scene.width * 0.8
                    y: scene.height * 0.45
                    text: "󰇀"
                    color: Theme.textStrong
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontBody
                }
            }
        }
    }

    Toggle {
        key: "left_handed"
        label: "Left-handed"
        hint: "Swaps the primary and secondary buttons"
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "TOUCHPAD" }

    SettingsNote {
        visible: !page.hasTouchpad
        text: "No touchpad connected; these apply when one is"
    }

    SettingsSubhead { caption: "CLICKING" }

    Toggle {
        sub: "touchpad"; key: "tap_to_click"
        label: "Tap to click"
        hint: on ? "A light tap clicks" : "Press the pad down to click"
    }
    Toggle {
        sub: "touchpad"; key: "clickfinger_behavior"
        label: "Click by finger count"
        hint: on ? "Two fingers right-click, three middle" : "Where you press decides the button"
    }
    Toggle {
        sub: "touchpad"; key: "drag_lock"
        label: "Drag lock"
        hint: "Lifting mid-drag doesn't drop it"
    }
    Toggle {
        sub: "touchpad"; key: "middle_button_emulation"
        label: "Middle-click emulation"
        hint: "Left and right pressed together"
    }

    SettingsSubhead { caption: "SCROLLING AND TYPING" }

    Level {
        sub: "touchpad"; key: "scroll_factor"
        label: "Scroll speed"
        hint: current < 1 ? "Slower than the fingers" : current > 1 ? "Further than the fingers" : "As far as the fingers"
        min: 0.1; max: 3; step: 0.1
        tickAt: 1
        readout: v => v.toFixed(1) + "×"
    }
    Toggle {
        sub: "touchpad"; key: "natural_scroll"
        label: "Natural scrolling"
        hint: on ? "Content follows the fingers, as on a phone" : "The scroll bar follows the fingers"
    }
    Toggle {
        sub: "touchpad"; key: "disable_while_typing"
        label: "Disable while typing"
        hint: "So a palm doesn't move the pointer"
    }
}
