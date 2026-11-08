-- Hold known tray apps off-screen only during their startup handshake.
-- The launcher releases each hold when its tray is ready. A compositor
-- timer also releases it if the launcher exits or the app never gets ready.
local M = {}
local holds = {}
local classes = {
    spotify = { "spotify", "Spotify" },
    equicord = { "discord", "Discord" },
    discord = { "discord", "Discord" },
    steam = { "steam", "Steam" },
}

local function recover(hold)
    local ws = hl.get_active_workspace()
    local target = ws and not ws.special and ws.id or hold.workspace
    if not target then return end
    for _, win in ipairs(hl.get_windows()) do
        if win.workspace and win.workspace.name == hold.hidden then
            hl.dispatch(hl.dsp.window.move({ window = "address:" .. win.address,
                workspace = target, follow = false }))
        end
    end
end

function M.finish(key)
    local hold = holds[key]
    if not hold then return end
    holds[key] = nil
    hold.rule:set_enabled(false)
    -- Allow the close request to unmap the window. If it refuses (a login
    -- prompt, for example), return it to a regular workspace instead.
    hl.timer(function() recover(hold) end, { timeout = 1000, type = "oneshot" })
end

function M.start(key)
    local names = classes[key]
    if not names or holds[key] then return end
    -- A second invocation must not disturb an app already in use.
    for _, win in ipairs(hl.get_windows()) do
        for _, name in ipairs(names) do
            if win.class == name then return end
        end
    end
    local ws = hl.get_active_workspace()
    local hold = { hidden = "special:autostart-" .. key, workspace = ws and ws.id }
    hold.rule = hl.window_rule({
        name = "autostart-tray-" .. key,
        match = { class = "^(" .. table.concat(names, "|") .. ")$" },
        workspace = hold.hidden .. " silent",
        no_focus = true,
    })
    holds[key] = hold
    hl.timer(function()
        if holds[key] == hold then M.finish(key) end
    end, { timeout = 65000, type = "oneshot" })
end

-- Reloading the config discards rules and timers; release any old holds.
local stale = {}
for _, win in ipairs(hl.get_windows()) do
    local name = win.workspace and win.workspace.name
    if name and name:find("^special:autostart%-") then stale[name] = true end
end
for name in pairs(stale) do recover({ hidden = name, workspace = 1 }) end

return M
