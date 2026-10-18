-- Singularity - Hyprland
-- ~/.config/hypr/windows.lua
--
-- How windows behave: monocle and SUPER+M, popouts, the scratchpad, tabs,
-- SUPER+X/C/D. The static rules are in window-rules.lua and the arrow keys
-- in window-keys.lua. The functions binds.lua calls are globals defined
-- here, as are the ones Quickshell runs through `hyprctl eval`
-- (singularityShowDesktop, markLaunch).

local S = require("shared")
local animOff, animFactor = S.animOff, S.animFactor * S.windowsFactor
local windowAnim, windowSlides, windowShrink = S.windowAnim, S.windowSlides, S.windowShrink
local windowSpeed, fadeSpeed = S.windowSpeed, S.fadeSpeed
local R = require("window-rules")
local monocleRule, edgeGaps, SCRATCH_CLASS, isPrompt, fullscreenRules, appRules, naturalRule
    = R.monocleRule, R.edgeGaps, R.SCRATCH_CLASS, R.isPrompt, R.fullscreenRules, R.appRules, R.naturalRule

-- Popouts: see holdPopup() below. Registered here, ahead of monocle's
-- hooks, which would fill the window; window.active comes ahead of
-- window.open for a window that takes focus. Windows open before this load
-- (a reload) are known already and left alone.
local holdPopup
local launchWaiting = false
local knownWindows = {}
for _, w in ipairs(hl.get_windows()) do knownWindows[w.address] = true end
hl.on("window.active", function() holdPopup(hl.get_active_window()) end)
hl.on("window.open", function(win) holdPopup(win) end)
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
--   shape     -- a monocle window's size and place; see shapeRect() below
--   placedOn  -- the monitor placeMonocle() last fitted it to
--   lastShape -- the shape SUPER+equal brings a filled monocle window back to
--   parked    -- moved below the screen while covered; see PARKING below
--   settling  -- coming back from SUPER+C, still animating into place
--   small     -- a tiled window unmaximized on purpose (SUPER+equal), so
--                refocusing it does not immediately undo the choice; see
--                toggleMaximize() below
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

-- A window's tags as a list: Hyprland hands over a lone tag as a string.
local function tagsOf(w)
    return type(w.tags) == "table" and w.tags or { w.tags }
end

-- Tells the shell to re-read the windows, whose tags it shows (the window
-- strip, the show-desktop button) but isn't told of. Once per tick, since
-- one event can change several windows and each call starts a `qs`.
local notifyPending = false
local function notifyShell()
    if notifyPending then return end
    notifyPending = true
    hl.timer(function()
        notifyPending = false
        hl.exec_cmd("qs ipc call desktop changed")
    end, { timeout = 1, type = "oneshot" })
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
-- for the styles that have one), and tiled again if it was tiled. With
-- `instant` it's put straight back with no animation, whatever the style;
-- the caller holds no_anim on it (see singularityShowDesktop).
local function restoreMinimized(win, instant)
    local st = stateOf(win.address)
    local saved = st.minimized
    st.minimized = nil
    st.hideGen = (st.hideGen or 0) + 1
    local gen = st.hideGen
    local addr = "address:" .. win.address
    hl.dispatch(hl.dsp.window.tag({ tag = "-" .. minimizedTag(saved), window = addr }))
    -- hidden by show desktop: the bar's button reads the tag
    for _, t in ipairs(tagsOf(win)) do
        if t == "showdesktop" then
            hl.dispatch(hl.dsp.window.tag({ tag = "-showdesktop", window = addr }))
            notifyShell()
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
    -- captureShape() leaves it alone until it has arrived
    st.settling = true
    afterAnimation(math.max(windowSpeed, fadeSpeed) + 1, function()
        if current() then st.settling = nil end
    end)
    local function show()
        if not current() then return end
        if windowAnim ~= "fade" then moveTo(addr, saved) end
        -- slide too: the window may have been hidden under another style
        setProp(addr, "opacity", "1")
        if saved.tiled then afterAnimation(windowSpeed, retile) end
    end

    if instant then
        moveTo(addr, saved)
        setProp(addr, "opacity", "1")
        if saved.tiled then retile() end
    elseif windowSlides then
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
    return win.class == "org.quickshell" or (hasTag(win, "monocle-exempt") and not hasTag(win, "promoted"))
end

-- Tags a floater "filled" while it fills its monitor and takes the tag off
-- once it doesn't, so the filled-borderless rule above drops its border.
-- Run after every resize this file makes; one resized by the mouse is
-- caught when focus next changes.
local function syncFillBorder(addr)
    local win = hl.get_window("address:" .. addr)
    if not win then return end
    local filled = win.floating and win.monitor ~= nil and isFitted(win, fillArea(win, win.monitor))
    if filled ~= hasTag(win, "filled") then
        hl.dispatch(hl.dsp.window.tag({ tag = (filled and "+" or "-") .. "filled", window = "address:" .. addr }))
    end
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
    syncFillBorder(win.address)
end

-- A monocle window's shape (windowState.shape): nil fills the area, a
-- {fx, fy, fw, fh} table is a rect in fractions of fillArea(), so it keeps
-- its size and place relative to whichever monitor it is on. A shape within
-- SNAP_FILL of the whole area counts as filling it.
local SNAP_FILL = 0.94

local function shapeRect(win, mon, shape)
    local area = fillArea(win, mon)
    if not shape then return area end
    return {
        x = area.x + shape.fx * area.w, y = area.y + shape.fy * area.h,
        w = shape.fw * area.w, h = shape.fh * area.h,
    }
end

local function centredShape(share)
    return { fx = (1 - share) / 2, fy = (1 - share) / 2, fw = share, fh = share }
end

-- Also kept on the window as a "shape_…" tag (per mille), since
-- windowState doesn't survive a config reload.
local function shapeTag(shape)
    return string.format("shape_%d_%d_%d_%d", math.floor(shape.fx * 1000 + 0.5),
        math.floor(shape.fy * 1000 + 0.5), math.floor(shape.fw * 1000 + 0.5), math.floor(shape.fh * 1000 + 0.5))
end

local function setShape(win, shape)
    local st = stateOf(win.address)
    local addr = "address:" .. win.address
    if st.shape then hl.dispatch(hl.dsp.window.tag({ tag = "-" .. shapeTag(st.shape), window = addr })) end
    st.shape = shape
    if shape then hl.dispatch(hl.dsp.window.tag({ tag = "+" .. shapeTag(shape), window = addr })) end
end

-- Sizes a monocle window to its shape on `mon`, if it isn't already. A
-- hidden (SUPER+C) window is left where it is. placedOn records the
-- monitor, so captureShape() can tell a window moved to another monitor,
-- which is re-placed, from one resized by hand.
local function placeMonocle(win, mon)
    mon = mon or win.monitor or hl.get_active_monitor()
    local st = stateOf(win.address)
    if not mon or st.minimized or st.parked then return end
    st.placedOn = mon.id
    local r = shapeRect(win, mon, st.shape)
    if isFitted(win, r) then return syncFillBorder(win.address) end
    local addr = "address:" .. win.address
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(r.w), y = math.floor(r.h), window = addr }))
    hl.dispatch(hl.dsp.window.move({ x = math.floor(r.x), y = math.floor(r.y), window = addr }))
    syncFillBorder(win.address)
end

-- The shape a floater's geometry makes on `mon`: nil within SNAP_FILL of
-- filling it. With `keep`, keeps that shape's size, just where it now is.
local function shapeOf(win, mon, keep)
    local area = fillArea(win, mon)
    local fw = keep and keep.fw or math.min(win.size.x / area.w, 1)
    local fh = keep and keep.fh or math.min(win.size.y / area.h, 1)
    if fw >= SNAP_FILL and fh >= SNAP_FILL then return nil end
    return {
        fx = math.max(0, math.min((win.at.x - area.x) / area.w, 1 - fw)),
        fy = math.max(0, math.min((win.at.y - area.y) / area.h, 1 - fh)),
        fw = fw, fh = fh,
    }
end

-- Takes a monocle window's shape from where it actually is, so one moved or
-- resized by the mouse or the arrow keys stays that way. One that has
-- changed monitor since it was placed keeps its share of the screen, where
-- it was dropped; a filled one is just filled again there.
local function captureShape(win)
    win = win and hl.get_window("address:" .. win.address)
    if not (win and win.floating and hasTag(win, "monocle") and win.fullscreen == 0) then return end
    local st = stateOf(win.address)
    local mon = win.monitor
    if not mon or st.minimized or st.parked or st.settling then return end
    local moved = st.placedOn ~= mon.id
    if moved and not st.shape then return end
    if not moved and isFitted(win, shapeRect(win, mon, st.shape)) then return end
    setShape(win, shapeOf(win, mon, moved and st.shape))
    placeMonocle(win, mon)
end

-- REMEMBERED SIZES. Each app's main window opens the way it was last left,
-- per kind of screen (wide, normal, tall): fullscreen, filled, or at its
-- shape. A window only counts as filled when it actually fills the area
-- (a Fills app, SUPER+X, the size ladder), not one that just opened big.
-- Kept in ~/.local/state/singularity/window-sizes.json as
-- { class = { normal = { fullscreen = true } | { fill = true }
--   | { fx, fy, fw, fh }, t = time } },
-- the 100 most recently used. Only monocle and natural windows count --
-- not popouts, prompts, rule entries, pinned windows or the shell's own.
local SIZES_FILE = os.getenv("HOME") .. "/.local/state/singularity/window-sizes.json"
local SIZES_MAX = 100
local sizes = {}
do
    local f = io.open(SIZES_FILE)
    local data = f and S.decodeJson(f:read("a"))
    if f then f:close() end
    if type(data) == "table" then sizes = data end
end

local function screenKind(area)
    local ratio = area.w / area.h
    return ratio > 1.9 and "wide" or ratio < 1 and "tall" or "normal"
end

local function rememberable(win)
    return win and win.class and win.class ~= "" and win.class ~= "org.quickshell"
        and win.class ~= SCRATCH_CLASS and win.floating and win.fullscreen ~= 1 and not win.pinned
        and (hasTag(win, "monocle") or hasTag(win, "natural"))
        and not (hasTag(win, "popout") or hasTag(win, "app-held") or hasTag(win, "rule-float")
            or hasTag(win, "rule-full") or hasTag(win, "monocle-exempt"))
        and monocleOn(win.workspace)
end

local function num(v) return string.format("%.4f", v) end

local function writeSizes()
    local classes = {}
    for class, entry in pairs(sizes) do
        if type(entry) == "table" then table.insert(classes, class) end
    end
    table.sort(classes, function(a, b) return (sizes[a].t or 0) > (sizes[b].t or 0) end)
    local lines = {}
    for i, class in ipairs(classes) do
        if i > SIZES_MAX then
            sizes[class] = nil
        else
            local parts = { '"t":' .. math.floor(sizes[class].t or 0) }
            for _, kind in ipairs({ "normal", "wide", "tall" }) do
                local m = sizes[class][kind]
                if type(m) == "table" and m.fullscreen then
                    table.insert(parts, '"' .. kind .. '":{"fullscreen":true}')
                elseif type(m) == "table" and m.fill then
                    table.insert(parts, '"' .. kind .. '":{"fill":true}')
                elseif type(m) == "table" and m.fw then
                    table.insert(parts, string.format('"%s":{"fx":%s,"fy":%s,"fw":%s,"fh":%s}',
                        kind, num(m.fx), num(m.fy), num(m.fw), num(m.fh)))
                end
            end
            local key = class:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end)
            table.insert(lines, string.format('  "%s": {%s}', key, table.concat(parts, ",")))
        end
    end
    local tmp = SIZES_FILE .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then return end
    f:write("{\n" .. table.concat(lines, ",\n") .. "\n}\n")
    f:close()
    os.rename(tmp, SIZES_FILE)
end

-- Written a moment after the last change, so dragging focus around
-- doesn't write the file for every window it passes.
local sizesDirty = false
local function saveSizes()
    if sizesDirty then return end
    sizesDirty = true
    hl.timer(function()
        sizesDirty = false
        writeSizes()
    end, { timeout = 2000, type = "oneshot" })
end

-- Records how `win` is now: fullscreen, a monocle window by its shape, a
-- natural one by where it actually is.
local function rememberWindow(win)
    if not rememberable(win) or not win.monitor then return end
    local st = stateOf(win.address)
    if st.minimized or st.parked or st.settling then return end
    local area = fillArea(win, win.monitor)
    local m
    if win.fullscreen == 2 then
        m = { fullscreen = true }
    else
        local shape
        if hasTag(win, "monocle") then
            shape = st.shape
        elseif isFitted(win, area) then
            shape = nil
        else
            shape = shapeOf(win, win.monitor)
            if not shape then return end
        end
        m = shape and { fx = shape.fx, fy = shape.fy, fw = shape.fw, fh = shape.fh } or { fill = true }
    end
    local entry = type(sizes[win.class]) == "table" and sizes[win.class] or {}
    local kind = screenKind(area)
    local old = entry[kind]
    entry.t = os.time()
    entry[kind] = m
    sizes[win.class] = entry
    local same = type(old) == "table" and old.fullscreen == m.fullscreen and old.fill == m.fill
        and (m.fullscreen or m.fill or (num(old.fx) == num(m.fx) and num(old.fy) == num(m.fy)
            and num(old.fw) == num(m.fw) and num(old.fh) == num(m.fh)))
    if not same then saveSizes() end
end

-- Settings > Window Rules' Forget: drops an app's remembered size at once.
function forgetSize(class)
    if sizes[class] == nil then return end
    sizes[class] = nil
    writeSizes()
end

-- The remembered shape for `win` on `mon`: "fullscreen", false for filled,
-- nil for none. Another kind of screen's entry stands in when this kind
-- has none.
local function recallShape(win, mon)
    local entry = sizes[win.class]
    if type(entry) ~= "table" then return nil end
    local m = entry[screenKind(fillArea(win, mon))] or entry.normal or entry.wide or entry.tall
    if type(m) ~= "table" then return nil end
    if m.fullscreen then return "fullscreen" end
    if m.fill then return false end
    local fx, fy, fw, fh = tonumber(m.fx), tonumber(m.fy), tonumber(m.fw), tonumber(m.fh)
    if not (fx and fy and fw and fh) or fw <= 0 or fh <= 0 then return nil end
    fw, fh = math.min(fw, 1), math.min(fh, 1)
    return {
        fx = math.max(0, math.min(fx, 1 - fw)), fy = math.max(0, math.min(fy, 1 - fh)),
        fw = fw, fh = fh,
    }
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
        setShape(win, nil)
        placeMonocle(win)
    else
        if not st.restore then
            st.restore = { x = win.at.x, y = win.at.y, w = win.size.x, h = win.size.y }
        end
        sizeToFullFloat(win)
    end
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

-- Moves one window into or out of monocle -- SUPER+M's sweep, and any
-- window that lands on a workspace whose layout isn't the one the rules
-- were set for when it mapped (see applyLayoutRules below) -- leaving it as
-- it would have opened there, whatever it went through since. That's
-- worked out from what Window Rules says of it (the "rule-*" tags), not
-- from the tags it picked up as it mapped: an app rule is off while the
-- app is open, and the tags it set go with it, so they can't be trusted
-- once more than one app is open.
--
-- In monocle a fullscreen entry's window is fullscreen, a Fills app's
-- fills the screen and any other floats where it is, centred. In dwindle
-- they tile. A float or pin entry's window floats in both, and so do an
-- app's dialogs and popups. A fullscreen the app asked for itself -- a
-- game, a video -- is left alone.
local function setWindowMonocle(w, on, mon)
    -- class "" is a window that hasn't said what it is yet; leave it, and
    -- the shell's windows and the scratchpad, which place themselves
    if not w.class or w.class == "" or w.class == "org.quickshell" or w.class == SCRATCH_CLASS then return end
    if w.pinned or hasTag(w, "rule-float") then return end
    local addr = "address:" .. w.address
    local popup = hasTag(w, "app-held") or hasTag(w, "popout")
    local full = hasTag(w, "rule-full") and not popup
    if on then
        if full then
            if not w.floating then hl.dispatch(hl.dsp.window.float({ action = "enable", window = addr })) end
            if w.fullscreen ~= 2 then
                hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set", window = addr }))
            end
        elseif not w.floating and w.fullscreen ~= 2 then
            if w.fullscreen == 1 then
                hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset", window = addr }))
            end
            hl.dispatch(hl.dsp.window.float({ action = "enable", window = addr }))
            if hasTag(w, "rule-fill") and not popup then
                hl.dispatch(hl.dsp.window.tag({ tag = "+monocle", window = addr }))
                placeMonocle(w, mon)
            else
                -- not filled: floated where it is, centred
                hl.dispatch(hl.dsp.window.tag({ tag = "+natural", window = addr }))
                hl.dispatch(hl.dsp.window.center({ window = addr }))
            end
        end
        return
    end
    if full and w.fullscreen ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "unset", window = addr }))
    end
    -- a Fills app's window by its rule too: one that opened while another
    -- of the app's was up, say, can have lost its monocle tag
    if w.floating and (full or hasTag(w, "monocle") or hasTag(w, "natural")
            or (hasTag(w, "rule-fill") and not popup)) then
        hl.dispatch(hl.dsp.window.float({ action = "disable", window = addr }))
    end
    hl.dispatch(hl.dsp.window.tag({ tag = "-monocle", window = addr }))
    hl.dispatch(hl.dsp.window.tag({ tag = "-natural", window = addr }))
    -- the rule's copy of the tag, which carries the *
    hl.dispatch(hl.dsp.window.tag({ tag = "-monocle*", window = addr }))
    hl.dispatch(hl.dsp.window.tag({ tag = "-filled", window = addr }))
    setShape(w, nil)
    stateOf(w.address).small = nil
end

-- In monocle right now: floated by the monocle machinery. The tag alone
-- isn't enough -- monocleRule's tag is re-applied whenever Hyprland
-- re-evaluates a window's rules, so a tiled window on a workspace pinned to
-- dwindle can pick it up while monocle is the active workspace's layout.
-- Floating isn't re-applied that way; it's set once, at map time.
local function isMonocleWin(w)
    return w.floating and hasTag(w, "monocle")
end

-- Laid out for monocle by setWindowMonocle or the rules: filled, floated
-- naturally, or a fullscreen entry's window floated under its fullscreen.
local function inMonocleState(w)
    return w.floating and (hasTag(w, "monocle") or hasTag(w, "natural") or hasTag(w, "rule-full"))
end

-- Sizes every window the monocle rule just floated, once, as it maps, so
-- switching to it later is just a raise. Uses the window window.open hands
-- over, not hl.get_active_window(), which can still be the previous window
-- when a second one opens.
-- POPOUTS. A window an app opens by itself -- a sign-in popup, a dialog,
-- a second window -- is one from a process that already has a window up,
-- unless a bind or the launcher has just run something (markLaunch). Any
-- monocle or natural app, rule or not; decided once, as it first shows up.
-- It floats over the window it came from, centred on it, at the size it
-- was last left (per app and title), else the size it asks for. One asking
-- for nearly the whole screen -- Firefox-based browsers ask 1280x1040 for
-- every popup -- gets POPOUT_SHARE of it instead.
local POPOUT_SHARE = { 0.5, 0.6 }

-- Settings > Window Rules' popup switches, in popups.json: { block, over,
-- remember }, each on unless set false.
local popupOpts = { block = true, over = true, remember = true }
do
    local f = io.open(os.getenv("HOME") .. "/.local/state/singularity/popups.json")
    local data = f and S.decodeJson(f:read("a"))
    if f then f:close() end
    if type(data) == "table" then
        for k in pairs(popupOpts) do
            if data[k] == false then popupOpts[k] = false end
        end
    end
end
local CASCADE = 32

-- The key a popout's size is remembered under: its app and the title it
-- opened with, unless that title looks like a document's, which changes.
local function popoutKey(win)
    local title = win.initial_title or win.title or ""
    if title == "" or #title > 40 or title:find(" [-—–|] ") then return nil end
    return "popout:" .. win.class .. ":" .. title
end

-- A dialog-sized popout blocks the window it came from until it's closed
-- or promoted, the way a modal dialog does: the owner takes no clicks or
-- focus (no_focus), and focusing it by any route -- ALT+Tab, the bar --
-- brings up the popout instead. Popouts asking for nearly the whole
-- screen (a browser's new window) don't block. Kept on tags as well --
-- "owner_<address>" on the popout, "blocked" on the owner -- since the
-- no_focus prop outlives a reload and this table doesn't.
local popoutOwner = {}

local function setBlocked(ownerAddr, on)
    local addr = "address:" .. ownerAddr
    if not hl.get_window(addr) then return end
    setProp(addr, "no_focus", on and "1" or "0")
    hl.dispatch(hl.dsp.window.tag({ tag = (on and "+" or "-") .. "blocked", window = addr }))
    notifyShell()
end

local function blockOwner(popAddr, ownerAddr)
    popoutOwner[popAddr] = ownerAddr
    hl.dispatch(hl.dsp.window.tag({ tag = "+owner_" .. ownerAddr, window = "address:" .. popAddr }))
    setBlocked(ownerAddr, true)
end

local function releasePopout(popAddr)
    local ownerAddr = popoutOwner[popAddr]
    if not ownerAddr then return end
    popoutOwner[popAddr] = nil
    hl.dispatch(hl.dsp.window.tag({ tag = "-owner_" .. ownerAddr, window = "address:" .. popAddr }))
    for _, o in pairs(popoutOwner) do
        if o == ownerAddr then return end
    end
    setBlocked(ownerAddr, false)
end

-- The owner's most recently used popout.
local function blockingPopout(ownerAddr)
    local best
    for p, o in pairs(popoutOwner) do
        local w = o == ownerAddr and hl.get_window("address:" .. p)
        if w and (not best or w.focus_history_id < best.focus_history_id) then best = w end
    end
    return best
end

do
    for _, w in ipairs(hl.get_windows()) do
        for _, t in ipairs(tagsOf(w)) do
            local o = tostring(t):match("^owner_(.+)$")
            if o and hl.get_window("address:" .. o) then popoutOwner[w.address] = o end
        end
    end
    for _, w in ipairs(hl.get_windows()) do
        if hasTag(w, "blocked") and not blockingPopout(w.address) then setBlocked(w.address, false) end
    end
end

hl.on("window.active", function()
    local win = hl.get_active_window()
    local pop = win and blockingPopout(win.address)
    if not pop then return end
    local addr = "address:" .. pop.address
    -- next tick, after the hooks that raise the window just focused
    hl.timer(function()
        hl.dispatch(hl.dsp.focus({ window = addr }))
        hl.dispatch(hl.dsp.window.bring_to_top({ window = addr }))
    end, { timeout = 1, type = "oneshot" })
end)
hl.on("window.close", function(win)
    if not win then return end
    releasePopout(win.address)
    -- an owner closed under its popouts
    for p, o in pairs(popoutOwner) do
        if o == win.address then popoutOwner[p] = nil end
    end
end)

-- Whether a window is on the workspace in front of you -- the focused
-- monitor's, or the scratchpad when it's shown over it -- where a new
-- window maps. Focusing one that isn't would switch to it.
local function onActiveWorkspace(win)
    local mon = hl.get_active_monitor()
    local active = mon and (mon.active_special_workspace or mon.active_workspace)
    return win.workspace and active and win.workspace.id == active.id
end

-- The window a new one came from: the app's most recently used window, one
-- of its main ones if it has any. Returns it and whether it's a main one.
local function popoutOwnerOf(win)
    local owner, ownerMain
    for _, w in ipairs(hl.get_windows()) do
        if w.pid == win.pid and w.address ~= win.address and w.mapped then
            local main = not (hasTag(w, "popout") or hasTag(w, "app-held"))
            if not owner or (main and not ownerMain)
                    or (main == ownerMain and w.focus_history_id < owner.focus_history_id) then
                owner, ownerMain = w, main
            end
        end
    end
    return owner, ownerMain
end

-- A window an app opens by itself goes to the workspace of the window it
-- came from, not the one you're on: a dialog from an app on another
-- workspace waits there with it, silently, instead of covering what you're
-- doing. Not one a bind or the launcher just asked for (markLaunch), a
-- pinned one, or one a Window Rules entry sends to a workspace of its own.
-- Returns the window as it is after the move.
local function followOwner(win)
    if launchWaiting or win.pinned or hasTag(win, "rule-ws") or not onActiveWorkspace(win) then return win end
    local owner = popoutOwnerOf(win)
    local ws = owner and owner.workspace
    if not ws or ws.id == win.workspace.id then return win end
    local special = ws.name and ws.name:find("^special:")
    hl.dispatch(hl.dsp.window.move({ workspace = special and ws.name or ws.id,
        window = "address:" .. win.address, follow = false }))
    return hl.get_window("address:" .. win.address) or win
end

holdPopup = function(win)
    if not win or knownWindows[win.address] then return end
    knownWindows[win.address] = true
    if not win.class or win.class == "" or win.class == "org.quickshell" or win.class == SCRATCH_CLASS then return end
    win = followOwner(win)
    if not win.floating or win.pinned or not monocleOn(win.workspace) then return end
    -- A Window Rules entry's window places itself; one the entry marks as a
    -- popout (a file or settings dialog) still blocks its owner.
    if hasTag(win, "rule-full") then return end
    local ruled = hasTag(win, "rule-float")
    if ruled and not hasTag(win, "popout") then return end
    if launchWaiting and not ruled then
        launchWaiting = false
        return
    end
    local owner, ownerMain = popoutOwnerOf(win)
    if not owner then return end

    local addr = "address:" .. win.address
    -- the window strip lists it under the window it came from
    hl.dispatch(hl.dsp.window.tag({ tag = "+from_" .. owner.address, window = addr }))
    if ruled then
        notifyShell()
        local mon = win.monitor or hl.get_active_monitor()
        local area = mon and fillArea(win, mon)
        if area and popupOpts.block and ownerMain and win.size.x <= area.w * 0.85 and win.size.y <= area.h * 0.85 then
            blockOwner(win.address, owner.address)
            if onActiveWorkspace(win) then hl.dispatch(hl.dsp.focus({ window = addr })) end
        end
        return
    end
    -- monocleRule's tag is a rule's, so it carries the *
    hl.dispatch(hl.dsp.window.tag({ tag = "-monocle*", window = addr }))
    hl.dispatch(hl.dsp.window.tag({ tag = "+monocle-exempt", window = addr }))
    hl.dispatch(hl.dsp.window.tag({ tag = "+app-held", window = addr }))
    hl.dispatch(hl.dsp.window.tag({ tag = "+popout", window = addr }))
    notifyShell()

    local mon = win.monitor or hl.get_active_monitor()
    if not mon then return end
    local area = fillArea(win, mon)
    local key = popoutKey(win)
    stateOf(win.address).popoutKey = key
    local w, h = win.size.x, win.size.y
    local dialogSized = w <= area.w * 0.85 and h <= area.h * 0.85
    local m = popupOpts.remember and key and type(sizes[key]) == "table" and sizes[key][screenKind(area)]
    if type(m) == "table" and tonumber(m.fw) and tonumber(m.fh) then
        w, h = math.min(m.fw, 1) * area.w, math.min(m.fh, 1) * area.h
    elseif w > area.w * 0.85 or h > area.h * 0.85 then
        w, h = area.w * POPOUT_SHARE[1], area.h * POPOUT_SHARE[2]
    end
    -- over its owner when that's on the same monitor, else the screen's centre
    local cx, cy = area.x + area.w / 2, area.y + area.h / 2
    if popupOpts.over and owner.monitor and owner.monitor.id == mon.id and owner.workspace and win.workspace
            and owner.workspace.id == win.workspace.id then
        cx, cy = owner.at.x + owner.size.x / 2, owner.at.y + owner.size.y / 2
    end
    local x = math.max(area.x, math.min(cx - w / 2, area.x + area.w - w))
    local y = math.max(area.y, math.min(cy - h / 2, area.y + area.h - h))
    -- stepped down and right off another of the app's popouts already there
    for _ = 1, 10 do
        local taken = false
        for _, o in ipairs(hl.get_windows()) do
            if o.pid == win.pid and o.address ~= win.address and hasTag(o, "popout")
                    and math.abs(o.at.x - x) < 8 and math.abs(o.at.y - y) < 8 then
                taken = true
            end
        end
        if not taken then break end
        x = math.min(x + CASCADE, area.x + area.w - w)
        y = math.min(y + CASCADE, area.y + area.h - h)
    end
    moveTo(addr, { x = math.floor(x), y = math.floor(y), w = math.floor(w), h = math.floor(h) })
    if popupOpts.block and dialogSized and ownerMain then
        blockOwner(win.address, owner.address)
        if onActiveWorkspace(win) then hl.dispatch(hl.dsp.focus({ window = addr })) end
    end
end

-- Records a popout's size, as a share of the screen, under its key.
local function rememberPopout(win)
    local key = win and stateOf(win.address).popoutKey
    if not key or not popupOpts.remember or not win.floating or win.fullscreen ~= 0 or not win.monitor then return end
    if not (hasTag(win, "popout") or hasTag(win, "app-held")) then return end
    local area = fillArea(win, win.monitor)
    local fw, fh = math.min(win.size.x / area.w, 1), math.min(win.size.y / area.h, 1)
    if fw >= SNAP_FILL and fh >= SNAP_FILL then return end
    local entry = type(sizes[key]) == "table" and sizes[key] or {}
    local kind = screenKind(area)
    local old = entry[kind]
    entry.t = os.time()
    entry[kind] = { fx = 0, fy = 0, fw = fw, fh = fh }
    sizes[key] = entry
    if not (type(old) == "table" and num(old.fw) == num(fw) and num(old.fh) == num(fh)) then saveSizes() end
end

-- Makes a popout one of the app's main windows: filled and in the monocle
-- stack for a Fills app, a natural window otherwise. Filling one does this
-- (see fillFloating), as does the window strip's row action.
local function promotePopout(win)
    if not (hasTag(win, "popout") or hasTag(win, "app-held")) then return win end
    releasePopout(win.address)
    local addr = "address:" .. win.address
    -- The held app rule's copy of monocle-exempt stays while the rule is on,
    -- so "promoted" tells isMonocleExempt() to look past it.
    for _, t in ipairs({ "popout", "app-held", "monocle-exempt" }) do
        hl.dispatch(hl.dsp.window.tag({ tag = "-" .. t, window = addr }))
    end
    hl.dispatch(hl.dsp.window.tag({ tag = "+promoted", window = addr }))
    for _, t in ipairs(tagsOf(win)) do
        if tostring(t):match("^from_") then hl.dispatch(hl.dsp.window.tag({ tag = "-" .. t, window = addr })) end
    end
    stateOf(win.address).popoutKey = nil
    if monocleOn(win.workspace) then
        hl.dispatch(hl.dsp.window.tag({ tag = hasTag(win, "rule-fill") and "+monocle" or "+natural", window = addr }))
    end
    notifyShell()
    return hl.get_window(addr) or win
end

-- Fills a floater the user asked to fill, promoting it if it's a popout.
local function fillByHand(win)
    win = promotePopout(win)
    if hasTag(win, "monocle") then
        setShape(win, nil)
        placeMonocle(win)
        hl.dispatch(hl.dsp.window.bring_to_top({ window = "address:" .. win.address }))
    else
        fillFloating(win)
    end
end

-- The window strip's "make main window": promoted where it is, and filled
-- if it's a Fills app's.
function promoteWindow(address)
    local win = hl.get_window("address:" .. address)
    if not win then return end
    win = promotePopout(win)
    if hasTag(win, "monocle") then
        setShape(win, nil)
        placeMonocle(win)
    end
end

-- A window that isn't filled and would open right on top of another of
-- the same app's steps down and to the right of it, like a deck of cards.
local function cascade(win)
    win = hl.get_window("address:" .. win.address) or win
    local mon = win.monitor
    if not mon or not win.workspace or not rememberable(win) then return end
    if hasTag(win, "monocle") and not stateOf(win.address).shape then return end
    local area = fillArea(win, mon)
    local x, y = win.at.x, win.at.y
    local function taken()
        for _, o in ipairs(hl.get_windows()) do
            if o.address ~= win.address and o.class == win.class and o.floating
                    and o.workspace and o.workspace.id == win.workspace.id
                    and math.abs(o.at.x - x) < 8 and math.abs(o.at.y - y) < 8 then
                return true
            end
        end
        return false
    end
    local steps = 0
    while steps < 10 and taken() do
        x, y = x + CASCADE, y + CASCADE
        if x + win.size.x > area.x + area.w or y + win.size.y > area.y + area.h then
            x, y = area.x + (steps + 1) * 8, area.y + (steps + 1) * 8
        end
        steps = steps + 1
    end
    if steps == 0 then return end
    hl.dispatch(hl.dsp.window.move({ x = math.floor(x), y = math.floor(y), window = "address:" .. win.address }))
    if hasTag(win, "monocle") then captureShape(win) end
end

local function onMonocleOpen(win)
    if not win then return end
    -- The rules follow the *active* workspace's layout, so a window that
    -- mapped somewhere else (a window-rules.json workspace entry, an app
    -- restoring its own session) can come up in the wrong one.
    --
    -- Only then: on the active workspace the rules were right, and a
    -- window's state isn't settled yet (Quickshell's windows map before
    -- their class and float land, and looked like tiled apps).
    -- Fetched again: followOwner may have just moved it.
    local fresh = hl.get_window("address:" .. win.address) or win
    local on = monocleOn(fresh.workspace)
    local active = hl.get_active_workspace()
    local elsewhere = fresh.workspace and active and fresh.workspace.id ~= active.id
    if elsewhere and on ~= inMonocleState(fresh) and not (on and isMonocleExempt(fresh)) then
        setWindowMonocle(fresh, on, fresh.monitor)
        if not on then return end
        fresh = hl.get_window("address:" .. win.address) or fresh
    end
    -- One the natural rule floated, marked so SUPER+M tiles it again (the
    -- rule's own tags go when it's switched off): floating, outside the
    -- monocle stack, and not one of the shell's, a prompt or a popup.
    if on and fresh.floating and not hasTag(fresh, "monocle") and not isMonocleExempt(fresh)
            and not fresh.pinned and not hasTag(fresh, "popout") then
        hl.dispatch(hl.dsp.window.tag({ tag = "+natural", window = "address:" .. win.address }))
    end
    -- The windows monocleRule floated are placed, and a natural one is put
    -- where it was last left. Exempt ones -- Quickshell's own windows,
    -- window-rules.json entries -- keep the size they open at.
    if not on then return end
    fresh = hl.get_window("address:" .. win.address) or fresh
    local mon = fresh.monitor
    local shape = nil
    if rememberable(fresh) and mon then shape = recallShape(fresh, mon) end
    local full = shape == "fullscreen"
    if full then shape = nil end
    if hasTag(fresh, "monocle") then
        if shape ~= nil or full then setShape(fresh, shape or nil) end
        placeMonocle(fresh)
    elseif shape == false then
        sizeToFullFloat(fresh, mon)
    elseif shape then
        moveTo("address:" .. fresh.address, shapeRect(fresh, mon, shape))
    end
    if full then
        hl.dispatch(hl.dsp.window.fullscreen({
            mode = "fullscreen", action = "set", window = "address:" .. fresh.address }))
        return
    end
    cascade(fresh)
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

-- SUPER+SHIFT+n and dragging between workspaces: the window takes on the
-- destination's layout. This fires before workspace.active does, so the
-- rules may still be set for the workspace it left -- which is fine, since
-- the conversion below is done by dispatch rather than by the rules.
hl.on("window.move_to_workspace", function(win, ws)
    if not win or not ws or ws.special then return end
    local on = monocleOn(ws)
    if on ~= inMonocleState(win) then setWindowMonocle(win, on, ws.monitor or win.monitor) end
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
            if win.monitor then placeMonocle(win, win.monitor) end
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

-- The window focus leaves keeps whatever shape the mouse gave it.
local shapeWatch = nil
hl.on("window.active", function()
    local win = hl.get_active_window()
    if shapeWatch and (not win or win.address ~= shapeWatch) then
        local left = hl.get_window("address:" .. shapeWatch)
        captureShape(left)
        left = left and hl.get_window("address:" .. left.address)
        rememberWindow(left)
        rememberPopout(left)
    end
    shapeWatch = win and win.address
end)
hl.on("window.active", maximizeFocused)

-- Focusing another window over a fullscreen one (ALT+Tab, the window strip,
-- the overlay) takes it out of fullscreen, as Windows does with a
-- fullscreen game. Left fullscreen it keeps the workspace's input: the
-- window you picked is raised and focused but every click lands on the
-- fullscreen one under it, and moving the pointer hands it the keyboard
-- back. Only Hyprland's side of it is dropped: the app is still told it's
-- fullscreen (fullscreen_state's client half), so a browser keeps its video
-- filling the window instead of leaving the page's fullscreen, and focusing
-- it again puts it straight back -- unless the app has left fullscreen of
-- its own accord meanwhile. Only true fullscreen (2): a maximized window
-- (1) is how dwindle mode fills, and maximizeFocused handles those.
local function yieldFullscreen()
    local win = hl.get_active_window()
    if not win or not win.workspace then return end
    local st = stateOf(win.address)
    local yielded = st.yieldedFullscreen
    if yielded then
        st.yieldedFullscreen = nil
        if win.fullscreen == 0 and win.fullscreen_client == yielded.client then
            hl.dispatch(hl.dsp.window.fullscreen_state({
                internal = 2, client = yielded.client, window = "address:" .. win.address }))
        end
        return
    end
    if win.fullscreen ~= 0 then return end
    for _, w in ipairs(hl.get_windows()) do
        if w.address ~= win.address and w.fullscreen == 2 and w.workspace
                and w.workspace.id == win.workspace.id then
            stateOf(w.address).yieldedFullscreen = { client = w.fullscreen_client }
            hl.dispatch(hl.dsp.window.fullscreen_state({
                internal = 0, client = w.fullscreen_client, window = "address:" .. w.address }))
            hl.dispatch(hl.dsp.window.bring_to_top({ window = "address:" .. win.address }))
        end
    end
end
hl.on("window.active", yieldFullscreen)
-- and a floater resized by the mouse gets its border back, or loses it
hl.on("window.active", function()
    local win = hl.get_active_window()
    if win then syncFillBorder(win.address) end
end)

-- Re-checked on close too, rather than relying on how Hyprland sequences
-- the focus change around it.
hl.on("window.close", maximizeFocused)

-- window.close hands the closing window over, same as window.open does.
hl.on("window.close", function(win)
    if not win then return end
    captureShape(win)
    local last = hl.get_window("address:" .. win.address) or win
    rememberWindow(last)
    rememberPopout(last)
    windowState[win.address] = nil
end)

-- Dialogs stay over the window they came from. Every monocle window is a
-- floater, and maximizeFocused raises whichever one you focus, so a click
-- off a file chooser or a sign-in popup onto the app behind it -- or
-- ALT+Tab back to the app -- would bury the dialog under it. As on Windows
-- and macOS, an app's dialogs come up with it instead: whenever a window is
-- focused, its dialogs are raised over it, nested ones over theirs. Focus
-- stays where you clicked.
--
-- Hyprland keeps an X11 dialog over its parent itself but not a Wayland
-- one, and Lua isn't told a window's parent, so the owner is worked out as
-- the dialog opens: the window focused just before it. That's only taken
-- as its owner when they share a process (a browser's sign-in popup, an
-- app's Preferences) or the dialog is one of the prompts above (the file
-- chooser portal, polkit), and the dialog floats outside the monocle
-- stack. A second window an app opens from a bind or the launcher is
-- monocle or an app rule's opened side, and owns nothing.
local dialogOwner = {}   -- dialog address -> owner address
local focusedNow, focusedBefore = nil, nil

local function adoptDialog(addr)
    local win = hl.get_window("address:" .. addr)
    if not win or not win.floating or win.class == "org.quickshell" then return end
    if hasTag(win, "monocle") or hasTag(win, "app-opened") or win.pinned then return end
    local ownerAddr = focusedNow == addr and focusedBefore or focusedNow
    local owner = ownerAddr and hl.get_window("address:" .. ownerAddr)
    if not owner or owner.address == addr then return end
    if owner.pid ~= win.pid and not isPrompt(win.class) then return end
    dialogOwner[addr] = owner.address
    -- as a dialog it's no natural window for SUPER+M to tile
    hl.dispatch(hl.dsp.window.tag({ tag = "-natural", window = "address:" .. addr }))
    -- the window strip lists popouts under the window they came from
    if not hasTag(win, "popout") then
        hl.dispatch(hl.dsp.window.tag({ tag = "+popout", window = "address:" .. addr }))
        notifyShell()
    end
end

-- Raises win's dialogs over it, then theirs over them.
local function raiseDialogs(addr, depth)
    if depth > 4 then return end
    for d, o in pairs(dialogOwner) do
        if o == addr then
            -- not bring_to_top, which only ever raises the active window
            hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = "address:" .. d }))
            raiseDialogs(d, depth + 1)
        end
    end
end

hl.on("window.active", function()
    local win = hl.get_active_window()
    if not win then return end
    if win.address ~= focusedNow then focusedBefore, focusedNow = focusedNow, win.address end
    -- On the next tick: the focus change raises the window itself once the
    -- hooks have run, which would put it back over its dialogs.
    local addr = win.address
    hl.timer(function() raiseDialogs(addr, 0) end, { timeout = 1, type = "oneshot" })
end)
-- A moment after it opens, once the rules' and holdPopup's tags are on it.
hl.on("window.open", function(win)
    if not win then return end
    local addr = win.address
    hl.timer(function() adoptDialog(addr) end, { timeout = 60, type = "oneshot" })
end)
hl.on("window.close", function(win)
    if not win then return end
    dialogOwner[win.address] = nil
    for d, o in pairs(dialogOwner) do
        if o == win.address then dialogOwner[d] = nil end
    end
end)

-- Docking, undocking, or changing a display's resolution or arrangement
-- moves the monitors under every open window, and floaters aren't re-laid
-- out. This re-fits every monocle window at once when that happens (the
-- focus hook only catches one at a time). Each keeps its shape.
local function refitMonocle()
    for _, w in ipairs(hl.get_windows()) do
        if w.floating and hasTag(w, "monocle") and monocleOn(w.workspace) and w.monitor then
            placeMonocle(w, w.monitor)
        end
    end
end

-- All three: added/removed for a display appearing or going,
-- layout_changed for a rearrangement (it fires last when docking).
hl.on("monitor.added", refitMonocle)
hl.on("monitor.removed", refitMonocle)
hl.on("monitor.layout_changed", refitMonocle)
-- and after every load, for a changed edge gap, keeping what the mouse did
-- to the focused window first
hl.timer(function()
    captureShape(hl.get_active_window())
    refitMonocle()
end, { timeout = 200, type = "oneshot" })
hl.timer(function()
    for _, w in ipairs(hl.get_windows()) do syncFillBorder(w.address) end
end, { timeout = 300, type = "oneshot" })

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
    if isMonocleWin(win) and monocleOn(win.workspace) then placeMonocle(win) end
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
-- A tiled window uses Hyprland's own maximize toggle. A monocle floater
-- switches between filling and the shape it had last (70% centred at first).
local function toggleMaximizeWin(win)
    if win.floating and hasTag(win, "monocle") then
        captureShape(win)
        local st = stateOf(win.address)
        if st.shape then
            st.lastShape = st.shape
            setShape(win, nil)
        else
            setShape(win, st.lastShape or centredShape(0.7))
        end
        placeMonocle(win)
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
            fillByHand(win)
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

function toggleMaximize()
    local win = hl.get_active_window()
    if not win then return end
    toggleMaximizeWin(win)
    syncFillBorder(win.address)
end

-- SUPER+equal and SUPER+minus: a floater steps up or down the ladder of
-- sizes, as a share of the usable area -- 55%, 70%, 85%, filled -- about
-- its own centre. A tiled window just maximizes or restores.
local LADDER = { 0.55, 0.7, 0.85 }
function stepWindowSize(dir)
    local win = hl.get_active_window()
    if not win or win.class == "org.quickshell" then return end
    if not win.floating then
        if dir > 0 or win.fullscreen ~= 0 then toggleMaximizeWin(win) end
        return
    end
    win = unflagFloating(win)
    local mon = win.monitor
    if not mon or win.fullscreen ~= 0 then return end
    local monocle = hasTag(win, "monocle")
    if monocle then
        captureShape(win)
        win = hl.get_window("address:" .. win.address) or win
    end
    local cur = monocle and stateOf(win.address).shape or shapeOf(win, mon)
    local size = cur and math.max(cur.fw, cur.fh) or 1
    local share = nil
    if dir > 0 then
        for _, step in ipairs(LADDER) do
            if step > size + 0.01 then share = step break end
        end
        if not cur then return end
    else
        for i = #LADDER, 1, -1 do
            if LADDER[i] < size - 0.01 then share = LADDER[i] break end
        end
        if not share then return end
    end
    local shape = nil
    if share then
        local cx = cur and cur.fx + cur.fw / 2 or 0.5
        local cy = cur and cur.fy + cur.fh / 2 or 0.5
        shape = {
            fx = math.max(0, math.min(cx - share / 2, 1 - share)),
            fy = math.max(0, math.min(cy - share / 2, 1 - share)),
            fw = share, fh = share,
        }
    end
    if monocle then
        if not shape then stateOf(win.address).lastShape = cur end
        setShape(win, shape)
        placeMonocle(win, mon)
    elseif not shape then
        fillByHand(win)
    else
        moveTo("address:" .. win.address, shapeRect(win, mon, shape))
    end
    syncFillBorder(win.address)
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
    -- mon.height is in pixels; the layout is in logical ones, so a scaled
    -- monitor (0.75 makes 1080 rows 1440 tall) would leave it half on screen
    local y = windowAnim == "drop" and mon.y - r.h - 100 or mon.y + math.ceil(mon.height / mon.scale) + 100
    return { x = r.x, y = y, w = r.w, h = r.h }
end

local function minimizeWindow(win, instant)
    local st = stateOf(win.address)
    local mon = win.monitor or hl.get_active_monitor()
    if not mon then return end
    local addr = "address:" .. win.address

    local tiled = not win.floating
    if not tiled then win = unflagFloating(win) end
    local r = { x = math.floor(win.at.x), y = math.floor(win.at.y),
                w = math.floor(win.size.x), h = math.floor(win.size.y),
                tiled = tiled, fullscreen = tiled and win.fullscreen or 0 }
    -- a parked window comes back where it was before it was parked
    if st.parked then
        local pr = shapeRect(win, mon, st.shape)
        r.x, r.y, r.w, r.h = math.floor(pr.x), math.floor(pr.y), math.floor(pr.w), math.floor(pr.h)
        hl.dispatch(hl.dsp.window.tag({ tag = string.format("-parked_%d_%d_%d_%d",
            st.parked.x, st.parked.y, st.parked.w, st.parked.h), window = addr }))
        if not hasTag(win, "monocle") then
            r.x, r.y, r.w, r.h = st.parked.x, st.parked.y, st.parked.w, st.parked.h
        end
        st.parked = nil
        instant = true
    end
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
        if instant then moveTo(addr, hiddenRect(r, mon)) else jumpTo(addr, r, hide) end
    elseif instant then
        moveTo(addr, hiddenRect(r, mon))
    else
        hide()
    end
end

-- PARKING. In monocle the windows on a workspace are floaters stacked
-- over each other, and Hyprland keeps drawing -- and sending frames to --
-- the ones a filled window covers completely, so a video or an animated
-- page behind it runs at full rate. Those are parked below the screen like
-- a hidden window, where Hyprland throttles them as it does windows on
-- hidden workspaces. Down each visible monocle workspace's stack from the
-- top (hl.get_windows() lists windows bottom to top), everything stays
-- down to the first window that covers the screen, plus the one
-- under it, which shows as soon as the top one closes or hides. Focusing a
-- parked window by any route brings it straight back. Popouts, pinned
-- windows, tab groups and the shell's own are never parked. A
-- "parked_x_y_w_h" tag carries where it was over a reload.
local function parkable(w)
    return w.mapped and w.floating and not w.pinned and not w.group and w.class ~= ""
        and w.class ~= "org.quickshell" and w.class ~= SCRATCH_CLASS
        and (hasTag(w, "monocle") or hasTag(w, "natural"))
        and not (hasTag(w, "popout") or hasTag(w, "app-held"))
end

local function covers(w)
    if w.fullscreen == 2 then return true end
    local mon = w.workspace and w.workspace.monitor or w.monitor
    if hasTag(w, "monocle") then return not stateOf(w.address).shape end
    return mon ~= nil and isFitted(w, fillArea(w, mon))
end

local function parkTag(r)
    return string.format("parked_%d_%d_%d_%d", r.x, r.y, r.w, r.h)
end

local function parkWin(w)
    local st = stateOf(w.address)
    local mon = w.workspace and w.workspace.monitor or w.monitor
    if st.parked or st.minimized or st.settling or not mon then return end
    local r = { x = math.floor(w.at.x), y = math.floor(w.at.y), w = math.floor(w.size.x), h = math.floor(w.size.y) }
    st.parked = r
    local addr = "address:" .. w.address
    hl.dispatch(hl.dsp.window.tag({ tag = "+" .. parkTag(r), window = addr }))
    jumpTo(addr, hiddenRect(r, mon))
end

-- Back where it was: a monocle window where its shape puts it on its
-- workspace's monitor now, any other where it was parked from.
local function unparkWin(w)
    local st = stateOf(w.address)
    local r = st.parked
    if not r then return end
    st.parked = nil
    local addr = "address:" .. w.address
    hl.dispatch(hl.dsp.window.tag({ tag = "-" .. parkTag(r), window = addr }))
    if not w.floating then return end
    local mon = w.workspace and w.workspace.monitor or w.monitor
    if mon and hasTag(w, "monocle") then
        local sr = shapeRect(w, mon, st.shape)
        r = { x = math.floor(sr.x), y = math.floor(sr.y), w = math.floor(sr.w), h = math.floor(sr.h) }
        st.placedOn = mon.id
    end
    jumpTo(addr, r)
end

local function syncParking()
    local stacks = {}
    for _, mon in ipairs(hl.get_monitors()) do
        local ws = mon.active_workspace
        if ws and monocleOn(ws) then stacks[ws.id] = {} end
    end
    for _, w in ipairs(hl.get_windows()) do
        local st = stateOf(w.address)
        local stack = w.workspace and stacks[w.workspace.id]
        if stack and parkable(w) and not st.minimized then
            table.insert(stack, 1, w)
        elseif st.parked and not (w.workspace and monocleOn(w.workspace) and parkable(w)) then
            -- out of monocle, or no longer a window that parks
            unparkWin(w)
        end
    end
    for _, stack in pairs(stacks) do
        local keep = #stack
        for i, w in ipairs(stack) do
            if covers(w) then
                keep = i + 1
                break
            end
        end
        for i, w in ipairs(stack) do
            if i <= keep then unparkWin(w) else parkWin(w) end
        end
    end
end

-- Once per burst of events, on the next tick, when focus and the stack
-- have settled.
local parkPending = false
local function scheduleParking()
    if parkPending then return end
    parkPending = true
    hl.timer(function()
        parkPending = false
        syncParking()
    end, { timeout = 1, type = "oneshot" })
end

-- The window focused comes back at once, ahead of the next frame, and
-- goes on top of the stack -- a natural window too, which nothing else
-- raises -- or the next sync would park it again.
hl.on("window.active", function()
    local win = hl.get_active_window()
    if win and stateOf(win.address).parked then
        unparkWin(win)
        hl.dispatch(hl.dsp.window.bring_to_top({ window = "address:" .. win.address }))
    end
    scheduleParking()
end)
for _, ev in ipairs({ "window.open", "window.close", "window.fullscreen", "window.move_to_workspace",
        "workspace.active", "monitor.added", "monitor.removed", "monitor.layout_changed" }) do
    hl.on(ev, function() scheduleParking() end)
end

-- after a reload: the parked windows from the tag, then the stacks afresh
for _, w in ipairs(hl.get_windows()) do
    for _, t in ipairs(tagsOf(w)) do
        local x, y, pw, ph = tostring(t):match("^parked_(%-?%d+)_(%-?%d+)_(%d+)_(%d+)$")
        if x then
            stateOf(w.address).parked = { x = tonumber(x), y = tonumber(y), w = tonumber(pw), h = tonumber(ph) }
        end
    end
end
hl.timer(syncParking, { timeout = 300, type = "oneshot" })

function toggleMinimize()
    local win = hl.get_active_window()
    if not win then return end
    if stateOf(win.address).minimized then restoreMinimized(win) else minimizeWindow(win) end
end

-- SUPER+D and the bar's show-desktop button. With any window showing on
-- any workspace of any monitor, hides them all as SUPER+C does, tagged
-- "showdesktop"; with none, brings back the ones it tagged and focuses the
-- one used last on the active workspace. Always instant, whatever the
-- animation settings: every window it touches holds no_anim until the
-- moves have been drawn, so neither the hidden windows nor the tiles
-- reflowing around them animate. The scratchpad and other special
-- workspaces are left alone. Bringing one back any other way (the window
-- strip, ALT+Tab) drops its tag. The bar reads the tag to light its
-- button, so it's told to look again. A global so the button can run it
-- through `hyprctl eval`.
function singularityShowDesktop()
    local showing, hidden = {}, {}
    for _, w in ipairs(hl.get_windows()) do
        if w.mapped and not w.hidden and w.workspace and not w.workspace.special
                and w.class ~= "org.quickshell" then
            if not stateOf(w.address).minimized then
                showing[#showing + 1] = w
            elseif hasTag(w, "showdesktop") then
                hidden[#hidden + 1] = w
            end
        end
    end
    local touched = #showing > 0 and showing or hidden
    if #touched == 0 then return end
    for _, w in ipairs(touched) do setProp("address:" .. w.address, "no_anim", "1") end

    if #showing > 0 then
        for _, w in ipairs(showing) do
            hl.dispatch(hl.dsp.window.tag({ tag = "+showdesktop", window = "address:" .. w.address }))
            minimizeWindow(w, true)
        end
    else
        local ws = hl.get_active_workspace()
        local last
        for _, w in ipairs(hidden) do
            restoreMinimized(w, true)
            if ws and w.workspace.id == ws.id
                    and (not last or w.focus_history_id < last.focus_history_id) then
                last = w
            end
        end
        if last then hl.dispatch(hl.dsp.focus({ window = "address:" .. last.address })) end
    end

    hl.timer(function()
        for _, w in ipairs(touched) do setProp("address:" .. w.address, "no_anim", "0") end
    end, { timeout = 30, type = "oneshot" })
    notifyShell()
end

-- After a reload, windows SUPER+C hid get their windowState back from the
-- tag it left. One a reload caught mid-fade, before the timer above moved
-- it away, is moved away now. Monocle windows get their shape back, as
-- placed on the monitor they're on.
for _, w in ipairs(hl.get_windows()) do
    if w.monitor and isMonocleWin(w) then stateOf(w.address).placedOn = w.monitor.id end
    for _, t in ipairs(tagsOf(w)) do
        local fx, fy, fw, fh = tostring(t):match("^shape_(%d+)_(%d+)_(%d+)_(%d+)$")
        if fx then
            stateOf(w.address).shape = { fx = fx / 1000, fy = fy / 1000, fw = fw / 1000, fh = fh / 1000 }
        end
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

require("window-keys")({
    isMonocleWin = isMonocleWin, stateOf = stateOf,
    placeMonocle = placeMonocle, captureShape = captureShape,
})

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
    naturalRule:set_enabled(on)
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
    scheduleParking()
end
