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

-- Popouts (holdPopup below), hooked ahead of monocle's hooks, which would
-- fill the window. Windows already open at load (a reload) are left alone.
local holdPopup
local launchWaiting = false
local knownWindows = {}
for _, w in ipairs(hl.get_windows()) do knownWindows[w.address] = true end
hl.on("window.active", function() holdPopup(hl.get_active_window()) end)
hl.on("window.open", function(win) holdPopup(win) end)
hl.on("window.close", function(win) if win then knownWindows[win.address] = nil end end)

-- SUPER+M's global layout mode, kept in a runtime file so a reload keeps
-- it; monocle again at login. The rest of monocle is event hooks.
local LAYOUT_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/singularity-layout"
local monocleEnabled = true
do
    local f = io.open(LAYOUT_FILE)
    if f then
        monocleEnabled = f:read("l") ~= "dwindle"
        f:close()
    end
end

-- Workspaces pinned to a layout, from workspace-layouts.json (written by
-- Settings > Window Rules): { "1": "monocle", "3": "dwindle" }.
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

-- Per-window state by address, on top of Hyprland's own:
--   shape     -- a monocle window's size and place (shapeRect)
--   placedOn  -- the monitor placeMonocle() last fitted it to
--   lastShape -- the shape SUPER+equal brings a filled window back to
--   parked    -- moved off-screen while covered (PARKING)
--   settling  -- coming back from SUPER+C, still animating
--   small     -- a tiled window unmaximized on purpose (toggleMaximize)
--   minimized -- where SUPER+C hid it from, and whether it was tiled/fullscreen
--   hideGen   -- bumped by every hide and restore, so stale steps skip
--   restore   -- a non-monocle floater's rect before it was filled
-- Cleared on close: Hyprland reuses addresses.
local windowState = {}
local function stateOf(addr)
    local st = windowState[addr]
    if not st then
        st = {}
        windowState[addr] = st
    end
    return st
end

-- SUPER+C's saved rect, also kept as a tag so it survives a config reload.
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

-- Tells the shell to re-read window tags (strip, show-desktop button), at
-- most once per tick.
local notifyPending = false
local function notifyShell()
    if notifyPending then return end
    notifyPending = true
    hl.timer(function()
        notifyPending = false
        hl.exec_cmd("qs ipc call desktop changed")
    end, { timeout = 1, type = "oneshot" })
end

-- Sizes and places a floater at r = {x, y, w, h}. jumpTo does it without
-- animation: no_anim is read on the next draw, so it's held briefly.
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

-- r at the style's starting size (windowShrink), same centre
local function shrunk(r)
    local w, h = math.floor(r.w * windowShrink[1]), math.floor(r.h * windowShrink[2])
    return { x = r.x + (r.w - w) // 2, y = r.y + (r.h - h) // 2, w = w, h = h }
end

-- Puts a SUPER+C-hidden window back, animated per the window style, and
-- re-tiles it if it was tiled. `instant`: no animation (show desktop).
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
    -- re-tiled only once it has arrived, or a maximized window would hide
    -- the rest while it fades in
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

-- The monitor's usable rect (minus reserved edges), in layout coordinates.
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
-- less the tab bar for a grouped window.
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

-- Fills the monitor: position as well as size (unlike isAlreadyFull).
local function isFitted(win, area)
    return math.abs(win.size.x - area.w) <= 4 and math.abs(win.size.y - area.h) <= 4
        and math.abs(win.at.x - area.x) <= 4 and math.abs(win.at.y - area.y) <= 4
end

local function isAlreadyFull(win, mon)
    local area = usableArea(mon)
    local w, h = win.size.x, win.size.y
    return math.abs(w - area.w) <= 4 and math.abs(h - area.h) <= 4
end

-- Has the tag `name` (a rule's tag comes back with a trailing "*").
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

-- Windows SUPER+M's sweep must leave floating: the "monocle-exempt" tag
-- from Window Rules entries, and Quickshell's own windows.
local function isMonocleExempt(win)
    return win.class == "org.quickshell" or (hasTag(win, "monocle-exempt") and not hasTag(win, "promoted"))
end

-- Tags a floater "filled" while it fills its monitor, which drops its
-- border. Run after every resize made here.
local function syncFillBorder(addr)
    local win = hl.get_window("address:" .. addr)
    if not win then return end
    local filled = win.floating and win.monitor ~= nil and isFitted(win, fillArea(win, win.monitor))
    if filled ~= hasTag(win, "filled") then
        hl.dispatch(hl.dsp.window.tag({ tag = (filled and "+" or "-") .. "filled", window = "address:" .. addr }))
    end
end

-- Fills the usable rect without touching floating state.
local function sizeToFullFloat(win, mon)
    mon = mon or win.monitor or hl.get_active_monitor()
    if not mon then return end
    local area = fillArea(win, mon)
    local addr = "address:" .. win.address
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(area.w), y = math.floor(area.h), window = addr }))
    hl.dispatch(hl.dsp.window.move({ x = math.floor(area.x), y = math.floor(area.y), window = addr }))
    syncFillBorder(win.address)
end

-- A monocle window's shape: nil fills the area, else {fx, fy, fw, fh} in
-- fractions of fillArea(). Within SNAP_FILL of the whole counts as filled.
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

-- also kept as a "shape_…" tag (per mille) to survive a reload
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

-- Sizes a monocle window to its shape on `mon`. Hidden windows are left
-- alone. placedOn lets captureShape() tell a monitor move from a resize.
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

-- The shape a floater's geometry makes on `mon` (nil: fills it). With
-- `keep`, keeps that shape's size where it now is.
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

-- Takes a monocle window's shape from where it is, so a hand move or
-- resize sticks. Moved to another monitor: keeps its share of the screen.
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

-- REMEMBERED SIZES. An app's main window reopens as last left, per kind of
-- screen (wide, normal, tall): fullscreen, filled, or at its shape. Kept in
-- window-sizes.json, the 100 most recent apps; monocle and natural windows
-- only (not popouts, prompts, rule entries, pinned or shell windows).
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

-- written 2s after the last change
local sizesDirty = false
local function saveSizes()
    if sizesDirty then return end
    sizesDirty = true
    hl.timer(function()
        sizesDirty = false
        writeSizes()
    end, { timeout = 2000, type = "oneshot" })
end

-- Records how `win` is now: fullscreen, filled, or its shape.
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

-- The remembered shape on `mon`: "fullscreen", false for filled, nil for
-- none; another screen kind's entry stands in.
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

-- A floater is maximized by filling the usable area, never by Hyprland's
-- maximized flag (a flagged floater ignores bring_to_top and move). The
-- flag is taken off wherever it turns up. Filling saves the old rect for
-- toggleMaximize(). Returns the window re-read.
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

-- Moves a window into or out of monocle (SUPER+M's sweep, or a window
-- landing on a workspace of the other layout), going by its Window Rules
-- "rule-*" tags rather than tags picked up at map time. Monocle: a
-- fullscreen entry goes fullscreen, a Fills app fills, others float
-- centred. Dwindle: they tile. Float/pin entries and popups float in
-- both; an app's own fullscreen is left alone.
local function setWindowMonocle(w, on, mon)
    -- skip windows with no class yet, the shell's and the scratchpad
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
    -- a Fills app's window by its rule too: it may have lost its monocle tag
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

-- In monocle right now: floating as well as tagged, since the rule's tag
-- can be re-applied to a tiled window on a dwindle-pinned workspace.
local function isMonocleWin(w)
    return w.floating and hasTag(w, "monocle")
end

-- laid out for monocle: filled, floated naturally, or under a fullscreen
local function inMonocleState(w)
    return w.floating and (hasTag(w, "monocle") or hasTag(w, "natural") or hasTag(w, "rule-full"))
end

-- POPOUTS. A window from an app that already has one up, unless a bind or
-- the launcher just launched something (markLaunch). It floats centred over
-- its owner at its remembered size (per app and title), else its own; one
-- asking for nearly the whole screen gets POPOUT_SHARE instead.
local POPOUT_SHARE = { 0.5, 0.6 }

-- Window Rules' popup switches (popups.json), each on unless false
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

-- the key a popout's size is remembered under: app and opening title,
-- unless the title looks like a document's
local function popoutKey(win)
    local title = win.initial_title or win.title or ""
    if title == "" or #title > 40 or title:find(" [-—–|] ") then return nil end
    return "popout:" .. win.class .. ":" .. title
end

-- A dialog-sized popout blocks its owner like a modal dialog: the owner
-- takes no focus (no_focus), and focusing it brings up the popout. Kept on
-- tags too ("owner_<addr>", "blocked"), since no_focus survives a reload
-- and this table doesn't.
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

-- on the workspace in front of you (or the shown scratchpad), where a new
-- window maps
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

-- A window an app opens by itself goes to its owner's workspace, not the
-- one you're on, unless just launched, pinned, or sent by a Window Rules
-- entry. Returns the window after the move.
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
    -- a Window Rules entry's window places itself; a popout entry still blocks
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

-- Makes a popout a main window: filled for a Fills app, natural otherwise.
local function promotePopout(win)
    if not (hasTag(win, "popout") or hasTag(win, "app-held")) then return win end
    releasePopout(win.address)
    local addr = "address:" .. win.address
    -- "promoted" makes isMonocleExempt() look past the held rule's tag
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

-- a window opening right on top of another of the same app's steps down
-- and right of it
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
    -- The rules follow the active workspace's layout, so a window mapped
    -- elsewhere can come up in the wrong one; only then is it converted.
    -- Re-read, as followOwner may have moved it.
    local fresh = hl.get_window("address:" .. win.address) or win
    local on = monocleOn(fresh.workspace)
    local active = hl.get_active_workspace()
    local elsewhere = fresh.workspace and active and fresh.workspace.id ~= active.id
    if elsewhere and on ~= inMonocleState(fresh) and not (on and isMonocleExempt(fresh)) then
        setWindowMonocle(fresh, on, fresh.monitor)
        if not on then return end
        fresh = hl.get_window("address:" .. win.address) or fresh
    end
    -- tagged natural so SUPER+M tiles it again
    if on and fresh.floating and not hasTag(fresh, "monocle") and not isMonocleExempt(fresh)
            and not fresh.pinned and not hasTag(fresh, "popout") then
        hl.dispatch(hl.dsp.window.tag({ tag = "+natural", window = "address:" .. win.address }))
    end
    -- placed per its remembered shape; exempt windows keep their size
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

-- In dwindle every window opens tiled: a maximize or fullscreen asked for
-- in its first 1.5s is undone.
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

-- A window that maps while a flyout holds the keyboard (Update now) gets no
-- focus, and the flyout closing hands focus back to the window before it,
-- which is raised over the new one. Once the last flyout closes, the new
-- window is focused and raised instead.
local FLYOUT_NS = "singularity-flyout"
local openedUnderFlyout = nil
local function flyoutUp(except)
    for _, l in ipairs(hl.get_layers()) do
        if l.namespace == FLYOUT_NS and l.mapped and l.address ~= except then return true end
    end
    return false
end
hl.on("window.open", function(win)
    if win and flyoutUp() then openedUnderFlyout = win.address end
end)
hl.on("layer.closed", function(layer)
    if not layer or layer.namespace ~= FLYOUT_NS or not openedUnderFlyout or flyoutUp(layer.address) then return end
    local addr = "address:" .. openedUnderFlyout
    openedUnderFlyout = nil
    -- next tick, after Hyprland's own refocus
    hl.timer(function()
        local win = hl.get_window(addr)
        local active = hl.get_active_window()
        if not win or (active and active.address == win.address) or not onActiveWorkspace(win) then return end
        hl.dispatch(hl.dsp.focus({ window = addr }))
        hl.dispatch(hl.dsp.window.bring_to_top({ window = addr }))
    end, { timeout = 1, type = "oneshot" })
end)

-- A window moved to another workspace takes on its layout.
hl.on("window.move_to_workspace", function(win, ws)
    if not win or not ws or ws.special then return end
    local on = monocleOn(ws)
    if on ~= inMonocleState(win) then setWindowMonocle(win, on, ws.monitor or win.monitor) end
end)

local function maximizeFocused()
    local win = hl.get_active_window()

    -- a hidden window focused by any route is being asked for: bring it
    -- back and raise it (a re-fit would cut the restore short)
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
        -- monocle windows are raised on focus (Hyprland doesn't raise floaters)
        if hasTag(win, "monocle") then
            -- re-fit one left sized for another monitor
            if win.monitor then placeMonocle(win, win.monitor) end
            hl.dispatch(hl.dsp.window.bring_to_top({ window = "address:" .. win.address }))
        end
        return
    end
    -- by class too: a Quickshell window can be focused before its float lands
    if win.class == "org.quickshell" then return end
    if stateOf(win.address).small then return end

    local mon = hl.get_active_monitor()
    if not mon then return end

    -- a lone window already fills the area with fullscreen=0
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

-- Focusing another window over a fullscreen one drops the fullscreen on
-- Hyprland's side only (it would keep the workspace's input), so the app
-- stays fullscreen in its own eyes and refocusing restores it. Only true
-- fullscreen (2); maximized (1) is dwindle's fill.
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

-- re-checked on close too
hl.on("window.close", maximizeFocused)

hl.on("window.close", function(win)
    if not win then return end
    captureShape(win)
    local last = hl.get_window("address:" .. win.address) or win
    rememberWindow(last)
    rememberPopout(last)
    windowState[win.address] = nil
end)

-- Dialogs stay over the window they came from: focusing a window raises
-- its dialogs over it. Lua isn't told a Wayland dialog's parent, so the
-- owner is the window focused just before it opened, if they share a
-- process or the dialog is a prompt (file chooser, polkit).
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
    -- next tick: the focus change raises the window itself after the hooks
    local addr = win.address
    hl.timer(function() raiseDialogs(addr, 0) end, { timeout = 1, type = "oneshot" })
end)
-- after the rules' and holdPopup's tags are on
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

-- Re-fits every monocle window when the monitors change (dock, undock,
-- resolution, arrangement), keeping their shapes.
local function refitMonocle()
    for _, w in ipairs(hl.get_windows()) do
        if w.floating and hasTag(w, "monocle") and monocleOn(w.workspace) and w.monitor then
            placeMonocle(w, w.monitor)
        end
    end
end

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

-- TABS. These apps open each file as a tab of one Hyprland group, joining
-- the first window of the same class on the workspace.
local TABBED_CLASSES = {
    ["org.pwmt.zathura"] = true,
}

-- a monocle group is refitted as its tab bar comes and goes
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

-- A group down to its last tab is dissolved, once the close has settled.
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

-- SUPER+X. A tiled window uses Hyprland's maximize toggle (deliberate
-- shrinks are recorded so maximizeFocused() leaves them). A monocle floater
-- switches between filled and its last shape (70% centred at first).
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

    -- any other floater: fill it, or put back what filling replaced (70%
    -- centred if it opened full)
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

    -- read the state back: rules can override where the toggle lands
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

-- SUPER+equal/minus: a floater steps through 55%, 70%, 85%, filled, about
-- its centre. A tiled window maximizes or restores.
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

-- SUPER+C: hides a window below the screen, animated per windowAnim (slide,
-- or fade then move), and transparent while hidden. A tiled window is
-- floated first. Focusing it any way restores it (maximizeFocused).
local function hiddenRect(r, mon)
    -- mon.height is in pixels, the layout in logical ones
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

    -- focus the most recently used window left on the workspace (not a
    -- hidden one), once this one is gone
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

-- PARKING. Hyprland keeps sending frames to monocle windows a filled one
-- covers completely, so they're parked below the screen, where they're
-- throttled. Each visible monocle stack keeps everything down to the first
-- covering window plus the one under it. Focusing a parked window brings it
-- back. Popouts, pinned, grouped and shell windows never park. The
-- "parked_x_y_w_h" tag survives a reload.
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

-- back where it was: a monocle window at its shape on its monitor now
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

-- once per burst of events, on the next tick
local parkPending = false
local function scheduleParking()
    if parkPending then return end
    parkPending = true
    hl.timer(function()
        parkPending = false
        syncParking()
    end, { timeout = 1, type = "oneshot" })
end

-- the focused window comes back at once and goes on top, or the next sync
-- would park it again
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

-- SUPER+D and the bar's show-desktop button: hides every showing window on
-- every non-special workspace (tagged "showdesktop"), or brings those back
-- and focuses the last used one. Always instant (no_anim held until drawn).
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

-- After a reload: SUPER+C state and monocle shapes come back from the tags;
-- a window caught mid-fade is moved away now.
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

-- The monocle, natural and fullscreen rules act at map time, so they're
-- switched to the active workspace's layout on every workspace change and
-- on SUPER+M. The toast announces only a change (SUPER+M always).
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
-- wrapped: the handler's workspace argument would toast every change
hl.on("workspace.active", function() applyLayoutRules() end)

-- The app rules' switch: on while none of the app's windows is open or a
-- launch is pending. `closing` is a window still listed on its way out.
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

-- A bind or the launcher just ran something: app rules are on for 4s or
-- until that app opens, and the next window isn't a popout. Called by the
-- launcher through `hyprctl eval`.
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

-- SUPER+M: monocle or dwindle everywhere not pinned, converting the open
-- windows. A pinned workspace stays and the toast says so.
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

    -- every following workspace; hidden windows keep their state
    for _, w in ipairs(hl.get_windows()) do
        if w.workspace and not w.workspace.special and not workspaceLayouts[tostring(w.workspace.id)]
                and not stateOf(w.address).minimized then
            setWindowMonocle(w, monocleEnabled, w.monitor or hl.get_active_monitor())
        end
    end
    scheduleParking()
end
