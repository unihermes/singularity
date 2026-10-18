-- Singularity - Hyprland
-- ~/.config/hypr/window-keys.lua
--
-- The window keys, as globals for binds.lua. Takes the windows.lua helpers
-- it needs.

return function(W)
    local isMonocleWin, stateOf, placeMonocle, captureShape = W.isMonocleWin, W.stateOf, W.placeMonocle, W.captureShape

    -- WINDOW KEYS: SUPER+SHIFT/ALT/CTRL + arrows and SUPER+O. Global so the
    -- binds can reach them.
    --
    -- A monocle window filling its monitor has nowhere to move or grow on it,
    -- so the arrows leave it alone, except that SHIFT+left/right sends it to
    -- the monitor that way. SUPER+X shrinks it first to move or size it by hand.
    local NUDGE = 40
    local ARROWS = { left = { -1, 0 }, right = { 1, 0 }, up = { 0, -1 }, down = { 0, 1 } }

    local function isFullMonocle(win)
        return isMonocleWin(win) and not stateOf(win.address).shape
    end

    -- Re-fits a monocle window to the monitor it landed on. The focus hook
    -- would catch it too, but only on the next focus change.
    local function refitAfterMove(win)
        if not isMonocleWin(win) then return end
        local moved = hl.get_window("address:" .. win.address)
        if moved and moved.monitor then placeMonocle(moved, moved.monitor) end
    end

    -- Tiled: along the layout, and on to the next monitor past its edge.
    -- Floating: nudged, since a floater moved by direction jumps to the edge.
    function moveWindowDir(dir)
        local win = hl.get_active_window()
        if not win then return end
        if not win.floating then
            hl.dispatch(hl.dsp.window.move({ direction = dir }))
        elseif isFullMonocle(win) then
            if dir ~= "left" and dir ~= "right" then return end
            hl.dispatch(hl.dsp.window.move({ monitor = dir == "left" and "l" or "r" }))
            refitAfterMove(win)
        else
            local d = ARROWS[dir]
            hl.dispatch(hl.dsp.window.move({ x = d[1] * NUDGE, y = d[2] * NUDGE, relative = true }))
            captureShape(win)
        end
    end

    -- Tiled only: a floater has no place in the layout to trade. Hyprland
    -- reports a missing neighbour as an error, which is nothing here.
    function swapWindowDir(dir)
        local win = hl.get_active_window()
        if not win or win.floating then return end
        pcall(hl.dispatch, hl.dsp.window.swap({ direction = dir }))
    end

    -- On a tiled window the arrow moves the split it shares with its
    -- neighbour that way. A floater grows to the right and down and shrinks to
    -- the left and up, about its centre.
    function resizeWindowDir(dir)
        local win = hl.get_active_window()
        if not win or isFullMonocle(win) then return end
        local d = ARROWS[dir]
        hl.dispatch(hl.dsp.window.resize({ x = d[1] * NUDGE, y = d[2] * NUDGE, relative = true }))
        captureShape(win)
    end

    function sendToNextMonitor()
        local win = hl.get_active_window()
        if not win or #hl.get_monitors() < 2 then return end
        hl.dispatch(hl.dsp.window.move({ monitor = "+1" }))
        refitAfterMove(win)
    end
end
