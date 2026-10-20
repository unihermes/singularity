-- Singularity - Hyprland
-- ~/.config/hypr/alttab.lua
--
-- Windows-style ALT+Tab, drawn by Quickshell (AltTabSwitcher.qml); nothing
-- is focused until ALT comes up, so stepping is free and SHIFT+Tab works.
--
-- No submap: Hyprland never delivers a modifier release to one; the
-- switcher grabs the keyboard instead. Every Tab (and SHIFT+Tab, grave)
-- comes through the binds, which win over the grab; the shell's
-- onAltTabTab opens on the first and steps after. alttab-ipc.sh reaches the
-- shell through alttab-relay, `qs ipc call` only as the fallback.
--
-- The ALT release is also polled here (hl.is_key_down), as one before the
-- switcher is up would reach no one; whichever route notices first wins.
-- Chained oneshots, since a repeating Lua timer outlives its use. Each
-- gesture's generation number goes with every command, so the shell matches
-- a release to its Tab, and old chains retire.
local altTabWatchGen = 0
local altTabWatchTimer = nil

-- `sends` counts commits sent for this release: two extras follow the first
-- in case it's lost in flight; the shell drops repeats
local function altTabWatch(gen, sends)
    if gen ~= altTabWatchGen then return end

    if hl.is_key_down("Alt_L") or hl.is_key_down("Alt_R") then
        altTabWatchTimer = hl.timer(function() altTabWatch(gen, 0) end,
            { timeout = 24, type = "oneshot" })
        return
    end

    hl.exec_cmd("~/.config/hypr/alttab-ipc.sh commit " .. gen)

    if sends >= 2 then
        altTabWatchTimer = nil
        return
    end

    altTabWatchTimer = hl.timer(function() altTabWatch(gen, sends + 1) end,
        { timeout = 90, type = "oneshot" })
end

-- Armed by every alt-tab bind, retiring the previous chain. The generation
-- is bumped before the command runs, so both carry the same id.
local function altTabKey(cmd)
    return function()
        altTabWatchGen = altTabWatchGen + 1
        local gen = altTabWatchGen
        hl.exec_cmd(cmd .. " " .. gen)
        altTabWatchTimer = hl.timer(function() altTabWatch(gen, 0) end,
            { timeout = 24, type = "oneshot" })
    end
end

return altTabKey
