-- Singularity - Hyprland
-- ~/.config/hypr/autostart.lua
--
-- What starts with the session: the shell, its helpers and daemons, and
-- the XDG autostart entries managed from Settings > Startup.

local S = require("shared")

hl.on("hyprland.start", function()
    -- Not UWSM, so graphical-session.target is never reached, and units
    -- that hang off it (rather than D-Bus activation) have to be started by
    -- hand. Starting the unit rather than the binary keeps its
    -- respawn-on-crash and cgroup.
    --
    -- reset-failed first: after Hyprland crashes and is restarted, the unit
    -- has usually hit its start limit respawning into a missing Wayland
    -- socket, and a plain `start` is then refused.
    hl.exec_cmd("systemctl --user reset-failed hyprpolkitagent.service; systemctl --user start hyprpolkitagent.service")
    -- Same for hypridle; the fallback runs it bare if the unit is missing.
    hl.exec_cmd("systemctl --user reset-failed hypridle.service; systemctl --user start hypridle.service || hypridle")
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
