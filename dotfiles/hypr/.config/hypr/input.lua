-- Singularity - Hyprland
-- ~/.config/hypr/input.lua
--
-- Keyboard, mouse, touchpad and gestures. Settings > Input reads the plain
-- fields of the input table here, and writes its own changes to
-- hyprland.json (see overrides.lua).

hl.config({
    input = {
        kb_layout     = "us",
        follow_mouse  = 0,
        sensitivity   = 0.1,
        accel_profile = "adaptive",
        left_handed = false,

        touchpad = {
            natural_scroll       = false,
            disable_while_typing = true,
            scroll_factor        = 0.7,
            -- the .conf spelling is tap-to-click; the lua schema takes the
            -- underscored form, since dashes are not a bare Lua identifier
            tap_to_click         = true,
            clickfinger_behavior = true,
        },
    },

    -- stops the cursor from jumping to whatever gets focused, e.g. the
    -- Quickshell workspace bar's click-to-focus icons
    cursor = {
        no_warps = true,
    },
})

-- Swipe left, go left: uninverted, to match natural_scroll = false above.
hl.config({
    gestures = {
        workspace_swipe_invert = false,
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
