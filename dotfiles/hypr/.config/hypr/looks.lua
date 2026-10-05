-- Singularity - Hyprland
-- ~/.config/hypr/looks.lua
--
-- How windows look and move: gaps, borders, rounding, shadows, blur, the tab
-- bar over grouped windows, and the animations. Most values come from state
-- files the Appearance page writes; Settings > Appearance reads the plain
-- fields under general and decoration here, and writes its own changes to
-- hyprland.json (see overrides.lua).
--
-- grayscale ramp, shared with every other config in this repo:
--   #0b0b0b base   #121212 bar    #1a1a1a surface  #242424 overlay
--   #303030 border #4d4d4d muted  #7a7a7a subtext  #d0e2fa text
--   #ebebeb bright

local S = require("shared")

-- The scratchpad (SUPER+grave) is a special workspace, and a workspace can
-- only slide or fade, so the styles that don't slide show it as a fade.
local scratchStyle = S.windowSlides and "slidevert" or "fade"

-- "<active> <inactive>" border colours, written by the Appearance page when
-- borders follow the shell's accent; otherwise absent, and the colours
-- under general below apply.
local borderActive, borderInactive = S.state("borders", ""):match("^(%S+)%s+(%S+)$")

-- "<active tab> <inactive tab> <active text> <inactive text> <accent>" for
-- the tab bar over grouped windows (see TABS in windows.lua), written by the
-- Appearance page from the current look; absent, the colours under group
-- below apply.
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

-- "<border width> <shadow>" from the Appearance page's style: the border
-- as thick as the shell's strokes, and its shadow ("none", "soft", "hard")
local windowBorder, windowShadow = S.state("window-frame", ""):match("^(%d+)%s+(%a+)$")
windowBorder = tonumber(windowBorder) or 1
windowShadow = windowShadow or "soft"
local hardShadow = windowShadow == "hard"

-- The open tab's fill, with a line of the accent along its top edge. The
-- groupbar has no colour of its own for that line (its indicator shares the
-- fill's colour), so it's the last stops of a vertical gradient: the last
-- two of twenty are the accent, a line about 2px thick on a 26px bar.
local function tabFill(fill, accent)
    local colors = {}
    for i = 1, 18 do colors[i] = fill end
    colors[19], colors[20] = accent, accent
    return { colors = colors, angle = 270 }
end

local function animation(t)
    t.speed   = t.speed * S.animFactor
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

        -- soft: black at 40 percent, blurred; hard: a solid offset copy
        shadow = {
            enabled      = windowShadow ~= "none",
            range        = hardShadow and 2 or 18,
            render_power = hardShadow and 1 or 3,
            offset       = hardShadow and "4 4" or "0 0",
            color        = hardShadow and "rgba(000000ff)" or "rgba(00000066)",
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
            -- tabs edge to edge: -1 rather than 0, since tab widths are
            -- fractional and 0 leaves a hairline between them
            gaps_in             = -1,
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

    -- A fullscreen game's frames go straight to the display, skipping
    -- compositing; 2 limits it to windows tagged as games, where 1 (every
    -- fullscreen window) can flicker on some apps.
    render = {
        direct_scanout = 2,
    },
})

hl.curve("singularity", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })

-- speed is in 100ms units (3 = 300ms), so lower is faster
local windowSpeed, fadeSpeed = S.windowSpeed, S.fadeSpeed
local windowStyle, windowsAnimate = S.windowStyle, S.windowsAnimate
animation({ leaf = "global",     enabled = true, speed = 3, bezier = "singularity" })
animation({ leaf = "border",     enabled = true, speed = 3, bezier = "singularity" })
animation({ leaf = "windows",    enabled = true, speed = windowSpeed, bezier = "singularity", style = windowStyle })
animation({ leaf = "windowsIn",  enabled = windowsAnimate, speed = windowSpeed, bezier = "singularity", style = windowStyle })
animation({ leaf = "windowsOut", enabled = windowsAnimate, speed = 1.5, bezier = "singularity", style = windowStyle })
animation({ leaf = "fade",       enabled = true, speed = fadeSpeed, bezier = "singularity" })
animation({ leaf = "fadeIn",     enabled = windowsAnimate, speed = fadeSpeed, bezier = "singularity" })
animation({ leaf = "fadeOut",    enabled = windowsAnimate, speed = fadeSpeed, bezier = "singularity" })
animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "singularity", style = "slidefade 12%" })
animation({ leaf = "specialWorkspace", enabled = windowsAnimate, speed = windowSpeed, bezier = "singularity",
            style = scratchStyle })

-- Layer surfaces: wofi and the bar's flyouts. Faster than `global`, which
-- they'd otherwise inherit, since a launcher should appear at once. fade
-- rather than popin, since the bar is a layer too.
animation({ leaf = "layersIn",  enabled = true, speed = 1, bezier = "singularity", style = "fade" })
animation({ leaf = "layersOut", enabled = true, speed = 1, bezier = "singularity", style = "fade" })
-- The shell's surfaces (the bar is "quickshell", the rest "singularity-*")
-- blur what's behind their see-through grounds, which the Glass style and a
-- See-through below 100% rely on. ignore_alpha leaves the transparent rest
-- of a full-screen flyout surface, and the faint edge of a soft shadow,
-- unblurred.
hl.layer_rule({
    name  = "shell-blur",
    match = { namespace = "^(quickshell|singularity-.*)$" },
    blur  = true,
    ignore_alpha = 0.2,
})
