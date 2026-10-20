-- Singularity - Hyprland
-- ~/.config/hypr/autostart.lua
--
-- What starts with the session: the shell, its helpers and daemons, and
-- the XDG autostart entries managed from Settings > Startup.

local S = require("shared")

hl.on("hyprland.start", function()
    -- hyprland-session.target brings up graphical-session.target (no UWSM);
    -- its units are started by hand (keeping respawn and cgroup), after
    -- reset-failed for a restart after a crash; hypridle runs bare without
    -- its unit.
    hl.exec_cmd("systemctl --user reset-failed hyprpolkitagent.service hypridle.service"
        .. " xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service;"
        .. " systemctl --user start hyprland-session.target;"
        .. " systemctl --user start hyprpolkitagent.service;"
        .. " systemctl --user start hypridle.service || hypridle")
    -- logind's lid handling inhibited until Hyprland exits (lid.sh handles it)
    hl.exec_cmd("systemd-inhibit --what=handle-lid-switch --who=Hyprland --why='Hyprland handles the lid' waitpid $(pidof -s Hyprland)")
    -- QML warnings to a log; `exec` so no idle sh is left as the parent
    hl.exec_cmd("exec quickshell > ~/.cache/quickshell.log 2>&1")
    -- ALT+Tab's IPC relay; QT_FORCE_STDERR_LOGGING keeps it in its log
    hl.exec_cmd("exec env QT_FORCE_STDERR_LOGGING=1 ~/.config/hypr/alttab-relay > ~/.cache/alttab-relay.log 2>&1")
    -- lifts shadows on displays display-fixes.lua's toneCurves lists,
    -- matched by model
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
    -- XDG autostart (Settings > Startup), last, so entries find the bar up
    hl.exec_cmd("~/.config/singularity/autostart.sh run")
end)

-- Stops the session's units while the compositor is still up (they'd crash
-- and respawn on its closed socket). io.popen, so it runs before exit;
-- --no-block, so Hyprland isn't held up. Session.qml's logout does the same.
hl.on("hyprland.shutdown", function()
    local p = io.popen("systemctl --user stop --no-block hyprland-session.target")
    if p then p:read("a"); p:close() end
end)
