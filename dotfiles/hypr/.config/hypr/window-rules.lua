-- Singularity - Hyprland
-- ~/.config/hypr/window-rules.lua
--
-- The static window rules windows.lua builds on: the monocle rule, square
-- and borderless filled windows, Notes and the scratchpad, prompts, and the
-- per-app entries from Settings > Window Rules. Returns the pieces
-- windows.lua switches at runtime.

local S = require("shared")

-- Maximize events aren't suppressed: a titlebar double-click sends one, and
-- on a floater windows.lua turns it into a fill (fillFloating).

hl.window_rule({
    -- Fixes dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Steam's games (Proton ones never say so themselves) and Minecraft count
-- as games, so render.direct_scanout = 2 can hand their frames straight to
-- the screen
hl.window_rule({
    name    = "steam-games",
    match   = { class = "^(steam_app_\\d+|Minecraft.*)$" },
    content = "game",
})

-- a link from another app opens a Floorp tab and activates its window
hl.window_rule({
    name  = "floorp-focus-on-activate",
    match = { class = "^(floorp)$" },
    focus_on_activate = true,
})

-- and the other way: while a browser has focus, an app asking to be
-- activated (a download opened in it) comes to the front
local BROWSER_CLASSES = { ["zen"] = true, ["zen-browser"] = true, ["floorp"] = true, ["firefox"] = true }
hl.on("window.urgent", function(win)
    local active = hl.get_active_window()
    if not win or not active or win.address == active.address then return end
    if not BROWSER_CLASSES[active.class] or BROWSER_CLASSES[win.class] then return end
    hl.dispatch(hl.dsp.focus({ window = "address:" .. win.address }))
end)

-- Monocle, emulated: every window that would tile is floated and sized to
-- fill the usable area (floaters keep their own geometry, so switching is
-- just a raise). The "+monocle" tag marks the windows windows.lua places;
-- later rules take it off with "-monocle".
local monocleRule = hl.window_rule({
    name  = "monocle",
    match = { float = false },
    float = true,
    maximize = false,
    tag = "+monocle",
})

-- general.gaps_out at the screen's edges: { top, right, bottom, left }
local function edgeGaps()
    local g = hl.get_config("general.gaps_out")
    if type(g) ~= "table" then return { top = 0, right = 0, bottom = 0, left = 0 } end
    return { top = g.top or 0, right = g.right or 0, bottom = g.bottom or 0, left = g.left or 0 }
end

-- A window filling the screen is square; with an edge gap only fullscreen
-- ones are.
local function hasEdgeGap()
    local g = edgeGaps()
    return g.top > 0 or g.right > 0 or g.bottom > 0 or g.left > 0
end
if not hasEdgeGap() then
    hl.window_rule({ name = "filled-square", match = { tag = "filled" }, rounding = 0 })
    hl.window_rule({ name = "lone-tiled-square", match = { float = false, workspace = "w[tv1]" }, rounding = 0 })
    hl.window_rule({ name = "maximized-square", match = { fullscreen_state_internal = 1 }, rounding = 0 })
end
hl.window_rule({ name = "fullscreen-square", match = { fullscreen_state_internal = 2 }, rounding = 0 })

-- A window filling the usable area has no border (a floater's border would
-- also spill onto the next display). syncFillBorder() tags filled floaters.
hl.window_rule({ name = "filled-borderless", match = { tag = "filled" }, border_size = 0 })
hl.window_rule({ name = "lone-tiled-borderless", match = { float = false, workspace = "w[tv1]" }, border_size = 0 })
hl.window_rule({ name = "maximized-borderless", match = { fullscreen_state_internal = 1 }, border_size = 0 })

-- The shell's own windows size themselves in QML: float centred, no size.
-- Must come after the monocle rule, which also matches them at map time.
hl.window_rule({
    name     = "quickshell-windows",
    tag      = "-monocle",
    match    = { class = "^(org\\.quickshell)$", title = "negative:^(Notes)$" },
    float    = true,
    center   = true,
    maximize = false,
})

-- The phone on screen (scrcpy): floating at the phone's own shape; Phone.qml
-- sizes it and puts it in the top-right corner.
hl.window_rule({
    name     = "scrcpy",
    tag      = "-monocle",
    match    = { class = "^(scrcpy)$" },
    float    = true,
    center   = true,
    maximize = false,
})

-- Notes (SUPER+N): pinned, top-right. Placed by the rule, since moving a
-- pinned window as it maps crashes Hyprland; the rule ignores reserved
-- space, so the bar's extent comes from the bar-top state file.
local NOTES_MARGIN = 8
local function notesTop()
    return (tonumber(S.state("bar-top", "32")) or 32) + NOTES_MARGIN
end
hl.window_rule({
    name     = "notes",
    tag      = "-monocle",
    match    = { class = "^(org\\.quickshell)$", title = "^(Notes)$" },
    float    = true,
    pin      = true,
    maximize = false,
    move     = "monitor_w-window_w-" .. NOTES_MARGIN .. " " .. notesTop(),
})

-- The scratchpad terminal (SUPER+grave): floating on its special workspace.
-- Ghostty only takes a GTK app id (with a dot) as its class.
local SCRATCH_CLASS = "singularity.scratch"
hl.window_rule({
    name      = "scratchpad-terminal",
    tag       = "-monocle",
    match     = { class = "^(" .. SCRATCH_CLASS .. ")$" },
    workspace = "special:scratchpad",
    float     = true,
    center    = true,
    size      = "monitor_w*0.6 monitor_h*0.6",
    maximize  = false,
})
hl.window_rule({ name = "scratchpad-terminal-exempt", match = { class = "^(" .. SCRATCH_CLASS .. ")$" }, tag = "+monocle-exempt" })

-- Starts the scratchpad terminal, or toggles its workspace.
function toggleScratchpad(terminal)
    if #hl.get_windows({ class = SCRATCH_CLASS }) == 0 then
        hl.dispatch(hl.dsp.exec_cmd(terminal .. " --class " .. SCRATCH_CLASS))
    else
        hl.dispatch(hl.dsp.workspace.toggle_special("scratchpad"))
    end
end

-- Moves the focused window out of the scratchpad (onto the workspace it was
-- shown over) or into it, silently.
function toggleStashed()
    local win = hl.get_active_window()
    if not win or not win.workspace then return end
    local target = "address:" .. win.address
    if win.workspace.name == "special:scratchpad" then
        local mon = win.monitor
        local ws = mon and mon.active_workspace
        if not ws then return end
        hl.dispatch(hl.dsp.window.move({ workspace = ws.id, window = target }))
        if mon.active_special_workspace then
            hl.dispatch(hl.dsp.workspace.toggle_special("scratchpad"))
        end
        hl.dispatch(hl.dsp.focus({ window = target }))
    else
        hl.dispatch(hl.dsp.window.move({ workspace = "special:scratchpad", window = target, follow = false }))
    end
end

-- Prompts with a process of their own (polkit, keyring, pinentry, share
-- picker, file chooser portal): holdPopup can't tell them from an app's
-- first window, so they float centred at their own size.
local PROMPTS = { "hyprpolkitagent", "gcr-prompter", "hyprland-share-picker",
    "xdg-desktop-portal-gtk", "xdg-desktop-portal-hyprland" }
-- every pinentry flavour
local PROMPT_CLASSES = "^(" .. table.concat(PROMPTS, "|"):gsub("%.", "\\.")
    .. "|(org\\.gnupg\\.)?pinentry-.*)$"
local function isPrompt(class)
    if not class then return false end
    for _, c in ipairs(PROMPTS) do
        if class == c then return true end
    end
    return class:match("^pinentry%-") ~= nil or class:match("^org%.gnupg%.pinentry%-") ~= nil
end
-- and any window that says it's modal
for name, match in pairs({ ["system-prompts"] = { class = PROMPT_CLASSES }, ["modal-dialogs"] = { modal = true } }) do
    hl.window_rule({ name = name, tag = "-monocle", match = match, float = true, center = true, maximize = false })
    hl.window_rule({ name = name .. "-exempt", match = match, tag = "+monocle-exempt" })
    hl.window_rule({ name = name .. "-popout", match = match, tag = "+popout" })
end
-- what windows.lua's adoptDialog blocks the owner for
hl.window_rule({ name = "modal-dialogs-tag", match = { modal = true }, tag = "+modal" })

-- A rule's size: "W H" in pixels, or a share of the screen ("60%").
local function ruleSize(size)
    if type(size) ~= "string" then return nil end
    local w, h = size:match("^(%d+%%?) (%d+%%?)$")
    if not w then return nil end
    local function part(v, dim)
        local pct = v:match("^(%d+)%%$")
        return pct and (dim .. "*" .. tonumber(pct) / 100) or v
    end
    return part(w, "monitor_w") .. " " .. part(h, "monitor_h")
end

-- Per-app entries from window-rules.json (Settings > Window Rules), else
-- the shipped window-rules.defaults.json. Applied after the rules above so
-- they win; nearer the top of the file wins. Entries match class, title or
-- both, literally unless "regex": true ("negative:" for "anything but",
-- since Hyprland's regex has no lookaheads). Broken JSON reads as empty.

-- classes match whole and literally
local function literalRegex(text)
    return (text:gsub("[%.%^%$%*%+%?%(%)%[%]%{%}%|\\]", "\\%0"))
end

-- the "fullscreen" entries' rules, switched with the layout: { rule, app }
local fullscreenRules = {}

-- An entry naming a class and no title is an app rule: for the window you
-- open, not its popups. So it's on only while none of the app's windows is
-- open, or just after a launch (markLaunch). While off, its "held" rules
-- float the popups centred instead. Records are { tag, rules, held, on };
-- windows.lua tags each window "app-held" or "app-opened" by the side it
-- opened on.
local appRules = {}

-- a short stable tag for an app rule's class (tags outlive a reload)
local function classTag(class)
    local h = 5381
    for c in class:gmatch(".") do
        h = (h * 33 + c:byte()) % 4294967296
    end
    return string.format("app-%08x", h)
end

local userRules = {}
do
    local f = io.open(os.getenv("HOME") .. "/.local/state/singularity/window-rules.json")
        or io.open(os.getenv("HOME") .. "/.config/singularity/window-rules.defaults.json")
    local rules = f and S.decodeJson(f:read("a")) or {}
    if f then f:close() end
    userRules = type(rules) == "table" and rules or {}
end

-- In monocle only the "As left" apps of Window Rules (class only, not
-- float, pin, fullscreen or "own") fill the screen; every other window
-- opens naturally, floating centred at its own size.
local fillMatch = {}
for _, r in ipairs(userRules) do
    if type(r) == "table" and type(r.class) == "string" and r.class ~= ""
            and not (type(r.title) == "string" and r.title ~= "")
            and not r.float and not r.pin and not r.fullscreen and not r.own then
        if r.regex then
            table.insert(fillMatch, "(" .. r.class .. ")")
        else
            table.insert(fillMatch, "(^" .. literalRegex(r.class) .. "$)")
        end
    end
end

-- after the shell's rules, before the entries (so a float or size entry
-- still wins); the shell's windows and the scratchpad place themselves
local NOT_NATURAL = { "(^org\\.quickshell$)", "(^" .. SCRATCH_CLASS .. "$)" }
for _, m in ipairs(fillMatch) do table.insert(NOT_NATURAL, m) end
local naturalMatch = { float = false, class = "negative:" .. table.concat(NOT_NATURAL, "|") }
local naturalRule = hl.window_rule({
    name = "monocle-natural", match = naturalMatch,
    tag = "-monocle", center = true, maximize = false,
})

do
    local rules = userRules
    -- from the bottom, so the entry higher in the list is applied last and wins
    for n = #rules, 1, -1 do
        local r = rules[n]
        local match = {}
        if type(r) == "table" then
            for _, key in ipairs({ "class", "title" }) do
                if type(r[key]) == "string" and r[key] ~= "" then
                    match[key] = r.regex and r[key] or "^(" .. literalRegex(r[key]) .. ")$"
                end
            end
        end
        if next(match) then
            -- an entry with no class never matches the shell's windows
            match.class = match.class or "negative:^(org\\.quickshell)$"
            local name = "settings-rule-" .. n
            local rule = { name = name, match = match }
            local exempt = r.float or r.pin or r.fullscreen
            local app = not match.title and { tag = classTag(match.class), rules = {}, on = true } or nil
            local appMatch = match
            if app then
                appMatch = { class = match.class, tag = "negative:app-held" }
                rule.match = appMatch
            end
            -- floating, pinned and fullscreen entries leave monocle
            if exempt then
                rule.tag      = "-monocle"
                rule.maximize = false
            end
            -- a pinned window (picture-in-picture) keeps its app's spot
            if r.float or r.pin then
                rule.float  = true
                rule.center = not r.pin
                rule.size = ruleSize(r.size)
            end
            if r.pin then rule.pin = true end
            local ws = tonumber(r.workspace)
            if ws and ws >= 1 and ws <= S.maxWorkspaces then
                rule.workspace = tostring(math.floor(ws))
                -- so followOwner leaves it where the entry put it
                hl.window_rule({ name = name .. "-ws", match = match, tag = "+rule-ws" })
            end
            local applied = hl.window_rule(rule)
            -- an entry by title is for an app's popups: one icon in the bar
            if match.title then
                hl.window_rule({ name = name .. "-popout", match = match, tag = "+popout" })
            end
            -- its own rule, switched off in dwindle (applyLayoutRules)
            if r.fullscreen then
                table.insert(fullscreenRules, { app = app,
                    rule = hl.window_rule({ name = name .. "-fullscreen", match = appMatch, fullscreen = true }) })
            end
            -- exempt from SUPER+M's sweep (one rule carries one tag)
            local exemptRule = exempt
                and hl.window_rule({ name = name .. "-exempt", match = appMatch, tag = "+monocle-exempt" })
            -- what the entry makes of a window, for the sweep; always on
            local intent = (r.float or r.pin) and "rule-float" or r.fullscreen and "rule-full"
                or not match.title and not r.own and "rule-fill"
            if intent then hl.window_rule({ name = name .. "-intent", match = match, tag = "+" .. intent }) end
            if app then
                -- the fullscreen rule is switched by applyLayoutRules
                app.rules = { applied, exemptRule or nil }
                local heldMatch = { class = match.class, tag = "negative:app-opened" }
                app.held = {
                    hl.window_rule({ name = name .. "-held", match = heldMatch,
                        tag = "-monocle", maximize = false, center = true, enabled = false }),
                    hl.window_rule({ name = name .. "-held-exempt", match = heldMatch,
                        tag = "+monocle-exempt", enabled = false }),
                }
                hl.window_rule({ name = name .. "-app", match = match, tag = "+" .. app.tag })
                table.insert(appRules, app)
            end
        end
    end
end

return {
    monocleRule = monocleRule,
    edgeGaps = edgeGaps,
    SCRATCH_CLASS = SCRATCH_CLASS,
    isPrompt = isPrompt,
    fullscreenRules = fullscreenRules,
    appRules = appRules,
    naturalRule = naturalRule,
    BROWSER_CLASSES = BROWSER_CLASSES,
}
