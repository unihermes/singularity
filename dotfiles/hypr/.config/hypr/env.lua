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

-- An NVIDIA card running its own driver (the desktop): VA-API and GLX go to
-- NVIDIA's libraries, and Hyprland renders on it rather than on the CPU's
-- integrated GPU, whose outputs nothing is plugged into -- left on the iGPU,
-- every frame would be drawn there and copied across. The iGPU stays listed
-- after it so its outputs still work. Read from sysfs so it holds for any
-- machine, and skipped while the screen is still on the firmware framebuffer.
local function drmCards()
    local nvidia, rest = {}, {}
    for i = 0, 15 do
        local f = io.open("/sys/class/drm/card" .. i .. "/device/vendor")
        if f then
            local vendor = f:read("l")
            f:close()
            table.insert(vendor == "0x10de" and nvidia or rest, "/dev/dri/card" .. i)
        end
    end
    return nvidia, rest
end

local nvidia, rest = drmCards()
local driver = io.open("/sys/module/nvidia_drm")
if driver then driver:close() end
if #nvidia > 0 and driver then
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
    for _, card in ipairs(rest) do table.insert(nvidia, card) end
    hl.env("AQ_DRM_DEVICES", table.concat(nvidia, ":"))
end
