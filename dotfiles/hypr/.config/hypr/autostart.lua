-- Singularity - Hyprland
-- ~/.config/hypr/autostart.lua
--
-- What starts with the session: the shell, its helpers and daemons, and
-- the XDG autostart entries managed from Settings > Startup.

local S = require("shared")

hl.on("hyprland.start", function()
    -- Not UWSM, so graphical-session.target is brought up by
    -- hyprland-session.target (dotfiles/systemd), which the shutdown handler
    -- below takes down again. The units that hang off it (rather than D-Bus
    -- activation) aren't enabled, so they're started by hand. Starting the
    -- unit rather than the binary keeps its respawn-on-crash and cgroup.
    --
    -- reset-failed first: after Hyprland crashes and is restarted, the
    -- session units have usually hit their start limit respawning into a
    -- missing Wayland socket, and a plain `start` is then refused. The
    -- hypridle fallback runs it bare if the unit is missing.
    hl.exec_cmd("systemctl --user reset-failed hyprpolkitagent.service hypridle.service"
        .. " xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service;"
        .. " systemctl --user start hyprland-session.target;"
        .. " systemctl --user start hyprpolkitagent.service;"
        .. " systemctl --user start hypridle.service || hypridle")
    -- Stop logind suspending on lid close: the lid binds in binds.lua just blank the
    -- screen, and hypridle suspends after 20 min idle. Released when
    -- Hyprland exits (waitpid blocks on a pidfd; it doesn't poll).
    hl.exec_cmd("systemd-inhibit --what=handle-lid-switch --who=Hyprland --why='Hyprland handles the lid' waitpid $(pidof -s Hyprland)")
    -- QML warnings go to a log rather than the TTY. `exec` replaces the
    -- /bin/sh that hl.exec_cmd wraps this in, so no idle shell sits in the
    -- tree as quickshell's parent (same for the relay below).
    hl.exec_cmd("exec quickshell > ~/.cache/quickshell.log 2>&1")
    -- The ALT+Tab switcher's IPC relay (alttab-relay.cpp). It finds
    -- Quickshell lazily, so order doesn't matter. QT_FORCE_STDERR_LOGGING
    -- keeps its self-test messages in the log file rather than the journal.
    hl.exec_cmd("exec env QT_FORCE_STDERR_LOGGING=1 ~/.config/hypr/alttab-relay > ~/.cache/alttab-relay.log 2>&1")
    -- Lifts the shadows on displays that show them darker than the others
    -- (display-curve.c), the ones this machine's display-fixes.lua lists
    -- under toneCurves (see shared.lua). Matched by model, so the lift
    -- follows a monitor between ports.
    do
        local args = {}
        for model, exponent in pairs(type(S.displayFixes.toneCurves) == "table" and S.displayFixes.toneCurves or {}) do
            if type(model) == "string" and tonumber(exponent) then
                args[#args + 1] = "'" .. model:gsub("'", "") .. "=" .. tonumber(exponent) .. "'"
            end
        end
        if #args > 0 then
            hl.exec_cmd("exec ~/.config/hypr/display-curve " .. table.concat(args, " ") .. " > ~/.cache/display-curve.log 2>&1")
        end
    end
    -- env alone does not retheme the cursor Hyprland draws over the desktop
    hl.exec_cmd("hyprctl setcursor " .. S.cursorTheme .. " " .. S.cursorSize)
    -- the saved wallpaper, or a random one from wallpapers/ when shuffle is on
    hl.exec_cmd("~/.config/hypr/wallpaper.sh")
    -- clipboard history daemon (cliphist needs this to capture every copy)
    hl.exec_cmd("wl-paste --watch cliphist store")
    -- XDG autostart, which Hyprland does not run itself: the .desktop files
    -- in ~/.config/autostart, managed from Settings > Startup. Last, so a
    -- user entry starts against a session that already has its bar, its
    -- notification daemon and its wallpaper -- an entry that opens a window
    -- otherwise races the bar for the screen. See the script's header for
    -- which entries it runs and why a package's own entry is opt-in.
    hl.exec_cmd("~/.config/singularity/autostart.sh run")
end)

-- Stop the session's units while the compositor is still here to see them
-- off, rather than leaving them to crash on its closed socket and respawn
-- into nothing until they hit their start limit. --no-block: a unit being
-- stopped is never restarted, so queueing the stop jobs is enough, and
-- Hyprland isn't held up waiting on them. io.popen rather than hl.exec_cmd
-- so it has run before Hyprland goes on to exit (and unsets the Wayland
-- variables it gave systemd). Logging out from the session menu does the
-- same first (Session.qml), since that ends everything in the session at
-- once, Hyprland and this included.
hl.on("hyprland.shutdown", function()
    local p = io.popen("systemctl --user stop --no-block hyprland-session.target")
    if p then p:read("a"); p:close() end
end)
