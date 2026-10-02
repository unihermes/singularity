// Singularity - Quickshell
// ~/.config/quickshell/services/ChannelPath.js
//
// SVG path data for a channel frame round a stack of touching rectangles:
// a bar group with its grown flyout below (or above) it. Each rect is
// { x0, x1, y0, y1, r }, top to bottom, each one's y1 the next one's y0.
// Outer corners are rounded by the rect's r; where the width steps in or
// out, the inside corner gets a fillet instead.

.pragma library

// A rect's left and right edges, moved onto `fixed`'s where they come
// closer than a corner's worth, so no sliver of a step is left between two
// nearly flush sides.
function snapTo(rect, fixed, fillet) {
    var out = { x0: rect.x0, x1: rect.x1, y0: rect.y0, y1: rect.y1, r: rect.r }
    var near = fillet + Math.max(rect.r, fixed.r)
    for (var k of ["x0", "x1"]) {
        var d = Math.abs(out[k] - fixed[k])
        if (d > 0 && d < near) out[k] = fixed[k]
    }
    return out
}

// The same stack shrunk by d on its outside: convex corners tighten by d,
// fillets widen by d, so the result runs parallel to the original.
function inset(rects, d) {
    var last = rects.length - 1
    return rects.map(function(r, i) {
        return { x0: r.x0 + d, x1: r.x1 - d,
                 y0: i === 0 ? r.y0 + d : r.y0, y1: i === last ? r.y1 - d : r.y1,
                 r: Math.max(0, r.r - d) }
    })
}

function arc(r, x, y, sweep) {
    return " A" + r + " " + r + " 0 0 " + sweep + " " + x + " " + y
}

// closed outline, clockwise from the top-left corner
function outline(R, fillet) {
    var F = fillet
    var t = R[0], b = R[R.length - 1]
    var p = "M" + (t.x0 + t.r) + " " + t.y0 + " L" + (t.x1 - t.r) + " " + t.y0 + arc(t.r, t.x1, t.y0 + t.r, 1)
    for (var i = 0; i < R.length - 1; i++) {
        var u = R[i], v = R[i + 1], y = u.y1
        if (v.x1 > u.x1)
            p += " L" + u.x1 + " " + (y - F) + arc(F, u.x1 + F, y, 0)
                + " L" + (v.x1 - v.r) + " " + y + arc(v.r, v.x1, y + v.r, 1)
        else if (v.x1 < u.x1)
            p += " L" + u.x1 + " " + (y - u.r) + arc(u.r, u.x1 - u.r, y, 1)
                + " L" + (v.x1 + F) + " " + y + arc(F, v.x1, y + F, 0)
    }
    p += " L" + b.x1 + " " + (b.y1 - b.r) + arc(b.r, b.x1 - b.r, b.y1, 1)
        + " L" + (b.x0 + b.r) + " " + b.y1 + arc(b.r, b.x0, b.y1 - b.r, 1)
    for (var j = R.length - 1; j > 0; j--) {
        var w = R[j], z = R[j - 1], yy = w.y0
        if (z.x0 < w.x0)
            p += " L" + w.x0 + " " + (yy + F) + arc(F, w.x0 - F, yy, 0)
                + " L" + (z.x0 + z.r) + " " + yy + arc(z.r, z.x0, yy - z.r, 1)
        else if (z.x0 > w.x0)
            p += " L" + w.x0 + " " + (yy + w.r) + arc(w.r, w.x0 + w.r, yy, 1)
                + " L" + (z.x0 - F) + " " + yy + arc(F, z.x0, yy - F, 0)
    }
    return p + " L" + t.x0 + " " + (t.y0 + t.r) + arc(t.r, t.x0 + t.r, t.y0, 1) + " Z"
}

function roundRect(x0, y0, x1, y1, r) {
    return outline([{ x0: x0, x1: x1, y0: y0, y1: y1, r: r }], 0)
}
