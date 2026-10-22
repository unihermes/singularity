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

-- Digital vibrance (0..100, 50 = unchanged), per display: the state file
-- has a line "NAME VALUE" for each, and a bare number (the old format)
-- counts for every display. vibrance.frag gets vibranceOf() filled in by
-- Hyprland's display id and is copied to the runtime dir under a name per
-- set of values, so Hyprland recompiles it. Rebuilt when a display comes or
-- goes, as ids follow the connected displays; S.setVibranceOff(true) (from
-- game-keys.lua, while a game has focus) takes it off every display.
do
    local function readVibrance()
        local all, named = 50, {}
        local f = io.open(os.getenv("HOME") .. "/.local/state/singularity/vibrance")
        if f then
            for line in f:lines() do
                local name, v = line:match("^(%S+)%s+(%d+)%s*$")
                if name then named[name] = tonumber(v)
                elseif tonumber(line) then all = tonumber(line) end
            end
            f:close()
        end
        return function(name)
            return math.max(0, math.min(100, named[name] or all))
        end
    end

    local shader, off = "", false
    local function build()
        local of = readVibrance()
        local cases, key = {}, {}
        for _, m in ipairs(hl.get_monitors()) do
            local v = of(m.name)
            if v ~= 50 then
                table.insert(cases, string.format("if (o == %d) return %.2f;", m.id, (v - 50) / 50))
                table.insert(key, m.id .. "-" .. v)
            end
        end
        shader = ""
        local src = #cases > 0 and io.open(os.getenv("HOME") .. "/.config/hypr/vibrance.frag")
        if not src then return end
        local text = src:read("a"):gsub("float vibranceOf%(int o%) { return 0%.0; }",
            "float vibranceOf(int o) { " .. table.concat(cases, " ") .. " return 0.0; }", 1)
        src:close()
        local path = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/singularity-vibrance-"
            .. table.concat(key, "_") .. ".frag"
        local out = io.open(path, "w")
        if out then
            out:write(text)
            out:close()
            shader = path
        end
    end
    local function apply()
        hl.config({ decoration = { screen_shader = off and "" or shader } })
    end

    function S.setVibranceOff(v)
        if v == off then return end
        off = v
        if shader ~= "" then apply() end
    end

    build()
    apply()
    local function rebuild() build() apply() end
    hl.on("monitor.added", rebuild)
    hl.on("monitor.removed", rebuild)
end

-- One workspace per display numbered from the primary (left to right, top
-- to bottom), the rest gathered on the primary. For the Display page's
-- "Reset workspaces", via `hyprctl eval`.
function singularityResetWorkspaces()
    local mons = hl.get_monitors()
    if #mons == 0 then return end
    local primary = mons[1]
    for _, m in ipairs(mons) do
        if m.name == primaryDisplay then primary = m end
    end
    local order = {}
    for _, m in ipairs(mons) do
        if m ~= primary then order[#order + 1] = m end
    end
    table.sort(order, function(a, b) return a.x < b.x or (a.x == b.x and a.y < b.y) end)
    table.insert(order, 1, primary)

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

-- A display plugged in (or the panel back) lays the workspaces out afresh
-- (with the lid shut, lid.sh handles it). From a timer: focusing a display
-- before its workspace exists crashes Hyprland.
local function resetWorkspacesSoon()
    hl.timer(function() singularityResetWorkspaces() end, { timeout = 500, type = "oneshot" })
end
hl.on("monitor.added", function()
    resetWorkspacesSoon()
    hl.exec_cmd("~/.config/hypr/lid.sh displays")
end)
hl.on("monitor.removed", function()
    hl.exec_cmd("~/.config/hypr/lid.sh displays")
end)
hl.on("hyprland.start", resetWorkspacesSoon)
