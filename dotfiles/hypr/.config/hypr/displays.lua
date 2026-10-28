-- Singularity - Hyprland
-- ~/.config/hypr/displays.lua
--
-- Displays: the per-machine rules the Display page saves, the lid's docked
-- mode, the primary display, and laying the workspaces out across them.
-- Settings > Display copies the default rule here to start monitors.lua.

local S = require("shared")

-- The built-in panel off while the lid is shut on a docked laptop: lid.sh
-- writes its name here and reloads. After the rules, so it wins.
local function panelOffWhileLidShut()
    local f = io.open((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/singularity-lid-docked")
    if not f then return end
    local panel = f:read("l")
    f:close()
    if panel and panel ~= "" then hl.monitor({ output = panel, disabled = true }) end
end

-- Displays whose native mode is a TV timing (CTA VIC 16) without full-range
-- RGB in their EDID crush blacks and clip whites; the same resolution at PC
-- timings (CVT-RB, 59.94 Hz) reads full range. Keyed on the EDID model name
-- from sysfs; the list is this machine's display-fixes.lua.
local pcTimings = type(S.displayFixes.pcTimings) == "table" and S.displayFixes.pcTimings or {}

local function readAll(cmd)
    local p = io.popen(cmd)
    if not p then return "" end
    local s = p:read("a") or ""
    p:close()
    return s
end

local function pcModeline(output)
    if output == "" or output:find("[^%w%-]") then return nil end
    local edid = readAll("cat /sys/class/drm/card*-" .. output .. "/edid 2>/dev/null")
    for model, line in pairs(pcTimings) do
        if edid:find(model, 1, true) then return line end
    end
end

-- The rule with its TV-timed mode swapped for the PC one, for those displays.
-- Any mode other than the native one is left as chosen.
local function withPcTimings(rule)
    local mode = rule.mode or "preferred"
    if rule.disabled or not (mode == "preferred" or mode:match("^1920x1080@60")) then return rule end
    local line = pcModeline(rule.output or "")
    if not line then return rule end
    local out = {}
    for k, v in pairs(rule) do out[k] = v end
    out.mode = line
    return out
end

-- The Display page's rules for this machine, in the state directory; until
-- it saves any, one catch-all rule (empty output). Scale 1 is native; below
-- 1, XWayland apps blur unless custom.lua sets force_zero_scaling. Every
-- rule goes through withPcTimings.
local monitorRule, named, catchAll = hl.monitor, {}, nil
hl.monitor = function(rule)
    named[rule.output] = true
    if rule.output == "" then catchAll = rule end
    return monitorRule(withPcTimings(rule))
end
if not pcall(dofile, os.getenv("HOME") .. "/.local/state/singularity/monitors.lua") then
    hl.monitor({
        output   = "",
        mode     = "preferred",
        position = "auto",
        scale    = 1,
    })
end
hl.monitor = monitorRule
if catchAll then
    for output in readAll("grep -l '^connected' /sys/class/drm/card*-*/status 2>/dev/null"):gmatch("card%d+%-(%S-)/status") do
        if not named[output] and pcModeline(output) then
            local rule = {}
            for k, v in pairs(catchAll) do rule[k] = v end
            rule.output = output
            hl.monitor(withPcTimings(rule))
        end
    end
end

panelOffWhileLidShut()

-- The primary display (state file from the Display page): workspace 1 and
-- the cursor start there, duplicate copies it; empty leaves it to Hyprland.
-- The rule only places workspace 1 when it's created, so the page and
-- singularityResetWorkspaces() move it.
local primaryDisplay = S.state("primary-display", "")
if primaryDisplay ~= "" then
    hl.config({ cursor = { default_monitor = primaryDisplay } })
    hl.workspace_rule({ workspace = "1", monitor = primaryDisplay, default = true })
end

-- Digital vibrance (0..100, 50 = unchanged): vibrance.frag with the value
-- filled in, as a screen shader, copied to the runtime dir under a name per
-- value so Hyprland recompiles it. S.vibranceOn tells looks.lua.
do
    local vibrance = math.max(0, math.min(100, tonumber(S.state("vibrance", "50")) or 50))
    local shader = ""
    local src = vibrance ~= 50 and io.open(os.getenv("HOME") .. "/.config/hypr/vibrance.frag")
    if src then
        local text = src:read("a"):gsub("const float VIBRANCE = [^;]*;",
            string.format("const float VIBRANCE = %.2f;", (vibrance - 50) / 50), 1)
        src:close()
        local path = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/singularity-vibrance-" .. vibrance .. ".frag"
        local out = io.open(path, "w")
        if out then
            out:write(text)
            out:close()
            shader = path
        end
    end
    S.vibranceOn = shader ~= ""
    hl.config({ decoration = { screen_shader = shader } })
end

-- Displays in the order they were first seen (by EDID description, one per
-- line in the state dir), so each keeps its workspace number: one plugged in
-- later numbers after them and they go back to theirs when it's unplugged.
-- Ones not seen before join the end left to right, top to bottom. The
-- primary comes first all the same; S.orderedMonitors() for game-keys.lua.
local orderPath = os.getenv("HOME") .. "/.local/state/singularity/display-order"

local function displayKey(m)
    return (m.description and m.description ~= "") and m.description or m.name
end

function S.orderedMonitors()
    local mons, rank, count = hl.get_monitors(), {}, 0
    local f = io.open(orderPath)
    if f then
        for line in f:lines() do
            if line ~= "" and not rank[line] then
                count = count + 1
                rank[line] = count
            end
        end
        f:close()
    end
    local new = {}
    for _, m in ipairs(mons) do
        if not rank[displayKey(m)] then new[#new + 1] = m end
    end
    if #new > 0 then
        table.sort(new, function(a, b) return a.x < b.x or (a.x == b.x and a.y < b.y) end)
        local out = io.open(orderPath, "a")
        for _, m in ipairs(new) do
            count = count + 1
            rank[displayKey(m)] = count
            if out then out:write(displayKey(m), "\n") end
        end
        if out then out:close() end
    end
    local function key(m)
        return m.name == primaryDisplay and 0 or rank[displayKey(m)]
    end
    table.sort(mons, function(a, b) return key(a) < key(b) end)
    return mons
end

-- One workspace per display in that order, the rest gathered on the first.
-- For the Display page's "Reset workspaces", via `hyprctl eval`.
function singularityResetWorkspaces()
    local order = S.orderedMonitors()
    if #order == 0 then return end
    local primary = order[1]

    for _, ws in ipairs(hl.get_workspaces()) do
        if not ws.special and ws.id > #order and ws.monitor and ws.monitor.name ~= primary.name then
            hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(ws.id), monitor = primary.name }))
        end
    end
    -- Backwards, so the primary is focused last. A workspace that doesn't
    -- exist yet is created on whichever display has focus.
    for i = #order, 1, -1 do
        local name = order[i].name
        if hl.get_workspace(i) then
            hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(i), monitor = name }))
        else
            hl.dispatch(hl.dsp.focus({ monitor = name }))
        end
        hl.dispatch(hl.dsp.focus({ workspace = i }))
    end
end

-- Layer surfaces aren't re-placed when Hyprland slides a display over, so a
-- one-pixel monitor-rule nudge and a reload put them right; lid.sh runs it
-- after display changes.
function singularityNudgeDisplays()
    for _, m in ipairs(hl.get_monitors()) do
        if not m.is_mirror then
            hl.monitor({
                output    = m.name,
                mode      = string.format("%dx%d@%.3f", m.width, m.height, m.refresh_rate),
                position  = (m.x + 1) .. "x" .. m.y,
                scale     = m.scale,
                transform = m.transform,
            })
        end
    end
end

-- The workspace layout from before a display was plugged in, one file per
-- set of displays (so they stack), kept in the runtime dir through reloads:
-- "ws <id> <display>", "active <display> <id>" and "focus <display>" lines.
-- Unplugging back to that set puts every workspace that was there back on
-- its display, showing what it showed; ones opened since stay put.
local runtimeDir = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
local layoutPrefix = runtimeDir .. "/singularity-workspaces-"

local function monitorNames()
    local names = {}
    for _, m in ipairs(hl.get_monitors()) do names[#names + 1] = m.name end
    table.sort(names)
    return names
end

local function layoutPath(names)
    return layoutPrefix .. table.concat(names, "+")
end

local knownMonitors = monitorNames()

local function saveLayout(names)
    local keep = {}
    for _, n in ipairs(names) do keep[n] = true end
    local lines = {}
    for _, ws in ipairs(hl.get_workspaces()) do
        if not ws.special and ws.monitor and keep[ws.monitor.name] then
            lines[#lines + 1] = "ws " .. ws.id .. " " .. ws.monitor.name
        end
    end
    for _, m in ipairs(hl.get_monitors()) do
        if keep[m.name] and m.active_workspace then
            lines[#lines + 1] = "active " .. m.name .. " " .. m.active_workspace.id
        end
    end
    local focused = hl.get_active_monitor()
    if focused and keep[focused.name] then lines[#lines + 1] = "focus " .. focused.name end
    local f = io.open(layoutPath(names), "w")
    if not f then return end
    f:write(table.concat(lines, "\n"), "\n")
    f:close()
end

local function restoreLayout()
    local path = layoutPath(monitorNames())
    local f = io.open(path)
    if not f then return end
    local moves, active, focus = {}, {}, nil
    for line in f:lines() do
        local id, mon = line:match("^ws (%-?%d+) (%S+)$")
        if id then moves[#moves + 1] = { id = tonumber(id), mon = mon } end
        local am, aid = line:match("^active (%S+) (%-?%d+)$")
        if am then active[#active + 1] = { mon = am, id = tonumber(aid) } end
        focus = line:match("^focus (%S+)$") or focus
    end
    f:close()
    os.remove(path)

    for _, mv in ipairs(moves) do
        local ws = hl.get_workspace(mv.id)
        if ws and ws.monitor and ws.monitor.name ~= mv.mon then
            hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(mv.id), monitor = mv.mon }))
        end
    end
    -- The focused display last, so it keeps focus. An empty workspace went
    -- when the reset moved it, so it's made again on its display.
    table.sort(active, function(a, b) return b.mon == focus and a.mon ~= focus end)
    for _, a in ipairs(active) do
        local ws = hl.get_workspace(a.id)
        if not ws then hl.dispatch(hl.dsp.focus({ monitor = a.mon })) end
        if not ws or (ws.monitor and ws.monitor.name == a.mon) then
            hl.dispatch(hl.dsp.focus({ workspace = a.id }))
        end
    end
end

-- A display plugged in (or the panel back) saves the layout and lays the
-- workspaces out afresh; one unplugged puts the saved layout back (with the
-- lid shut, lid.sh handles the panel). From a timer: focusing a display
-- before its workspace exists crashes Hyprland.
local function resetWorkspacesSoon()
    hl.timer(function() singularityResetWorkspaces() end, { timeout = 500, type = "oneshot" })
end
hl.on("monitor.added", function()
    local now, before, was = monitorNames(), {}, {}
    for _, n in ipairs(knownMonitors) do was[n] = true end
    for _, n in ipairs(now) do
        if was[n] then before[#before + 1] = n end
    end
    knownMonitors = now
    if #before > 0 and #before < #now then saveLayout(before) end
    resetWorkspacesSoon()
    hl.exec_cmd("~/.config/hypr/lid.sh displays")
end)
hl.on("monitor.removed", function()
    hl.timer(function()
        knownMonitors = monitorNames()
        restoreLayout()
    end, { timeout = 500, type = "oneshot" })
    hl.exec_cmd("~/.config/hypr/lid.sh displays")
end)
hl.on("hyprland.start", function()
    os.execute("rm -f '" .. layoutPrefix .. "'*")
    resetWorkspacesSoon()
end)
