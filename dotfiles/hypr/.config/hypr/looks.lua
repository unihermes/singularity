-- Singularity - Hyprland
-- ~/.config/hypr/looks.lua
--
-- How windows look and move: gaps, borders, rounding, shadows, blur, the
-- grouped windows' tab bar, animations. Values mostly come from state files
-- Appearance writes; its own field changes go to hyprland.json
-- (overrides.lua).

local S = require("shared")

-- The scratchpad (SUPER+grave) is a special workspace, and a workspace can
-- only slide or fade, so the styles that don't slide show it as a fade.
local scratchStyle = S.windowSlides and "slidevert" or "fade"

-- "<active> <inactive>" border colours when borders follow the accent
local borderActive, borderInactive = S.state("borders", ""):match("^(%S+)%s+(%S+)$")

-- the tab bar's colours from the look; absent, the group defaults below
local tabActive, tabInactive, tabText, tabTextInactive, tabAccent =
    S.state("groupbar", ""):match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$")

-- Window corner radius, written by the Appearance page from the shell's panel
-- corners so windows and panels round alike; absent, 6.
local windowRounding = tonumber(S.state("rounding", "")) or 6

-- The gap at the screen's edges, written by the Appearance page from its bar
-- shape, so a floating bar and the windows keep the same gap; absent, 0.
local edgeGap = tonumber(S.state("gaps", "")) or 0

-- "<focused> <unfocused>" window opacity from the Appearance page, 0-1;
-- absent, both opaque
local activeOpacity, inactiveOpacity = S.state("window-opacity", ""):match("^(%S+)%s+(%S+)$")
activeOpacity   = tonumber(activeOpacity) or 1
inactiveOpacity = tonumber(inactiveOpacity) or 1

-- "<border width> <shadow>" from the Appearance page: the border's width,
-- and the shadow ("none", "small", "soft" -- the style's -- or "large")
local windowBorder, windowShadow = S.state("window-frame", ""):match("^(%d+)%s+(%a+)$")
windowBorder = tonumber(windowBorder) or 1
windowShadow = windowShadow or "soft"
local shadowRange = ({ small = 8, soft = 18, large = 34 })[windowShadow] or 18

-- the open tab's fill with an accent line along its top, as the last stops
-- of a vertical gradient (the groupbar has no colour for it)
local function tabFill(fill, accent)
    local colors = {}
    for i = 1, 18 do colors[i] = fill end
    colors[19], colors[20] = accent, accent
    return { colors = colors, angle = 270 }
end

-- `factor` is the Appearance page's own speed for the leaf's kind
local function animation(t)
    t.speed   = t.speed * S.animFactor * (t.factor or 1)
    t.factor  = nil
    t.enabled = t.enabled and not S.animOff
    hl.animation(t)
end

hl.config({
    general = {
        gaps_in     = 1,
        gaps_out    = edgeGap,
        border_size = windowBorder,

        col = {
            active_border   = borderActive or "rgba(d0e2fa66)",
            inactive_border = borderInactive or "rgba(303030aa)",
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding         = windowRounding,
        rounding_power   = 2,
        active_opacity   = activeOpacity,
        inactive_opacity = inactiveOpacity,
        dim_inactive = true,
        dim_strength = 0.4,

        -- black at 40 percent, blurred as far as the size says
        shadow = {
            enabled      = windowShadow ~= "none",
            range        = shadowRange,
            render_power = 3,
            offset       = "0 0",
            color        = "rgba(00000066)",
        },

        blur = {
            enabled    = true,
            size       = 12,
            passes     = 2,
            noise      = 0.015,
            contrast   = 0.9,
            brightness = 0.7,
        },
    },

    animations = {
        enabled = not S.animOff,
    },

    dwindle = {
        preserve_split = true,
    },

    -- Groups are only made by the TABS hooks in windows.lua, so a new window never
    -- joins whichever group has focus, and dragging one never merges it in.
    group = {
        auto_group      = false,
        drag_into_group = 0,
        -- the tab fills, so the border runs on from the tab bar instead of
        -- drawing an accent line between it and the window
        col = {
            border_active   = tabActive or "rgba(2a2a2aff)",
            border_inactive = tabInactive or "rgba(161616ff)",
        },
        groupbar = {
            height              = S.GROUPBAR_HEIGHT,
            -- tabs edge to edge (0.57 rejects anything below 0)
            gaps_in             = 0,
            gaps_out            = 0,
            font_family         = "UbuntuMono Nerd Font",
            font_size           = 13,
            -- room either side, so a long title's "…" isn't against the edge
            text_padding        = 10,
            gradients           = true,
            rounding            = 3,
            gradient_rounding   = 3,
            indicator_height    = 0,
            middle_click_close  = true,
            text_color          = tabText or "rgba(d0e2faff)",
            text_color_inactive = tabTextInactive or "rgba(7a7a7aff)",
            col = {
                active   = tabFill(tabActive or "rgba(2a2a2aff)", tabAccent or "rgba(d0e2faff)"),
                inactive = tabInactive or "rgba(161616ff)",
            },
        },
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        -- any key or mouse movement turns a blanked screen back on, whatever
        -- blanked it -- not only hypridle's own screens-off step
        key_press_enables_dpms  = true,
        mouse_move_enables_dpms = true,
    },

    -- direct scanout for windows tagged as games only (1 can flicker); off
    -- with vibrance on, as a scanned-out game would skip the screen shader
    render = {
        direct_scanout = S.vibranceOn and 0 or 2,
    },
})

hl.curve("singularity", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })

-- speed is in 100ms units (2 = 200ms), so lower is faster; the shell's
-- Theme.durFast/Medium/Slow are these 1, 1.5 and 2, on the same curve
local windowSpeed, fadeSpeed = S.windowSpeed, S.fadeSpeed
local windowStyle, windowsAnimate = S.windowStyle, S.windowsAnimate
animation({ leaf = "global",     enabled = true, speed = 2, bezier = "singularity" })
animation({ leaf = "border",     enabled = true, speed = 2, bezier = "singularity" })
local win, ws = S.windowsFactor, S.workspacesFactor
animation({ leaf = "windows",    enabled = true, speed = windowSpeed, factor = win, bezier = "singularity", style = windowStyle })
animation({ leaf = "windowsIn",  enabled = windowsAnimate, speed = windowSpeed, factor = win, bezier = "singularity", style = windowStyle })
animation({ leaf = "windowsOut", enabled = windowsAnimate, speed = 1.5, factor = win, bezier = "singularity", style = windowStyle })
animation({ leaf = "fade",       enabled = true, speed = fadeSpeed, factor = win, bezier = "singularity" })
animation({ leaf = "fadeIn",     enabled = windowsAnimate, speed = fadeSpeed, factor = win, bezier = "singularity" })
animation({ leaf = "fadeOut",    enabled = windowsAnimate, speed = fadeSpeed, factor = win, bezier = "singularity" })
animation({ leaf = "workspaces", enabled = true, speed = 2, factor = ws, bezier = "singularity", style = "slidefade 12%" })
animation({ leaf = "specialWorkspace", enabled = windowsAnimate, speed = windowSpeed, factor = ws, bezier = "singularity",
            style = scratchStyle })

-- layers (flyouts) faster than global, fading
animation({ leaf = "layersIn",  enabled = true, speed = 1, bezier = "singularity", style = "fade" })
animation({ leaf = "layersOut", enabled = true, speed = 1, bezier = "singularity", style = "fade" })
-- the shell's surfaces blur what's behind (Glass, See-through);
-- ignore_alpha leaves fully transparent parts unblurred. Overlays on a
-- display scaled under 1 are "unblurred-..." (OverlayWindow.qml), outside it
hl.layer_rule({
    name  = "shell-blur",
    match = { namespace = "^(quickshell|singularity-.*)$" },
    blur  = true,
    ignore_alpha = 0.2,
})
