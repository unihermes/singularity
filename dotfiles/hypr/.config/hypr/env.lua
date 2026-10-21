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
-- GTK's settings.ini with the cursor (AppearanceSync writes it), for X11 apps
-- that read no gsettings: GTK ones, and Chromium/Electron through GTK
local configDirs = os.getenv("XDG_CONFIG_DIRS")
local xdg = os.getenv("HOME") .. "/.local/state/singularity/xdg"
if not (configDirs or ""):find(xdg, 1, true) then
    hl.env("XDG_CONFIG_DIRS", xdg .. ":" .. ((configDirs or "") ~= "" and configDirs or "/etc/xdg"))
end
-- Quickshell's icon theme (Qt has none configured); must be in the env at
-- launch, as `//@ pragma Env` is applied too late for it
hl.env("QS_ICON_THEME", S.state("icons", "kora"))

-- An NVIDIA card on its own driver: VA-API, GLX and Hyprland's rendering go
-- to it, the iGPU listed after. From sysfs; skipped while still on the
-- firmware framebuffer.
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
    -- nvidia-vaapi-driver opens /dev/nvidia* itself, which Zen's and
    -- Floorp's media decoder (RDD) sandbox forbids, so without this their
    -- video falls back to CPU decoding (see browserPrefs in AppearanceSync).
    hl.env("MOZ_DISABLE_RDD_SANDBOX", "1")
    for _, card in ipairs(rest) do table.insert(nvidia, card) end
    hl.env("AQ_DRM_DEVICES", table.concat(nvidia, ":"))
end
