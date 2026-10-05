-- Singularity - Hyprland
-- ~/.config/hypr/alttab.lua
--
-- Windows-style alt-tab, with the switcher drawn by Quickshell
-- (AltTabSwitcher.qml). Hold ALT and tap Tab to move the highlight, release
-- ALT to focus what you landed on.
--
-- Nothing is focused until the release. Hyprland's own cycle_next focuses as
-- it walks, so previewing a window meant raising it and resizing the layout;
-- keeping the selection in Quickshell makes stepping free, and gives
-- SHIFT+Tab a working reverse direction, which the dispatcher never had.
--
-- There is no submap: Hyprland (0.56.2) never delivers a modifier release
-- to a submap bind. The switcher takes the keyboard itself and catches the
-- release in Keys.onReleased, and with no submap there's no mode for the
-- keyboard to get stuck in.
--
-- Every Tab of a held ALT+Tab comes through the binds, not just the first:
-- Hyprland matches its own binds before forwarding keys to any client, so they
-- win over the switcher's keyboard grab and Keys.onPressed never sees a Tab.
-- The shell's onAltTabTab is idempotent to suit -- it opens the switcher on
-- the first Tab and steps it on the ones after. SHIFT+Tab and grave need their own
-- binds for the same reason; they would otherwise never reach the shell.
-- `repeating` on each so holding the key autorepeats.
--
-- alttab-ipc.sh reaches the shell through alttab-relay (autostart.lua),
-- which also reads the window list from Hyprland; `qs ipc call` (~45ms just
-- to start) is only the fallback. See alttab-relay.cpp.
--
-- The ALT release is also watched here, in-process. The switcher's grab
-- only sees a release that happens after it is up, and an ALT let go while
-- the first Tab is still on its way would otherwise reach no one, leaving
-- the switcher holding the keyboard. hl.is_key_down reads Hyprland's own key
-- state, so altTabWatch polls it from the moment the bind fires and sends
-- the commit when ALT comes up. Keys.onReleased stays the fast path;
-- whichever notices first wins, and the shell drops the second.
--
-- Chained oneshots rather than a `repeat` timer: a Lua timer only stops
-- once collected, so a repeating one fires on long after it's wanted.
--
-- Each gesture gets a generation number, sent with every command, so the
-- shell matches a release to the exact Tab it belongs to and never opens a
-- switcher for a gesture whose ALT is already up. It also retires any chain
-- left over from an earlier gesture.
local altTabWatchGen = 0
local altTabWatchTimer = nil

-- `sends` counts commits already sent for this release. Two extras follow
-- the first, as insurance against it being lost while the Tab is still in
-- flight; the shell drops repeats for a gesture it has committed.
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
