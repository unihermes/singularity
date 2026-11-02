-- Apply only supported device settings, including locally saved overrides.
local S = require("shared")
local configure, bind, gesture = hl.config, hl.bind, hl.gesture

hl.config = function(config)
    if not S.has("touchpad") then
        if config.input then config.input.touchpad = nil end
        config.gestures = nil
    end
    return configure(config)
end

hl.bind = function(key, ...)
    if type(key) == "string" then
        if key:find("Lid Switch", 1, true) and not S.allows("lid") then return end
        if key:find("XF86MonBrightness", 1, true) and not S.has("backlight") then return end
    end
    return bind(key, ...)
end

hl.gesture = function(...)
    if S.has("touchpad") then return gesture(...) end
end
