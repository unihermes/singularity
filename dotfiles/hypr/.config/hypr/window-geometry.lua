-- Geometry in logical pixels; shapes are fractions of the available area.
local G = {}

local function clamp(n, low, high)
    return math.max(low, math.min(n, high))
end

function G.area(mon, gaps, tabHeight)
    local r = mon.reserved or {}
    gaps = gaps or {}
    local left = (r.left or 0) + (gaps.left or 0)
    local top = (r.top or 0) + (gaps.top or 0) + (tabHeight or 0)
    return {
        x = (mon.x or 0) + left, y = (mon.y or 0) + top,
        w = math.max(1, mon.width / mon.scale - left - (r.right or 0) - (gaps.right or 0)),
        h = math.max(1, mon.height / mon.scale - top - (r.bottom or 0) - (gaps.bottom or 0)),
    }
end

function G.fitted(rect, target)
    return math.abs(rect.x - target.x) <= 4 and math.abs(rect.y - target.y) <= 4
        and math.abs(rect.w - target.w) <= 4 and math.abs(rect.h - target.h) <= 4
end

function G.shape(rect, area, keep)
    local fw = clamp(keep and keep.fw or rect.w / area.w, 1 / area.w, 1)
    local fh = clamp(keep and keep.fh or rect.h / area.h, 1 / area.h, 1)
    return {
        fx = clamp((rect.x - area.x) / area.w, 0, 1 - fw),
        fy = clamp((rect.y - area.y) / area.h, 0, 1 - fh), fw = fw, fh = fh,
    }
end

function G.rect(area, shape)
    if not shape then return { x = area.x, y = area.y, w = area.w, h = area.h } end
    local w, h = clamp(shape.fw * area.w, 1, area.w), clamp(shape.fh * area.h, 1, area.h)
    return {
        x = area.x + clamp(shape.fx * area.w, 0, area.w - w),
        y = area.y + clamp(shape.fy * area.h, 0, area.h - h), w = w, h = h,
    }
end

function G.centred(share)
    return { fx = (1 - share) / 2, fy = (1 - share) / 2, fw = share, fh = share }
end

local LADDER = { 0.55, 0.7, 0.85 }
-- Returns the next shape (nil means fill), and whether anything changed.
function G.step(cur, dir)
    local size = cur and math.max(cur.fw, cur.fh) or 1
    local share
    if dir > 0 then
        if not cur then return nil, false end
        for _, step in ipairs(LADDER) do
            if step > size + 0.01 then share = step break end
        end
    else
        for i = #LADDER, 1, -1 do
            if LADDER[i] < size - 0.01 then share = LADDER[i] break end
        end
        if not share then return cur, false end
    end
    if not share then return nil, true end
    local fw, fh = share, share
    if cur then fw, fh = cur.fw * share / size, cur.fh * share / size end
    local cx, cy = cur and cur.fx + cur.fw / 2 or 0.5, cur and cur.fy + cur.fh / 2 or 0.5
    return { fx = clamp(cx - fw / 2, 0, 1 - fw), fy = clamp(cy - fh / 2, 0, 1 - fh), fw = fw, fh = fh }, true
end

return G
