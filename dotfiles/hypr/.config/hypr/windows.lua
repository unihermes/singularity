-- Singularity - Hyprland
-- ~/.config/hypr/windows.lua
--
-- How windows behave: the rules, the per-app entries from Settings > Window
-- Rules, the emulated monocle layout and SUPER+M, the scratchpad, tabs,
-- SUPER+X/C/D and the window keys. The functions the binds in binds.lua
-- call are globals defined here, as are the ones Quickshell runs through
-- `hyprctl eval` (singularityShowDesktop, markLaunch).

local S = require("shared")
local animOff, animFactor = S.animOff, S.animFactor
local windowAnim, windowSlides, windowShrink = S.windowAnim, S.windowSlides, S.windowShrink
local windowSpeed, fadeSpeed = S.windowSpeed, S.fadeSpeed

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

-- With no gap, a monocle window runs to the screen's edges, where rounded
-- corners would only show slivers of wallpaper and border; it stays square.
local gaps = edgeGaps()
if gaps.top == 0 and gaps.right == 0 and gaps.bottom == 0 and gaps.left == 0 then
    hl.window_rule({
        name     = "monocle-square",
        match    = { tag = "monocle" },
        rounding = 0,
    })
end

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
local SCRATCH_CLASS = "singularity-scratch"
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

do
    local f = io.open(os.getenv("HOME") .. "/.local/state/singularity/window-rules.json")
        or io.open(os.getenv("HOME") .. "/.config/singularity/window-rules.defaults.json")
    local rules = f and S.decodeJson(f:read("a")) or {}
    if f then f:close() end
    -- Bottom of the file first: when two rules set the same property the
    -- one applied last wins, and the page lists newest first, so this makes
    -- "higher in the list wins" -- a rule you just added beats the defaults.
    rules = type(rules) == "table" and rules or {}
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
            if ws and ws >= 1 and ws <= S.maxWorkspaces then rule.workspace = tostring(math.floor(ws)) end
            local applied = hl.window_rule(rule)
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

-- A window an app opens by itself -- a sign-in popup, a dialog -- comes up
-- at the size it asked for, centred, rather than filling the screen in
-- monocle: one from a process that already has a window, unless a bind or
-- the launcher has just run something (markLaunch). Any app, rule or not.
--
-- Decided once per window, as it first shows up: window.active comes ahead
-- of window.open for a window that takes focus, and these hooks are
-- registered ahead of monocle's, which would fill it. Windows open before
-- this load (a reload) are known already and left alone.
--
-- Firefox-based browsers ignore the size a page asks for and open every
-- popup at their default 1280x1040, so theirs are given one here.
local POPUP_SIZES = {
    floorp = { 960, 720 }, zen = { 960, 720 }, firefox = { 960, 720 },
}
local launchWaiting = false
local knownWindows = {}
for _, w in ipairs(hl.get_windows()) do knownWindows[w.address] = true end

local function holdPopup(win)
    if not win or knownWindows[win.address] then return end
    knownWindows[win.address] = true
    if win.class == "org.quickshell" or type(win.tags) ~= "table" then return end
    local monocle = false
    for _, t in ipairs(win.tags) do
        if t == "monocle" or t == "monocle*" then monocle = true end
    end
    if not monocle then return end
    if launchWaiting then
        launchWaiting = false
        return
    end
    for _, w in ipairs(hl.get_windows()) do
        if w.pid == win.pid and w.address ~= win.address then
            local addr = "address:" .. win.address
            -- monocleRule's tag is a rule's, so it carries the *
            hl.dispatch(hl.dsp.window.tag({ tag = "-monocle*", window = addr }))
            hl.dispatch(hl.dsp.window.tag({ tag = "+monocle-exempt", window = addr }))
            hl.dispatch(hl.dsp.window.tag({ tag = "+app-held", window = addr }))
            local size = POPUP_SIZES[win.class]
            if size then hl.dispatch(hl.dsp.window.resize({ x = size[1], y = size[2], window = addr })) end
            hl.dispatch(hl.dsp.window.center({ window = addr }))
            return
        end
    end
end
hl.on("window.active", function() holdPopup(hl.get_active_window()) end)
hl.on("window.open", holdPopup)
hl.on("window.close", function(win) if win then knownWindows[win.address] = nil end end)

-- The global layout mode, toggled by SUPER+M. Kept in a runtime file so a
-- reload (which the Appearance page does for most of its settings) doesn't
-- drop a tiled session back into monocle with its windows still tiled --
-- they'd sit under every monocle floater and ALT+Tab couldn't raise them.
-- Back to monocle at login.
--
-- The rest of monocle is hooks, run in-process on Hyprland's event thread so
-- no other event can land mid-way: window.open sizes each new window,
-- window.active (maximizeFocused) keeps whatever you land on full and on top.
local LAYOUT_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/singularity-layout"
local monocleEnabled = true
do
    local f = io.open(LAYOUT_FILE)
    if f then
        monocleEnabled = f:read("l") ~= "dwindle"
        f:close()
    end
end

-- Workspaces pinned to one layout whatever SUPER+M says, from
-- ~/.local/state/singularity/workspace-layouts.json -- { "1": "monocle",
-- "3": "dwindle" } -- which the Settings window's Window Rules page writes.
-- Anything not listed follows monocleEnabled. Read on every load, like
-- window-rules.json.
local workspaceLayouts = {}
do
    local f = io.open(os.getenv("HOME") .. "/.local/state/singularity/workspace-layouts.json")
    local pins = f and S.decodeJson(f:read("a")) or {}
    if f then f:close() end
    if type(pins) == "table" then
        for ws, mode in pairs(pins) do
            if mode == "monocle" or mode == "dwindle" then workspaceLayouts[tostring(ws)] = mode end
        end
    end
end

-- Whether monocle applies on this workspace: its pin, else the global mode.
local function monocleOn(ws)
    local pin = ws and workspaceLayouts[tostring(ws.id)]
    if pin then return pin == "monocle" end
    return monocleEnabled
end

-- Per-window state this config keeps on top of Hyprland's own, by address:
--   small     -- unmaximized on purpose (SUPER+equal), so refocusing it does
--                not immediately undo the choice; see toggleMaximize() below
--   minimized -- the {x, y, w, h} SUPER+C hid it from, and whether it was
--                tiled (and fullscreen) before being floated to hide it;
--                see toggleMinimize() below
--   hideGen   -- bumped by every hide and restore, so a hide's delayed
--                second step skips a window brought back in the meantime
--   restore   -- the {x, y, w, h} a non-monocle floater had before it was
--                filled; see fillFloating() below
-- Cleared by a window.close hook further down: Hyprland reuses addresses,
-- so leftovers would land on some later window.
local windowState = {}
local function stateOf(addr)
    local st = windowState[addr]
    if not st then
        st = {}
        windowState[addr] = st
    end
    return st
end

-- SUPER+C also writes what it saved to a tag on the window, since
-- windowState doesn't survive a config reload and the Appearance page
-- reloads for most of its settings. A window hidden across one would
-- otherwise never come back. Tags set by dispatch outlive a reload.
local function minimizedTag(m)
    return string.format("minimized_%d_%d_%d_%d_%d_%d",
        m.x, m.y, m.w, m.h, m.tiled and 1 or 0, m.fullscreen)
end

local function setProp(addr, prop, value)
    hl.dispatch(hl.dsp.window.set_prop({ prop = prop, value = value, window = addr }))
end

-- Sizes and places a floater at r = {x, y, w, h}: animated with the
-- windows curve, or in one jump. Hyprland reads no_anim when it next draws,
-- not when the move is dispatched, so the jump holds it for a moment before
-- clearing it and calling andThen, which may animate again.
local function moveTo(addr, r)
    hl.dispatch(hl.dsp.window.resize({ x = r.w, y = r.h, window = addr }))
    hl.dispatch(hl.dsp.window.move({ x = r.x, y = r.y, window = addr }))
end
local function jumpTo(addr, r, andThen)
    setProp(addr, "no_anim", "1")
    moveTo(addr, r)
    hl.timer(function()
        setProp(addr, "no_anim", "0")
        if andThen then andThen() end
    end, { timeout = 30, type = "oneshot" })
end

-- Calls fn once an animation of the given speed has played out.
local function afterAnimation(speed, fn)
    if animOff then
        fn()
    else
        hl.timer(fn, { timeout = math.floor(speed * 100 * animFactor), type = "oneshot" })
    end
end

-- r at the window style's starting size (windowShrink), around the same
-- centre.
local function shrunk(r)
    local w, h = math.floor(r.w * windowShrink[1]), math.floor(r.h * windowShrink[2])
    return { x = r.x + (r.w - w) // 2, y = r.y + (r.h - h) // 2, w = w, h = h }
end

-- Puts a SUPER+C-hidden window back where it was and forgets it was
-- hidden: slid back, or faded in where it was (growing from windowShrink
-- for the styles that have one), and tiled again if it was tiled.
local function restoreMinimized(win)
    local st = stateOf(win.address)
    local saved = st.minimized
    st.minimized = nil
    st.hideGen = (st.hideGen or 0) + 1
    local gen = st.hideGen
    local addr = "address:" .. win.address
    hl.dispatch(hl.dsp.window.tag({ tag = "-" .. minimizedTag(saved), window = addr }))
    -- hidden by show desktop: the bar's button reads the tag
    for _, t in ipairs(type(win.tags) == "table" and win.tags or { win.tags }) do
        if t == "showdesktop" then
            hl.dispatch(hl.dsp.window.tag({ tag = "-showdesktop", window = addr }))
            hl.dispatch(hl.dsp.exec_cmd("qs ipc call desktop changed"))
            break
        end
    end

    -- skipped if it was hidden again, or closed, in the meantime
    local function current()
        return windowState[win.address] == st and st.hideGen == gen
    end
    -- Tiled again only once it has arrived: a maximized window hides the
    -- rest of the workspace, which would otherwise vanish while it's still
    -- fading in.
    local function retile()
        if not current() then return end
        hl.dispatch(hl.dsp.window.float({ action = "disable", window = addr }))
        if saved.fullscreen ~= 0 then
            hl.dispatch(hl.dsp.window.fullscreen({
                mode = saved.fullscreen == 1 and "maximized" or "fullscreen", action = "set", window = addr }))
        end
    end
    local function show()
        if not current() then return end
        if windowAnim ~= "fade" then moveTo(addr, saved) end
        -- slide too: the window may have been hidden under another style
        setProp(addr, "opacity", "1")
        if saved.tiled then afterAnimation(windowSpeed, retile) end
    end

    if windowSlides then
        show()
    else
        jumpTo(addr, windowShrink and shrunk(saved) or saved, show)
    end
end

-- The monitor's usable rect (its resolution minus what the bar and other
-- layer surfaces reserve), in the logical pixels of win.size/win.at. x/y
-- are absolute layout coordinates -- the monitor's origin plus its reserved
-- edge -- since window.move places windows in the whole layout.
local function usableArea(mon)
    local reserved = mon.reserved or { left = 0, top = 0, right = 0, bottom = 0 }
    return {
        x = (mon.x or 0) + reserved.left,
        y = (mon.y or 0) + reserved.top,
        w = mon.width / mon.scale - reserved.left - reserved.right,
        h = mon.height / mon.scale - reserved.top - reserved.bottom,
    }
end

-- The rect a monocle window fills: the usable area inside the edge gaps,
-- less a strip along the top for the tab bar when the window is one of a
-- group's tabs.
local function fillArea(win, mon)
    local area = usableArea(mon)
    local g = edgeGaps()
    area.x = area.x + g.left
    area.y = area.y + g.top
    area.w = area.w - g.left - g.right
    area.h = area.h - g.top - g.bottom
    if win.group then
        local bar = S.GROUPBAR_HEIGHT
        area.y = area.y + bar
        area.h = area.h - bar
    end
    return area
end

-- Whether a floater fills the monitor it is on: position as well as size,
-- unlike isAlreadyFull(), since the right size on the wrong screen isn't.
local function isFitted(win, area)
    return math.abs(win.size.x - area.w) <= 4 and math.abs(win.size.y - area.h) <= 4
        and math.abs(win.at.x - area.x) <= 4 and math.abs(win.at.y - area.y) <= 4
end

local function isAlreadyFull(win, mon)
    local area = usableArea(mon)
    local w, h = win.size.x, win.size.y
    return math.abs(w - area.w) <= 4 and math.abs(h - area.h) <= 4
end

-- True if `win` carries the Hyprland tag `name`. A tag set by a window rule
-- comes back with a trailing "*" (dynamic) and one set by dispatch without;
-- both count.
local function hasTag(win, name)
    if not win.tags then return false end
    if type(win.tags) == "table" then
        for _, t in ipairs(win.tags) do
            if t == name or t == name .. "*" then return true end
        end
        return false
    end
    return win.tags == name or win.tags == name .. "*"
end

-- Windows SUPER+M's sweep (toggleLayout) must leave floating when monocle
-- comes back on. It can't rely on the "monocle" tag -- windows open since
-- dwindle mode never got one -- so it asks the "monocle-exempt" tag the
-- window-rules.json entries add, plus Quickshell's own windows, whose rule
-- is part of this file's machinery rather than that list.
local function isMonocleExempt(win)
    return win.class == "org.quickshell" or hasTag(win, "monocle-exempt")
end

-- Fills `win` to the monitor's usable rect without touching its floating
-- state -- callers decide whether it needs floating first.
local function sizeToFullFloat(win, mon)
    mon = mon or win.monitor or hl.get_active_monitor()
    if not mon then return end
    local area = fillArea(win, mon)
    local addr = "address:" .. win.address
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(area.w), y = math.floor(area.h), window = addr }))
    hl.dispatch(hl.dsp.window.move({ x = math.floor(area.x), y = math.floor(area.y), window = addr }))
end

-- A floating window is maximized by filling the usable area, never with
-- Hyprland's maximized flag: a floater carrying that flag ignores
-- bring_to_top and window.move, so ALT+Tab left it covered and SUPER+C
-- couldn't hide it. The flag is taken off wherever it turns up (the
-- window.fullscreen hook, and on focus as a backstop) -- SUPER+X, a titlebar
-- double-click, an app asking for it -- and the window filled instead.
-- Filling remembers the geometry it had, which toggleMaximize() puts back.
--
-- Returns the window re-read, since its geometry has changed.
local function fillFloating(win)
    local addr = "address:" .. win.address
    local st = stateOf(win.address)
    if hasTag(win, "monocle") then
        st.small = nil
    elseif not st.restore then
        st.restore = { x = win.at.x, y = win.at.y, w = win.size.x, h = win.size.y }
    end
    sizeToFullFloat(win)
    hl.dispatch(hl.dsp.window.bring_to_top({ window = addr }))
    -- by selector: hl.get_window() returns nil for a bare address
    return hl.get_window(addr) or win
end

local function unflagFloating(win)
    if not (win and win.floating and win.fullscreen == 1) then return win end
    local addr = "address:" .. win.address
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset", window = addr }))
    win = hl.get_window(addr) or win
    -- Quickshell's own windows size themselves in QML; just unflag them
    if win.class == "org.quickshell" then return win end
    return fillFloating(win)
end
hl.on("window.fullscreen", function(win) unflagFloating(win) end)

-- Moves one window into or out of monocle. SUPER+M's sweep, and any window
-- that lands on a workspace whose layout isn't the one the rules were set
-- for when it mapped (see applyLayoutRules below). Windows opened before
-- monocle was ever turned on have no "monocle" tag yet (the rule was
-- disabled when they mapped), so going into monocle falls back to the
-- exemption list for those; going out can trust the tag, since anything
-- wearing it was floated by this same machinery at some point.
local function setWindowMonocle(w, on, mon)
    local addr = "address:" .. w.address
    if on then
        -- class "" is a window that hasn't said what it is yet; leave it
        if not w.floating and w.class and w.class ~= "" and not isMonocleExempt(w) then
            hl.dispatch(hl.dsp.window.float({ action = "enable", window = addr }))
            hl.dispatch(hl.dsp.window.tag({ tag = "+monocle", window = addr }))
            sizeToFullFloat(w, mon)
        end
    elseif w.floating and hasTag(w, "monocle") then
        hl.dispatch(hl.dsp.window.float({ action = "disable", window = addr }))
        hl.dispatch(hl.dsp.window.tag({ tag = "-monocle", window = addr }))
        stateOf(w.address).small = nil
    end
end

-- In monocle right now: floated by the monocle machinery. The tag alone
-- isn't enough -- monocleRule's tag is re-applied whenever Hyprland
-- re-evaluates a window's rules, so a tiled window on a workspace pinned to
-- dwindle can pick it up while monocle is the active workspace's layout.
-- Floating isn't re-applied that way; it's set once, at map time.
local function isMonocleWin(w)
    return w.floating and hasTag(w, "monocle")
end

-- Sizes every window the monocle rule just floated, once, as it maps, so
-- switching to it later is just a raise. Uses the window window.open hands
-- over, not hl.get_active_window(), which can still be the previous window
-- when a second one opens.
local function onMonocleOpen(win)
    if not win then return end
    -- The rules follow the *active* workspace's layout, so a window that
    -- mapped somewhere else (a window-rules.json workspace entry, an app
    -- restoring its own session) can come up in the wrong one.
    --
    -- Only then: on the active workspace the rules were right, and a
    -- window's state isn't settled yet (Quickshell's windows map before
    -- their class and float land, and looked like tiled apps).
    local on = monocleOn(win.workspace)
    local active = hl.get_active_workspace()
    local elsewhere = win.workspace and active and win.workspace.id ~= active.id
    if elsewhere and on ~= isMonocleWin(win) and not (on and isMonocleExempt(win)) then
        setWindowMonocle(win, on, win.monitor)
        return
    end
    -- Only the windows monocleRule floated. Exempt ones -- Quickshell's own
    -- Settings/System/Keybinds windows, window-rules.json entries -- keep
    -- the size they open at.
    if on and hasTag(win, "monocle") then sizeToFullFloat(win) end
end
hl.on("window.open", onMonocleOpen)

-- In dwindle every window opens tiled, including one that asks to open
-- maximized or fullscreen (an app restoring how it was last closed). Apps
-- ask as they map or a moment after, so for its first second and a half a
-- tiled window's maximize or fullscreen is undone. Taking it out of the
-- tiling afterwards is left to SUPER+X, SUPER+CTRL+F and SUPER+SHIFT+V.
local justOpened = {}
local function keepNewWindowTiled(win)
    if not (win and justOpened[win.address]) then return end
    if win.floating or win.fullscreen == 0 or monocleOn(win.workspace) then return end
    hl.dispatch(hl.dsp.window.fullscreen({
        mode = win.fullscreen == 1 and "maximized" or "fullscreen", action = "unset",
        window = "address:" .. win.address }))
end
hl.on("window.open", function(win)
    if not win then return end
    local addr = win.address
    justOpened[addr] = true
    hl.timer(function() justOpened[addr] = nil end, { timeout = 1500, type = "oneshot" })
    keepNewWindowTiled(win)
end)
hl.on("window.fullscreen", keepNewWindowTiled)

-- LinOffice (Office in a Windows VM over FreeRDP RemoteApp): each app also
-- maps an untitled ~21x21 helper window at the screen's corner, with the
-- app's class. It showed as a second, empty Word/Excel window in the strip
-- and ALT+Tab, so it's parked on a special workspace that's never shown.
-- Matched on size too: Office's menus and dropdowns are untitled as well.
hl.on("window.open", function(win)
    if not win or not win.xwayland or win.title ~= "" then return end
    if not (win.class or ""):match("^Microsoft ") then return end
    if win.size.x > 32 or win.size.y > 32 then return end
    hl.dispatch(hl.dsp.window.move({ workspace = "special:rdp-helpers", window = "address:" .. win.address, follow = false }))
end)

-- SUPER+SHIFT+n and dragging between workspaces: the window takes on the
-- destination's layout. This fires before workspace.active does, so the
-- rules may still be set for the workspace it left -- which is fine, since
-- the conversion below is done by dispatch rather than by the rules.
hl.on("window.move_to_workspace", function(win, ws)
    if not win or not ws or ws.special then return end
    local on = monocleOn(ws)
    if on ~= isMonocleWin(win) then setWindowMonocle(win, on, ws.monitor or win.monitor) end
end)

local function maximizeFocused()
    local win = hl.get_active_window()

    -- A hidden window focused by any route (ALT+Tab, the overlay, the bar)
    -- is being asked for, so bring it back. Ahead of the monocle check since
    -- SUPER+C works in dwindle mode too.
    -- Restoring puts it back as it was, so there's nothing left to do here
    -- but raise it -- a re-fit now would cut the restore animation short.
    if win and stateOf(win.address).minimized then
        restoreMinimized(win)
        hl.dispatch(hl.dsp.window.bring_to_top({ window = "address:" .. win.address }))
        return
    end

    -- normally already done by the window.fullscreen hook
    win = unflagFloating(win)

    if not win or not win.class or win.fullscreen ~= 0 then return end
    if not monocleOn(win.workspace) then return end

    if win.floating then
        -- Hyprland doesn't raise a floater just because it got focus, so a
        -- monocle window is raised here. Other floaters (dialogs, Quickshell)
        -- aren't part of the monocle stack and are left alone.
        if hasTag(win, "monocle") then
            -- Re-fit a window left sized for a monitor it's no longer on
            -- (moved across, docked, undocked); backs up the monitor hooks
            -- below for when the layout hadn't settled as they fired.
            local mon = win.monitor
            if mon and not stateOf(win.address).small and not isFitted(win, fillArea(win, mon)) then
                sizeToFullFloat(win, mon)
            end
            hl.dispatch(hl.dsp.window.bring_to_top({ window = "address:" .. win.address }))
        end
        return
    end
    -- By class too: a Quickshell window can be focused before its rule's
    -- float lands, and must never be maximized (it sizes itself in QML).
    if win.class == "org.quickshell" then return end
    if stateOf(win.address).small then return end

    local mon = hl.get_active_monitor()
    if not mon then return end

    -- A window alone on its workspace fills the area with fullscreen=0, so
    -- compare geometry too rather than re-maximize it on every focus.
    if isAlreadyFull(win, mon) then return end

    hl.dispatch(hl.dsp.window.fullscreen({mode="maximized"}))
end

hl.on("window.active", maximizeFocused)

-- Re-checked on close too, rather than relying on how Hyprland sequences
-- the focus change around it.
hl.on("window.close", maximizeFocused)

-- window.close hands the closing window over, same as window.open does.
hl.on("window.close", function(win)
    if win then windowState[win.address] = nil end
end)

-- Docking, undocking, or changing a display's resolution or arrangement
-- moves the monitors under every open window, and floaters aren't re-laid
-- out. This re-fits every monocle window at once when that happens (the
-- focus hook only catches one at a time). Windows made small keep that size.
local function refitMonocle()
    for _, w in ipairs(hl.get_windows()) do
        if w.floating and hasTag(w, "monocle") and not stateOf(w.address).small and monocleOn(w.workspace) then
            local mon = w.monitor
            if mon and not isFitted(w, fillArea(w, mon)) then sizeToFullFloat(w, mon) end
        end
    end
end

-- All three: added/removed for a display appearing or going,
-- layout_changed for a rearrangement (it fires last when docking).
hl.on("monitor.added", refitMonocle)
hl.on("monitor.removed", refitMonocle)
hl.on("monitor.layout_changed", refitMonocle)
-- and after every load, for a changed edge gap
hl.timer(refitMonocle, { timeout = 200, type = "oneshot" })

-- TABS. Apps with no tabs of their own open each file in a window of its
-- own; these open theirs as tabs of one Hyprland group instead, joining the
-- first window of the same class on the same workspace. The group draws its
-- tab bar; clicking a tab switches, middle-clicking closes it.
local TABBED_CLASSES = {
    ["org.pwmt.zathura"] = true,
}

-- A monocle group is refitted as its tab bar comes and goes: the group
-- moves as one, so fitting any member fits them all.
local function refitGroup(win)
    if isMonocleWin(win) and not stateOf(win.address).small and monocleOn(win.workspace) then
        sizeToFullFloat(win)
    end
end

hl.on("window.open", function(win)
    if not win or not TABBED_CLASSES[win.class] or not win.workspace then return end
    local host
    for _, w in ipairs(hl.get_windows()) do
        if w.address ~= win.address and w.class == win.class and w.workspace
            and w.workspace.id == win.workspace.id and (not host or (w.group and not host.group)) then
            host = w
        end
    end
    if not host then return end
    if not host.group then
        hl.dispatch(hl.dsp.group.toggle({ window = "address:" .. host.address }))
    end
    if not host.group then return end
    host.group:add(win)
    refitGroup(win)
end)

-- SUPER+SHIFT+Q: every tab of the focused window's group.
function closeAllTabs()
    local win = hl.get_active_window()
    if not win then return end
    local members = win.group and win.group.members or { win }
    for _, w in ipairs(members) do
        hl.dispatch(hl.dsp.window.close({ window = "address:" .. w.address }))
    end
end

-- The Tabs binds are live only while a tabbed app has focus.
local function syncTabBinds()
    local win = hl.get_active_window()
    local on = win ~= nil and TABBED_CLASSES[win.class] == true
    for _, b in ipairs(S.tabBinds or {}) do b:set_enabled(on) end
end
syncTabBinds()
hl.on("window.active", syncTabBinds)
hl.on("window.close", syncTabBinds)

-- A group down to its last tab is dissolved, so a lone window has no tab
-- bar. After the close has settled, since the group still counts the
-- closing window while window.close runs.
hl.on("window.close", function()
    hl.timer(function()
        for _, w in ipairs(hl.get_windows()) do
            if w.group and w.group.size == 1 then
                hl.dispatch(hl.dsp.group.toggle({ window = "address:" .. w.address }))
                refitGroup(w)
            end
        end
    end, { timeout = 50, type = "oneshot" })
end)

-- SUPER+X. Deliberately no hook forcing a window back to maximized when it
-- leaves that state (the window.fullscreen hook only takes the flag *off*
-- floaters): that would make shrinking a window impossible. Instead this
-- records deliberate shrinks in windowState and maximizeFocused() leaves
-- them alone.
--
-- A tiled window uses Hyprland's own maximize toggle. A monocle floater has
-- nothing to toggle, so it shrinks to 70% centred and grows back.
function toggleMaximize()
    local win = hl.get_active_window()
    if not win then return end

    if win.floating and hasTag(win, "monocle") then
        local addr = "address:" .. win.address
        if stateOf(win.address).small then
            sizeToFullFloat(win)
            stateOf(win.address).small = nil
        else
            local mon = win.monitor or hl.get_active_monitor()
            if not mon then return end
            local area = usableArea(mon)
            hl.dispatch(hl.dsp.window.resize({
                x = math.floor(area.w * 0.7), y = math.floor(area.h * 0.7), window = addr }))
            hl.dispatch(hl.dsp.window.center({ window = addr }))
            stateOf(win.address).small = true
        end
        return
    end

    -- Any other floater: fill it, or put back what filling it replaced.
    -- One opened already full (nothing to put back) shrinks to 70% centred,
    -- the same as a monocle window.
    if win.floating then
        win = unflagFloating(win)
        local st = stateOf(win.address)
        local addr = "address:" .. win.address
        local mon = win.monitor or hl.get_active_monitor()
        if not mon then return end
        local area = fillArea(win, mon)
        if not isFitted(win, area) then
            -- whatever size it is now is the one to come back to
            st.restore = nil
            fillFloating(win)
        elseif st.restore then
            local r = st.restore
            st.restore = nil
            hl.dispatch(hl.dsp.window.resize({ x = r.w, y = r.h, window = addr }))
            hl.dispatch(hl.dsp.window.move({ x = r.x, y = r.y, window = addr }))
        else
            hl.dispatch(hl.dsp.window.resize({
                x = math.floor(area.w * 0.7), y = math.floor(area.h * 0.7), window = addr }))
            hl.dispatch(hl.dsp.window.center({ window = addr }))
        end
        return
    end

    hl.dispatch(hl.dsp.window.fullscreen({mode="maximized"}))

    -- Hyprland decides where the toggle actually lands (window rules and
    -- monocle's own maximize=true can override it), so read the state back
    -- rather than assume it went the way this predicted.
    -- by selector: hl.get_window() returns nil for a bare address
    local after = hl.get_window("address:" .. win.address)
    if after and after.fullscreen ~= 0 then
        stateOf(win.address).small = nil
    else
        stateOf(win.address).small = true
    end
end

-- Hides a window below the screen, or restores it, the way windows open
-- and close (windowAnim): slid off the screen (up for drop, down otherwise),
-- faded out where it is (shrinking to windowShrink for the styles that have
-- one) and only then moved away, or moved away at once. It stays transparent
-- while hidden, so the fade back in starts from nothing. A tiled window is
-- floated where it is first, since only floaters can be moved off-screen.
-- Refocusing a hidden window any other way restores it too -- see
-- maximizeFocused() above.
local function hiddenRect(r, mon)
    local y = windowAnim == "drop" and mon.y - r.h - 100 or mon.y + mon.height + 100
    return { x = r.x, y = y, w = r.w, h = r.h }
end

local function minimizeWindow(win)
    local st = stateOf(win.address)
    local mon = win.monitor or hl.get_active_monitor()
    if not mon then return end
    local addr = "address:" .. win.address

    local tiled = not win.floating
    if not tiled then win = unflagFloating(win) end
    local r = { x = math.floor(win.at.x), y = math.floor(win.at.y),
                w = math.floor(win.size.x), h = math.floor(win.size.y),
                tiled = tiled, fullscreen = tiled and win.fullscreen or 0 }
    st.minimized = r
    st.hideGen = (st.hideGen or 0) + 1
    local gen = st.hideGen
    hl.dispatch(hl.dsp.window.tag({ tag = "+" .. minimizedTag(r), window = addr }))

    -- skipped if it was restored, or closed, in the meantime
    local function current()
        return windowState[win.address] == st and st.hideGen == gen
    end

    -- Moving it off-screen doesn't move focus, so hand focus to the most
    -- recently used window left on this workspace -- never another hidden
    -- one, since focusing that would bring it back. Only once it's gone:
    -- a monocle window is raised as it takes focus, and would cover the
    -- animation.
    local function focusNext()
        local next
        for _, w in ipairs(hl.get_windows()) do
            if w.address ~= win.address and w.mapped and not w.hidden
                    and w.workspace and win.workspace and w.workspace.id == win.workspace.id
                    and not stateOf(w.address).minimized
                    and (not next or w.focus_history_id < next.focus_history_id) then
                next = w
            end
        end
        if next then hl.dispatch(hl.dsp.focus({ window = "address:" .. next.address })) end
    end

    local function gone()
        if not current() then return end
        if not windowSlides then jumpTo(addr, hiddenRect(r, mon)) end
        focusNext()
    end
    local function hide()
        if not current() then return end
        if windowAnim == "none" then return gone() end
        if windowSlides then
            moveTo(addr, hiddenRect(r, mon))
        else
            setProp(addr, "opacity", "0")
            if windowShrink then moveTo(addr, shrunk(r)) end
        end
        afterAnimation(windowSlides and windowSpeed or fadeSpeed, gone)
    end

    if tiled then
        if r.fullscreen ~= 0 then
            hl.dispatch(hl.dsp.window.fullscreen({
                mode = r.fullscreen == 1 and "maximized" or "fullscreen", action = "unset", window = addr }))
        end
        hl.dispatch(hl.dsp.window.float({ action = "enable", window = addr }))
        jumpTo(addr, r, hide)
    else
        hide()
    end
end

function toggleMinimize()
    local win = hl.get_active_window()
    if not win then return end
    if stateOf(win.address).minimized then restoreMinimized(win) else minimizeWindow(win) end
end

-- SUPER+D and the bar's show-desktop button. With any window showing on
-- the active workspace, hides them all as SUPER+C does, tagged
-- "showdesktop"; with none, brings back the ones it tagged and focuses the
-- one used last. Bringing one back any other way (the window strip,
-- ALT+Tab) drops its tag. The bar reads the tag to light its button, so
-- it's told to look again. A global so the button can run it through
-- `hyprctl eval`.
function singularityShowDesktop()
    local ws = hl.get_active_workspace()
    if not ws or ws.special then return end
    local showing, hidden = {}, {}
    for _, w in ipairs(hl.get_windows()) do
        if w.mapped and not w.hidden and w.workspace and w.workspace.id == ws.id
                and w.class ~= "org.quickshell" then
            if not stateOf(w.address).minimized then
                showing[#showing + 1] = w
            elseif hasTag(w, "showdesktop") then
                hidden[#hidden + 1] = w
            end
        end
    end
    if #showing > 0 then
        for _, w in ipairs(showing) do
            hl.dispatch(hl.dsp.window.tag({ tag = "+showdesktop", window = "address:" .. w.address }))
            minimizeWindow(w)
        end
    elseif #hidden > 0 then
        local last
        for _, w in ipairs(hidden) do
            restoreMinimized(w)
            if not last or w.focus_history_id < last.focus_history_id then last = w end
        end
        hl.dispatch(hl.dsp.focus({ window = "address:" .. last.address }))
    end
    hl.dispatch(hl.dsp.exec_cmd("qs ipc call desktop changed"))
end

-- After a reload, windows SUPER+C hid get their windowState back from the
-- tag it left. One a reload caught mid-fade, before the timer above moved
-- it away, is moved away now.
for _, w in ipairs(hl.get_windows()) do
    for _, t in ipairs(type(w.tags) == "table" and w.tags or { w.tags }) do
        local x, y, width, height, tiled, fullscreen =
            tostring(t):match("^minimized_(%-?%d+)_(%-?%d+)_(%d+)_(%d+)_([01])_(%d+)$")
        if x then
            local r = { x = tonumber(x), y = tonumber(y), w = tonumber(width), h = tonumber(height),
                        tiled = tiled == "1", fullscreen = tonumber(fullscreen) }
            stateOf(w.address).minimized = r
            local mon = w.monitor
            if mon and w.at.y + w.size.y > mon.y and w.at.y < mon.y + mon.height then jumpTo("address:" .. w.address, hiddenRect(r, mon)) end
        end
    end
end

-- WINDOW KEYS: SUPER+SHIFT/ALT/CTRL + arrows and SUPER+O. Global so the
-- binds can reach them.
--
-- A monocle window filling its monitor has nowhere to move or grow on it,
-- so the arrows leave it alone, except that SHIFT+left/right sends it to
-- the monitor that way. SUPER+X shrinks it first to move or size it by hand.
local NUDGE = 40
local ARROWS = { left = { -1, 0 }, right = { 1, 0 }, up = { 0, -1 }, down = { 0, 1 } }

local function isFullMonocle(win)
    return isMonocleWin(win) and not stateOf(win.address).small
end

-- Re-fits a monocle window to the monitor it landed on. The focus hook
-- would catch it too, but only on the next focus change.
local function refitAfterMove(win)
    if not isMonocleWin(win) or stateOf(win.address).small then return end
    local moved = hl.get_window("address:" .. win.address)
    if moved and moved.monitor then sizeToFullFloat(moved, moved.monitor) end
end

-- Tiled: along the layout, and on to the next monitor past its edge.
-- Floating: nudged, since a floater moved by direction jumps to the edge.
function moveWindowDir(dir)
    local win = hl.get_active_window()
    if not win then return end
    if not win.floating then
        hl.dispatch(hl.dsp.window.move({ direction = dir }))
    elseif isFullMonocle(win) then
        if dir ~= "left" and dir ~= "right" then return end
        hl.dispatch(hl.dsp.window.move({ monitor = dir == "left" and "l" or "r" }))
        refitAfterMove(win)
    else
        local d = ARROWS[dir]
        hl.dispatch(hl.dsp.window.move({ x = d[1] * NUDGE, y = d[2] * NUDGE, relative = true }))
    end
end

-- Tiled only: a floater has no place in the layout to trade. Hyprland
-- reports a missing neighbour as an error, which is nothing here.
function swapWindowDir(dir)
    local win = hl.get_active_window()
    if not win or win.floating then return end
    pcall(hl.dispatch, hl.dsp.window.swap({ direction = dir }))
end

-- On a tiled window the arrow moves the split it shares with its
-- neighbour that way. A floater grows to the right and down and shrinks to
-- the left and up, about its centre.
function resizeWindowDir(dir)
    local win = hl.get_active_window()
    if not win or isFullMonocle(win) then return end
    local d = ARROWS[dir]
    hl.dispatch(hl.dsp.window.resize({ x = d[1] * NUDGE, y = d[2] * NUDGE, relative = true }))
end

function sendToNextMonitor()
    local win = hl.get_active_window()
    if not win or #hl.get_monitors() < 2 then return end
    hl.dispatch(hl.dsp.window.move({ monitor = "+1" }))
    refitAfterMove(win)
end

-- monocleRule and the fullscreen entries' rules act on windows as they map,
-- nearly always on the active workspace, so they're switched to match it on
-- every workspace change and on SUPER+M. That's what gives a pinned
-- workspace its layout at map time, with no float-then-tile flicker. The
-- bar's layout toast hears of a workspace change only when the layout
-- changes; SUPER+M always announces.
local rulesMonocle = nil
local function applyLayoutRules(announce)
    local ws = hl.get_active_workspace()
    if ws and ws.special then return end
    local on = monocleOn(ws)
    monocleRule:set_enabled(on)
    for _, f in ipairs(fullscreenRules) do f.rule:set_enabled(on and (not f.app or f.app.on)) end
    if announce or (rulesMonocle ~= nil and rulesMonocle ~= on) then
        hl.exec_cmd("qs ipc call layout set " .. (on and "monocle" or "dwindle"))
    end
    rulesMonocle = on
end
applyLayoutRules()
-- wrapped: the event handler is called with the workspace, and anything
-- truthy in that first argument would toast on every workspace change
hl.on("workspace.active", function() applyLayoutRules() end)

-- The app rules' switch (see appRules): on while none of the app's windows
-- is open, or while a launch is pending. `closing` is a window that's on its
-- way out but still listed.
local launchPending = {}
local function syncAppRules(closing)
    if #appRules == 0 then return end
    local open = {}
    for _, w in ipairs(hl.get_windows()) do
        if w.address ~= closing then
            for _, app in ipairs(appRules) do
                if hasTag(w, app.tag) then open[app.tag] = true end
            end
        end
    end
    for _, app in ipairs(appRules) do
        app.on = launchPending[app.tag] or not open[app.tag]
        for _, r in ipairs(app.rules) do r:set_enabled(app.on) end
        for _, r in ipairs(app.held) do r:set_enabled(not app.on) end
    end
    applyLayoutRules()
end
syncAppRules()

-- A bind or the launcher just ran something: every app rule is on for the
-- next few seconds, or until that app's window opens, and the next window
-- to open isn't taken for a popup (holdPopup). Global so Quickshell's
-- launcher can call it through `hyprctl eval`.
local launchGen = 0
function markLaunch()
    launchGen = launchGen + 1
    local gen = launchGen
    for _, app in ipairs(appRules) do launchPending[app.tag] = true end
    launchWaiting = true
    syncAppRules()
    hl.timer(function()
        if gen ~= launchGen then return end
        launchPending = {}
        launchWaiting = false
        syncAppRules()
    end, { timeout = 4000, type = "oneshot" })
end

hl.on("window.open", function(win)
    if not win then return end
    for _, app in ipairs(appRules) do
        if hasTag(win, app.tag) then
            local addr = "address:" .. win.address
            hl.dispatch(hl.dsp.window.tag({ tag = app.on and "+app-opened" or "+app-held", window = addr }))
            if not app.on then hl.dispatch(hl.dsp.window.tag({ tag = "+monocle-exempt", window = addr })) end
            launchPending[app.tag] = nil
        end
    end
    syncAppRules()
end)
hl.on("window.close", function(win) syncAppRules(win and win.address) end)

-- SUPER+M: monocle or dwindle everywhere that isn't pinned. The rules only
-- act at map time, so the windows already open are converted here too. On
-- a pinned workspace nothing moves and the toast says so. Global so the
-- SUPER+M bind can reach it.
function toggleLayout()
    monocleEnabled = not monocleEnabled
    local f = io.open(LAYOUT_FILE, "w")
    if f then
        f:write(monocleEnabled and "monocle\n" or "dwindle\n")
        f:close()
    end

    local ws = hl.get_active_workspace()
    local pin = ws and workspaceLayouts[tostring(ws.id)]
    if pin then
        hl.exec_cmd("notify-send -a Hyprland -t 3000 'Layout' 'Workspace " .. ws.id
            .. " is pinned to " .. (pin == "monocle" and "monocle" or "tiled")
            .. "; windows opened or moved elsewhere now go "
            .. (monocleEnabled and "monocle" or "tiled") .. "'")
        return
    end

    applyLayoutRules(true)

    -- every workspace that follows SUPER+M, not just this one; hidden
    -- windows (SUPER+C) keep their state, or one would tile back in unseen
    for _, w in ipairs(hl.get_windows()) do
        if w.workspace and not w.workspace.special and not workspaceLayouts[tostring(w.workspace.id)]
                and not stateOf(w.address).minimized then
            setWindowMonocle(w, monocleEnabled, w.monitor or hl.get_active_monitor())
        end
    end
end
