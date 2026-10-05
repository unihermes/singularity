-- Singularity - Hyprland
-- ~/.config/hypr/displays.lua
--
-- Displays: the per-machine rules the Display page saves, the lid's docked
-- mode, the primary display, and laying the workspaces out across them.
-- Settings > Display copies the default rule here to start monitors.lua.

local S = require("shared")

-- The built-in panel switched off while the lid is shut on a docked laptop,
-- so every workspace moves to the other displays as if the panel weren't
-- there. lid.sh decides when: it writes the panel's name to this file and
-- reloads, and removes it and reloads when the lid opens (the reload
-- restores the panel's own rule). Called after the rules, so it wins.
local function panelOffWhileLidShut()
    local f = io.open((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/singularity-lid-docked")
    if not f then return end
    local panel = f:read("l")
    f:close()
    if panel and panel ~= "" then hl.monitor({ output = panel, disabled = true }) end
end

-- The Display page's rules for this machine's displays, in the state
-- directory since they differ per machine. Until it has saved any, one rule
-- for every display: empty output matches them all, which suits a laptop
-- that gets docked. The page copies this rule to start the file.
-- scale 1 is native resolution: everything as small as the panel can draw it.
-- "auto" picks a HiDPI factor on a dense laptop panel, which makes the whole
-- desktop look oversized. Nudge to 1.25 or 1.5 if 1 is too small; fractional
-- values below 1 are not supported.
if not pcall(dofile, os.getenv("HOME") .. "/.local/state/singularity/monitors.lua") then
    hl.monitor({
        output   = "",
        mode     = "preferred",
        position = "auto",
        scale    = 1,
    })
end

panelOffWhileLidShut()

-- Primary display, picked on the Settings window's Display page and handed
-- over the way the Appearance page's settings are: a state file read here, then a
-- config-only reload. Workspace 1 lives on it, the cursor starts on it, and
-- duplicate mode copies it. Empty (the default) leaves all of that to
-- Hyprland, which uses the first display it finds.
--
-- The workspace rule only decides where workspace 1 is *created*, so a
-- workspace that already exists stays put. The Settings page moves it itself
-- when the choice changes, and singularityResetWorkspaces() below does on
-- docking.
local primaryDisplay = S.state("primary-display", "")
if primaryDisplay ~= "" then
    hl.config({ cursor = { default_monitor = primaryDisplay } })
    hl.workspace_rule({ workspace = "1", monitor = primaryDisplay, default = true })
end

-- One workspace per display, numbered from the primary: 1 on the primary,
-- 2 on the next display along (left to right, then top to bottom), and so
-- on. Every other workspace is gathered onto the primary. A global so the
-- Display page's "Reset workspaces" can run it through `hyprctl eval`.
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

-- Layer surfaces -- the bar, the wallpaper -- are only placed again when a
-- monitor rule moves a display, not when Hyprland slides one over because
-- another came or went, so the bar is left mid-screen or off it. A rule
-- moving each display one pixel, at its current mode and scale so nothing
-- modesets, followed by a reload back to the real rules, puts them right.
-- lid.sh runs both after every change of displays.
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

-- A display plugged in (or the panel back on as the lid opens) lays the
-- workspaces out afresh. Plugging or unplugging one with the lid shut is
-- lid.sh's to handle: it switches the panel off or back on to match.
--
-- Run from a timer rather than inside the event: a display is added before
-- its workspace exists, and focusing it then crashes Hyprland. At launch
-- that is every display, so hyprland.start queues it the same way.
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
