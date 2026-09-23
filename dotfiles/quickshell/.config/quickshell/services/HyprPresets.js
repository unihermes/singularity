// Singularity - Quickshell
// ~/.config/quickshell/services/HyprPresets.js
//
// The catalogue behind the Keybinds window's Presets tab: binds worth having
// that a fresh config usually doesn't, written the way this config writes
// them, so adding one is the same edit a person would make by hand.
//
// A preset is data, not a patch. It names the combo, what it should do (a
// shell command, or a Lua dispatcher expression), the hl.bind options it
// needs, and which `-- --- Section ---` it belongs under. HyprBinds.js turns
// that into source text; this file never touches the config.
//
// Every entry is grounded in something real: a dispatcher from Hyprland's own
// Lua stubs (/usr/share/hypr/stubs/hl.meta.lua), a call already in this
// config, or a command whose tool is checked for before the preset is
// offered (`needs`).
//
// status() is what the UI colours rows by: a preset can already be in the
// config exactly as written, be in there on other keys, or want a combo
// something else has taken.

.import "HyprBinds.js" as HyprBinds

// --- the catalogue -------------------------------------------------------
//
// keys     the combo, as hl.bind() spells it
// desc     the comment the bind is written with, and the row's label
// section  the `-- --- Name ---` it goes under; made if the config lacks it
// lua      a dispatcher expression, verbatim
// cmd      a shell command, wrapped in hl.dsp.exec_cmd()
// opts     hl.bind's third argument, verbatim
// needs    binaries the command wants; missing ones grey the row out

var PACKS = [
    {
        name: "Window management",
        note: "Hyprland's own window dispatchers",
        binds: [
            { keys: "SUPER + Q", desc: "Close window", section: "Window Management",
              lua: "hl.dsp.window.close()" },
            { keys: "SUPER + SHIFT + Q", desc: "Force a stuck window to quit", section: "Window Management",
              lua: "hl.dsp.window.kill()" },
            { keys: "SUPER + CTRL + F", desc: "Fullscreen window, covering the bar", section: "Window Management",
              lua: "hl.dsp.window.fullscreen()" },
            { keys: "SUPER + X", desc: "Maximize or restore window", section: "Window Management",
              lua: "hl.dsp.window.fullscreen({ mode = \"maximized\" })" },
            { keys: "SUPER + SHIFT + V", desc: "Float or tile window", section: "Window Management",
              lua: "hl.dsp.window.float({ action = \"toggle\" })" },
            { keys: "SUPER + SHIFT + P", desc: "Pin window above every workspace", section: "Window Management",
              lua: "hl.dsp.window.pin()" },
            { keys: "SUPER + G", desc: "Centre a floating window", section: "Window Management",
              lua: "hl.dsp.window.center()" },
            { keys: "SUPER + P", desc: "Keep window's own size in its tile", section: "Window Management",
              lua: "hl.dsp.window.pseudo()" },
            { keys: "SUPER + J", desc: "Split side by side or stacked", section: "Window Management",
              lua: "hl.dsp.layout(\"togglesplit\")" },
            { keys: "SUPER + Tab", desc: "Cycle to the next window", section: "Window Management",
              lua: "hl.dsp.window.cycle_next()", opts: "{ repeating = true }" },
            { keys: "SUPER + SHIFT + T", desc: "Bring window to the top", section: "Window Management",
              lua: "hl.dsp.window.bring_to_top()" },
        ],
    },
    {
        name: "Focus and moving",
        note: "Arrows, and the vim keys beside them",
        binds: [
            { keys: "SUPER + left", desc: "Focus window to the left", section: "Focus",
              lua: "hl.dsp.focus({ direction = \"left\" })" },
            { keys: "SUPER + right", desc: "Focus window to the right", section: "Focus",
              lua: "hl.dsp.focus({ direction = \"right\" })" },
            { keys: "SUPER + up", desc: "Focus window above", section: "Focus",
              lua: "hl.dsp.focus({ direction = \"up\" })" },
            { keys: "SUPER + down", desc: "Focus window below", section: "Focus",
              lua: "hl.dsp.focus({ direction = \"down\" })" },
            { keys: "SUPER + H", desc: "Focus window to the left", section: "Focus",
              lua: "hl.dsp.focus({ direction = \"left\" })" },
            { keys: "SUPER + L", desc: "Focus window to the right", section: "Focus",
              lua: "hl.dsp.focus({ direction = \"right\" })" },
            { keys: "SUPER + K", desc: "Focus window above", section: "Focus",
              lua: "hl.dsp.focus({ direction = \"up\" })" },
            { keys: "SUPER + J", desc: "Focus window below", section: "Focus",
              lua: "hl.dsp.focus({ direction = \"down\" })" },
            { keys: "SUPER + SHIFT + left", desc: "Move window to the left", section: "Focus",
              lua: "hl.dsp.window.move({ direction = \"left\" })" },
            { keys: "SUPER + SHIFT + right", desc: "Move window to the right", section: "Focus",
              lua: "hl.dsp.window.move({ direction = \"right\" })" },
            { keys: "SUPER + SHIFT + up", desc: "Move window up", section: "Focus",
              lua: "hl.dsp.window.move({ direction = \"up\" })" },
            { keys: "SUPER + SHIFT + down", desc: "Move window down", section: "Focus",
              lua: "hl.dsp.window.move({ direction = \"down\" })" },
            { keys: "SUPER + CTRL + left", desc: "Swap window with the one to the left", section: "Focus",
              lua: "hl.dsp.window.swap({ direction = \"left\" })" },
            { keys: "SUPER + CTRL + right", desc: "Swap window with the one to the right", section: "Focus",
              lua: "hl.dsp.window.swap({ direction = \"right\" })" },
        ],
    },
    {
        name: "Workspaces",
        note: "Relative moves and the scratchpad",
        binds: [
            { keys: "SUPER + period", desc: "Go to the next workspace", section: "Workspaces",
              lua: "hl.dsp.focus({ workspace = \"e+1\" })" },
            { keys: "SUPER + comma", desc: "Go to the previous workspace", section: "Workspaces",
              lua: "hl.dsp.focus({ workspace = \"e-1\" })" },
            { keys: "SUPER + CTRL + period", desc: "Move window to the next workspace", section: "Workspaces",
              lua: "hl.dsp.window.move({ workspace = \"e+1\" })" },
            { keys: "SUPER + CTRL + comma", desc: "Move window to the previous workspace", section: "Workspaces",
              lua: "hl.dsp.window.move({ workspace = \"e-1\" })" },
            { keys: "SUPER + mouse_down", desc: "Scroll to the next workspace", section: "Workspaces",
              lua: "hl.dsp.focus({ workspace = \"e+1\" })" },
            { keys: "SUPER + mouse_up", desc: "Scroll to the previous workspace", section: "Workspaces",
              lua: "hl.dsp.focus({ workspace = \"e-1\" })" },
            { keys: "SUPER + grave", desc: "Show or hide the scratchpad", section: "Workspaces",
              lua: "hl.dsp.workspace.toggle_special(\"magic\")" },
            { keys: "SUPER + SHIFT + grave", desc: "Send window to the scratchpad", section: "Workspaces",
              lua: "hl.dsp.window.move({ workspace = \"special:magic\" })" },
        ],
    },
    {
        name: "Groups",
        note: "Tabbed stacks of windows in one tile",
        binds: [
            { keys: "SUPER + SHIFT + G", desc: "Group or ungroup the window", section: "Groups",
              lua: "hl.dsp.group.toggle()" },
            { keys: "SUPER + bracketright", desc: "Next window in the group", section: "Groups",
              lua: "hl.dsp.group.next()" },
            { keys: "SUPER + bracketleft", desc: "Previous window in the group", section: "Groups",
              lua: "hl.dsp.group.prev()" },
            { keys: "SUPER + CTRL + G", desc: "Lock the group so windows stop joining it", section: "Groups",
              lua: "hl.dsp.group.lock_active()" },
        ],
    },
    {
        name: "Sound, brightness, media",
        note: "The keys above the number row",
        binds: [
            { keys: "XF86AudioRaiseVolume", desc: "Volume up", section: "Function Keys", needs: ["wpctl"],
              cmd: "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", opts: "{ locked = true, repeating = true }" },
            { keys: "XF86AudioLowerVolume", desc: "Volume down", section: "Function Keys", needs: ["wpctl"],
              cmd: "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", opts: "{ locked = true, repeating = true }" },
            { keys: "XF86AudioMute", desc: "Mute or unmute sound", section: "Function Keys", needs: ["wpctl"],
              cmd: "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", opts: "{ locked = true }" },
            { keys: "XF86AudioMicMute", desc: "Mute or unmute microphone", section: "Function Keys", needs: ["wpctl"],
              cmd: "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", opts: "{ locked = true }" },
            { keys: "XF86MonBrightnessUp", desc: "Brightness up", section: "Function Keys", needs: ["brightnessctl"],
              cmd: "brightnessctl -n1 set 5%+", opts: "{ locked = true, repeating = true }" },
            { keys: "XF86MonBrightnessDown", desc: "Brightness down", section: "Function Keys", needs: ["brightnessctl"],
              cmd: "brightnessctl -n1 set 5%-", opts: "{ locked = true, repeating = true }" },
            { keys: "XF86AudioPlay", desc: "Play or pause", section: "Function Keys", needs: ["playerctl"],
              cmd: "playerctl play-pause", opts: "{ locked = true }" },
            { keys: "XF86AudioNext", desc: "Next track", section: "Function Keys", needs: ["playerctl"],
              cmd: "playerctl next", opts: "{ locked = true }" },
            { keys: "XF86AudioPrev", desc: "Previous track", section: "Function Keys", needs: ["playerctl"],
              cmd: "playerctl previous", opts: "{ locked = true }" },
            { keys: "SUPER + SHIFT + M", desc: "Mute or unmute sound", section: "Function Keys", needs: ["wpctl"],
              cmd: "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" },
        ],
    },
    {
        name: "Screenshots and picking",
        note: "Straight to the clipboard, or to ~/Pictures",
        binds: [
            { keys: "Print", desc: "Screenshot an area", section: "Screenshot",
              cmd: "~/.config/hypr/screenshot.sh" },
            { keys: "SHIFT + Print", desc: "Copy an area to the clipboard", section: "Screenshot",
              needs: ["grim", "slurp", "wl-copy"],
              cmd: "grim -g \"$(slurp)\" - | wl-copy" },
            { keys: "CTRL + Print", desc: "Copy the whole screen to the clipboard", section: "Screenshot",
              needs: ["grim", "wl-copy"],
              cmd: "grim - | wl-copy" },
            { keys: "SUPER + Print", desc: "Save the whole screen to ~/Pictures/Screenshots", section: "Screenshot",
              needs: ["grim"],
              cmd: "mkdir -p ~/Pictures/Screenshots && grim ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png" },
            { keys: "SUPER + SHIFT + X", desc: "Pick a colour from the screen", section: "Screenshot",
              needs: ["hyprpicker", "wl-copy"],
              cmd: "hyprpicker -a" },
        ],
    },
    {
        name: "Apps",
        note: "The usual launchers, on the usual keys",
        binds: [
            { keys: "SUPER + Return", desc: "Open terminal", section: "Launchers", cmd: "alacritty" },
            { keys: "SUPER + E", desc: "Open file manager", section: "Launchers", cmd: "thunar" },
            { keys: "SUPER + V", desc: "Open code editor", section: "Launchers", cmd: "codium" },
            { keys: "SUPER + Z", desc: "Open Zen Browser", section: "Launchers", cmd: "zen-browser" },
            { keys: "SUPER + F", desc: "Open Floorp", section: "Launchers", cmd: "floorp" },
            { keys: "SUPER + SHIFT + B", desc: "Open the system monitor", section: "Launchers",
              needs: ["btop"], cmd: "alacritty -e btop" },
        ],
    },
    {
        name: "This desktop",
        note: "Quickshell's own windows, over qs ipc",
        binds: [
            { keys: "CTRL + SPACE", desc: "Open app launcher", section: "Launchers",
              cmd: "qs ipc call launcher toggle apps" },
            { keys: "SUPER + slash", desc: "Calculator", section: "Calculator and file search",
              cmd: "qs ipc call launcher toggle calc" },
            { keys: "SUPER + S", desc: "Search files", section: "Calculator and file search",
              cmd: "qs ipc call launcher toggle files" },
            { keys: "SUPER + H", desc: "Clipboard history", section: "Clipboard",
              cmd: "qs ipc call launcher toggle clipboard" },
            { keys: "SUPER + W", desc: "Show all workspaces", section: "Window Management",
              cmd: "qs ipc call overlay toggle" },
            { keys: "SUPER + I", desc: "Ask Claude to change the desktop", section: "Claude",
              cmd: "qs ipc call claude toggle" },
            { keys: "SUPER + K", desc: "Open the keybinds window", section: "Shell",
              cmd: "qs ipc call keybinds open" },
            { keys: "SUPER + CTRL + S", desc: "Open settings", section: "Shell",
              cmd: "qs ipc call settings open general" },
            { keys: "SUPER + CTRL + I", desc: "Open the system window", section: "Shell",
              cmd: "qs ipc call system open overview" },
            { keys: "SUPER + CTRL + T", desc: "Try the next look", section: "Shell",
              cmd: "qs ipc call look cycle" },
        ],
    },
    {
        name: "Session and power",
        note: "Locking, logging out, shutting down",
        binds: [
            { keys: "SUPER + SHIFT + E", desc: "Log out", section: "Session",
              lua: "hl.dsp.exit()" },
            { keys: "SUPER + CTRL + L", desc: "Lock the screen", section: "Session",
              needs: ["hyprlock"], cmd: "hyprlock" },
            { keys: "SUPER + CTRL + BackSpace", desc: "Suspend", section: "Session",
              cmd: "systemctl suspend" },
            { keys: "SUPER + CTRL + Delete", desc: "Turn the screens off", section: "Session",
              lua: "hl.dsp.dpms(\"off\")" },
            { keys: "SUPER + CTRL + R", desc: "Reload the Hyprland config", section: "Session",
              cmd: "hyprctl reload" },
        ],
    },
]

// every binary any preset asks for, for one `command -v` sweep at load
function neededBinaries() {
    var seen = {}, out = []
    PACKS.forEach(function(p) {
        p.binds.forEach(function(b) {
            (b.needs || []).forEach(function(n) { if (!seen[n]) { seen[n] = true; out.push(n) } })
        })
    })
    return out
}

// --- matching against the config -----------------------------------------

function squash(s) {
    return String(s || "").replace(/\s+/g, " ").trim()
}

// the Lua the preset would be written as, for comparing against what's there
function actionSource(preset) {
    return preset.lua ? squash(preset.lua)
        : "hl.dsp.exec_cmd(" + JSON.stringify(String(preset.cmd)) + ")"
}

function sameAction(preset, row) {
    if (preset.lua) return squash(row.cmdSrc) === squash(preset.lua)
    return !!row.isExec && squash(row.command) === squash(preset.cmd)
}

// A stable identity for selection, since two presets can share a combo.
function id(preset) {
    return preset.keys + " " + actionSource(preset)
}

// { state, row }, where state is
//   "bound"     already there, same keys and same action -- nothing to do
//   "elsewhere" the action is in the config, on another combo
//   "taken"     the combo is used for something else
//   "new"       neither
function status(model, preset) {
    if (!model) return { state: "new", row: null }
    var norm = HyprBinds.normalizeKeys(preset.keys)
    var onKeys = null, elsewhere = null
    for (var i = 0; i < model.rows.length; i++) {
        var r = model.rows[i]
        var matches = sameAction(preset, r)
        if (r.norm === norm) {
            if (matches) return { state: "bound", row: r }
            if (!onKeys) onKeys = r
        } else if (matches && !elsewhere) {
            elsewhere = r
        }
    }
    if (onKeys) return { state: "taken", row: onKeys }
    if (elsewhere) return { state: "elsewhere", row: elsewhere }
    return { state: "new", row: null }
}

// what HyprBinds.addBind() wants
function fields(preset) {
    return {
        keys: preset.keys,
        kind: preset.lua ? "lua" : "exec",
        src: preset.lua || "",
        command: preset.cmd || "",
        desc: preset.desc,
        category: preset.section,
        opts: preset.opts || "",
    }
}
