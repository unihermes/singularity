-- Singularity - Hyprland
-- ~/.config/hypr/window-rules.lua
--
-- The static window rules windows.lua builds on: the monocle rule, square
-- and borderless filled windows, Notes and the scratchpad, prompts, and the
-- per-app entries from Settings > Window Rules. Returns the pieces
-- windows.lua switches at runtime.

local S = require("shared")


-- Deliberately NOT suppressing maximize events (Hyprland's example config
-- does): that's what double-clicking a titlebar sends. On a floating window
-- the window.fullscreen hook turns it into a fill; see fillFloating().

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

-- A link opened from another app lands in a new Floorp tab, which Floorp
-- selects and then asks to be activated. Hyprland ignores activation
-- requests by default (misc:focus_on_activate); this honours Floorp's, so
-- its window comes to the front showing that tab.
hl.window_rule({
    name  = "floorp-focus-on-activate",
    match = { class = "^(floorp)$" },
    focus_on_activate = true,
})

-- The other way round: a download opened from the browser goes to its app,
-- which asks to be activated, and Hyprland only marks it urgent. While a
-- browser has focus, honour that request too, so an app that was already
-- open comes to the front with the file.
local BROWSER_CLASSES = { ["zen"] = true, ["zen-browser"] = true, ["floorp"] = true, ["firefox"] = true }
hl.on("window.urgent", function(win)
    local active = hl.get_active_window()
    if not win or not active or win.address == active.address then return end
    if not BROWSER_CLASSES[active.class] or BROWSER_CLASSES[win.class] then return end
    hl.dispatch(hl.dsp.focus({ window = "address:" .. win.address }))
end)

-- Monocle. Hyprland ships dwindle and master only, with no monocle layout,
-- so this emulates one: dwindle stays the underlying layout, but every
-- window that would tile is floated and sized to fill the usable area
-- instead of maximized.
--
-- Floating rather than maximized: Hyprland allows one maximized window per
-- workspace, so only the focused one could be full and switching would
-- resize. Floaters each keep their own geometry, so switching is a raise.
--
-- The "+monocle" tag (taken off again by "-monocle" on the rules below)
-- tells the window.open hook which windows it owns, without repeating
-- those rules' matches here.
local monocleRule = hl.window_rule({
    name  = "monocle",
    match = { float = false },
    float = true,
    maximize = false,
    tag = "+monocle",
})

-- The gap general.gaps_out leaves at the screen's edges, which monocle
-- windows keep clear of like tiled ones: { top, right, bottom, left }.
local function edgeGaps()
    local g = hl.get_config("general.gaps_out")
    if type(g) ~= "table" then return { top = 0, right = 0, bottom = 0, left = 0 } end
    return { top = g.top or 0, right = g.right or 0, bottom = g.bottom or 0, left = g.left or 0 }
end

-- A window that fills the screen stays square whatever the rounding
-- setting: rounded corners there would only show slivers of wallpaper
-- behind it. A fullscreen window always does; a filled floater, a maximized
-- window and a tiled one alone on its workspace only when there's no edge
-- gap -- with one, they sit inside it like any other window and keep their
-- corners.
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

-- Only a window smaller than the usable area has a border; one filling it
-- has nothing to set it apart from. A floater's border is drawn outside its
-- rect, so on a filled one it would also run a pixel past the screen's edge
-- -- onto the next display along, where two sit side by side. Floaters are
-- tagged "filled" by syncFillBorder() below; a tiled window alone on its
-- workspace, or maximized, fills the area too.
hl.window_rule({ name = "filled-borderless", match = { tag = "filled" }, border_size = 0 })
hl.window_rule({ name = "lone-tiled-borderless", match = { float = false, workspace = "w[tv1]" }, border_size = 0 })
hl.window_rule({ name = "maximized-borderless", match = { fullscreen_state_internal = 1 }, border_size = 0 })

-- The bar's standalone windows (System, Keybinds, Settings): Quickshell
-- FloatingWindows, class org.quickshell, which size themselves in QML. They
-- float centred at that size -- no size here.
--
-- maximize = false and coming *after* the monocle rule are both
-- load-bearing: at map time these aren't floating yet, so monocle matches
-- them too, and the later rule wins.
hl.window_rule({
    name     = "quickshell-windows",
    tag      = "-monocle",
    match    = { class = "^(org\\.quickshell)$", title = "negative:^(Notes)$" },
    float    = true,
    center   = true,
    maximize = false,
    -- Intentionally no size constraint — QML code defines window dimensions
})

-- The sticky notes (SUPER+N): one of the shell's windows too, but pinned so
-- it stays up across workspace switches, and opened in the top-right corner
-- instead of centred. Placed by the rule rather than moved from a
-- window.open hook: moving a pinned window as it maps crashes Hyprland.
-- A rule's position ignores the bar's reserved space, so clearing a top bar
-- takes its extent from the bar-top state file, which Quickshell rewrites
-- (and reloads this config) whenever the bar moves or changes size.
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

-- The scratchpad terminal (SUPER+grave): opens straight onto the special
-- workspace, floating and centred. Out of monocle for the same reason as the
-- shell's windows above -- its open hook would stretch it to fill the screen.
-- A dot in it: Ghostty only takes a GTK application id as its class.
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

-- Starts the terminal if it isn't running (the rule above shows it), and
-- otherwise toggles the workspace it lives on. The SUPER+grave bind hands
-- over binds.lua's terminal.
function toggleScratchpad(terminal)
    if #hl.get_windows({ class = SCRATCH_CLASS }) == 0 then
        hl.dispatch(hl.dsp.exec_cmd(terminal .. " --class " .. SCRATCH_CLASS))
    else
        hl.dispatch(hl.dsp.workspace.toggle_special("scratchpad"))
    end
end

-- Out of the scratchpad, it lands on the workspace the scratchpad was shown
-- over, which is then uncovered so the window can be seen there. Into it,
-- silently: the window just goes, rather than the scratchpad opening on it.
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

-- Prompts that come from a process of their own rather than the app asking:
-- the polkit and keyring password prompts, pinentry, the screen-share
-- picker, the file chooser portal. holdPopup below can't tell them from an
-- app's first window (nothing else shares their process), so in monocle
-- they'd fill the screen. They float centred at the size they ask for; the
-- file chooser's size comes from window-rules.json, which wins over this.
local PROMPTS = { "hyprpolkitagent", "gcr-prompter", "hyprland-share-picker",
    "xdg-desktop-portal-gtk", "xdg-desktop-portal-hyprland" }
-- pinentry's every flavour: pinentry-gtk, org.gnupg.pinentry-qt, ...
local PROMPT_CLASSES = "^(" .. table.concat(PROMPTS, "|"):gsub("%.", "\\.")
    .. "|(org\\.gnupg\\.)?pinentry-.*)$"
local function isPrompt(class)
    if not class then return false end
    for _, c in ipairs(PROMPTS) do
        if class == c then return true end
    end
    return class:match("^pinentry%-") ~= nil or class:match("^org%.gnupg%.pinentry%-") ~= nil
end
-- And any window that says it's modal (xdg-dialog-v1, or X11's
-- _NET_WM_STATE_MODAL): a dialog by its own account, whatever its title.
-- Hyprland already dims its parent and keeps clicks off it
-- (general:modal_parent_blocking, decoration:dim_modal).
for name, match in pairs({ ["system-prompts"] = { class = PROMPT_CLASSES }, ["modal-dialogs"] = { modal = true } }) do
    hl.window_rule({ name = name, tag = "-monocle", match = match, float = true, center = true, maximize = false })
    hl.window_rule({ name = name .. "-exempt", match = match, tag = "+monocle-exempt" })
    hl.window_rule({ name = name .. "-popout", match = match, tag = "+popout" })
end

-- A rule's size: "W H" in pixels, or either as a share of the screen
-- ("60%"), which Hyprland takes as monitor_w*0.6 / monitor_h*0.6.
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

-- Per-app and popout exceptions live in
-- ~/.local/state/singularity/window-rules.json, edited from Settings > Window
-- Rules; until that page first writes it, the defaults the repo ships in
-- ~/.config/singularity/window-rules.defaults.json are used instead. This
-- file keeps only the machinery the shell depends on.
--
-- Read on every load, after every rule above so an entry overrides this
-- file's defaults (the later rule wins); within the file, the entry nearer
-- the top wins.
--
-- Entries match by class, title or both, literally and whole unless
-- "regex": true, which the popout entries need. Hyprland's regex has no
-- lookaheads -- one silently never matches -- so "negative:" says "anything
-- but this". Popouts are matched by title, since dialogs inherit their
-- app's class.
--
-- JSON comes from S.decodeJson: missing or broken, the
-- rules are treated as empty rather than breaking the config.

-- Classes are matched whole and literally: "org.pwmt.zathura" must not also
-- match "orgXpwmtYzathura", so every regex metacharacter is escaped.
local function literalRegex(text)
    return (text:gsub("[%.%^%$%*%+%?%(%)%[%]%{%}%|\\]", "\\%0"))
end

-- The "fullscreen" entries' rules, which follow the layout like monocleRule:
-- { rule, app } with app the entry's appRules record, if it has one.
local fullscreenRules = {}

-- An entry that names a class and no title is an app rule: it's meant for
-- the window you open, not for the sign-in popups and dialogs the app opens
-- from it, which share its class. So it only applies while none of the app's
-- windows is open -- launching it, or opening a file in it from Thunar --
-- or for a moment after a bind or the launcher runs something (markLaunch),
-- which covers a second Thunar window. Each record is { tag, rules, held,
-- on }: every window of the app carries the tag, so the open ones can be
-- counted.
--
-- While an app rule is off, its "held" rules are on instead: the popup
-- stays out of monocle, floating at the size it asked for, centred -- in
-- dwindle it tiles as usual.
--
-- Switching a rule on re-applies its tags to every window it matches, so
-- the open hook below tags each window "app-held" or "app-opened" for which
-- side it opened on, and each side's rules don't match the other's windows.
-- Its "monocle-exempt" is set there as a plain tag, since a held rule's
-- goes when the rule is switched off.
local appRules = {}

-- A short tag name for an app rule's class, the same on every load: tags
-- outlive a reload, and the entry's position in the file can change.
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

-- In monocle only the apps listed in Window Rules as opening "As left",
-- filled the first time (an entry naming a class and no title that doesn't
-- float, pin, go fullscreen or start at its own size, "own") are filled to
-- the screen: browsers and editors. Every other window opens
-- naturally -- floating, centred, at the size it asks for. Matched by
-- Hyprland's regex, since a class can be one; SUPER+M's sweep asks the
-- "rule-fill" tag the entries' rules below put on these apps' windows.
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

-- After monocleRule and the shell's own rules, ahead of window-rules.json's
-- entries so a float or size entry still wins. The shell's windows and the
-- scratchpad are left out: they place themselves.
local NOT_NATURAL = { "(^org\\.quickshell$)", "(^" .. SCRATCH_CLASS .. "$)" }
for _, m in ipairs(fillMatch) do table.insert(NOT_NATURAL, m) end
local naturalMatch = { float = false, class = "negative:" .. table.concat(NOT_NATURAL, "|") }
local naturalRule = hl.window_rule({
    name = "monocle-natural", match = naturalMatch,
    tag = "-monocle", center = true, maximize = false,
})

do
    local rules = userRules
    -- Bottom of the file first: when two rules set the same property the
    -- one applied last wins, and the page lists newest first, so this makes
    -- "higher in the list wins" -- a rule you just added beats the defaults.
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
            -- A rule that doesn't name a class never reaches Quickshell's own
            -- windows, which size themselves in QML (the Settings window's
            -- title would otherwise match the dialog entry).
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
            -- Floating, pinned and fullscreen windows all leave monocle: its
            -- open hook would otherwise resize them to fill the screen a
            -- moment after this rule put them where they belong.
            if exempt then
                rule.tag      = "-monocle"
                rule.maximize = false
            end
            -- Pinning only applies to floating windows in Hyprland. A pinned
            -- window (picture-in-picture) keeps the spot its app chose.
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
            -- Its own rule so applyLayoutRules can switch it off in dwindle,
            -- where every window opens tiled (see keepNewWindowTiled).
            if r.fullscreen then
                table.insert(fullscreenRules, { app = app,
                    rule = hl.window_rule({ name = name .. "-fullscreen", match = appMatch, fullscreen = true }) })
            end
            -- A second rule, because one rule carries one tag: this marks the
            -- window as exempt for SUPER+M's sweep (toggleLayout), which has
            -- to decide about windows that were already open without being
            -- able to ask which rules matched them.
            local exemptRule = exempt
                and hl.window_rule({ name = name .. "-exempt", match = appMatch, tag = "+monocle-exempt" })
            -- And what the entry makes of a window, for that sweep to put it
            -- the way it would open in the layout it's switching to. Always
            -- on, unlike the app rules above, which are off while the app is
            -- open: the sweep tells an app's popups from it by "app-held".
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
}
