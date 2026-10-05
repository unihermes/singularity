-- Singularity - Hyprland
-- ~/.config/hypr/env.lua
--
-- The session's environment variables.

local S = require("shared")

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")
-- The pointer and icon themes picked on the Appearance page, which writes
-- them to state files.
hl.env("XCURSOR_THEME", S.cursorTheme)
hl.env("XCURSOR_SIZE", S.cursorSize)
hl.env("HYPRCURSOR_THEME", S.cursorTheme)
hl.env("HYPRCURSOR_SIZE", S.cursorSize)
-- Icon theme for Quickshell's window icons and Applications list. GTK and
-- wofi get it from gsettings, but Quickshell is Qt and Qt has no theme
-- configured here, so without this it falls back to each app's stock
-- hicolor icon (Thunar's hammer instead of kora's folder). It has to be in
-- the environment at launch: Quickshell reads it before its own
-- `//@ pragma Env` lines are applied, so setting it from shell.qml is ignored.
hl.env("QS_ICON_THEME", S.state("icons", "kora"))
