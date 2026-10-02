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
// within `near`, so no hairline of a step is left between two nearly
// flush sides.
function snapTo(rect, fixed, near) {
    var out = { x0: rect.x0, x1: rect.x1, y0: rect.y0, y1: rect.y1, r: rect.r }
    for (var k of ["x0", "x1"]) {
        var d = Math.abs(out[k] - fixed[k])
        if (d > 0 && d <= near) out[k] = fixed[k]
    }
    return out
}

function arc(r, x, y, sweep) {
    return " A" + r + " " + r + " 0 0 " + sweep + " " + x + " " + y
}

// The closed outline, clockwise from the top-left corner, shrunk by d so a
// band drawn inside it runs parallel: sides and ends move in by d, convex
// corners tighten by d, fillets widen by d, and each step's horizontal edge
// moves into whichever rect it belongs to (down into a wider rect below,
// up into a wider rect above). A step narrower than its fillet and corner
// together scales both down to fit, so it reads as a short jog.
function outline(R, fillet, d) {
    d = d || 0
    var n = R.length
    // a step's fillet and convex corner, inset by d; `r` is the wider
    // rect's corner radius and `w` the step's width at d = 0
    function step(w, r) {
        var k = Math.min(1, Math.abs(w) / Math.max(1, fillet + r))
        return { F: fillet * k + d, r: Math.max(0, r * k - d) }
    }
    var X0 = R.map(function(r) { return r.x0 + d })
    var X1 = R.map(function(r) { return r.x1 - d })
    var rad = R.map(function(r) { return Math.max(0, r.r - d) })
    var top = R[0].y0 + d, bottom = R[n - 1].y1 - d

    var p = "M" + (X0[0] + rad[0]) + " " + top + " L" + (X1[0] - rad[0]) + " " + top
        + arc(rad[0], X1[0], top + rad[0], 1)
    for (var i = 0; i < n - 1; i++) {
        var y = R[i].y1
        if (X1[i + 1] > X1[i]) {
            var so = step(R[i + 1].x1 - R[i].x1, R[i + 1].r)
            var ys = y + d
            p += " L" + X1[i] + " " + (ys - so.F) + arc(so.F, X1[i] + so.F, ys, 0)
                + " L" + (X1[i + 1] - so.r) + " " + ys + arc(so.r, X1[i + 1], ys + so.r, 1)
        } else if (X1[i + 1] < X1[i]) {
            var si = step(R[i].x1 - R[i + 1].x1, R[i].r)
            var yi = y - d
            p += " L" + X1[i] + " " + (yi - si.r) + arc(si.r, X1[i] - si.r, yi, 1)
                + " L" + (X1[i + 1] + si.F) + " " + yi + arc(si.F, X1[i + 1], yi + si.F, 0)
        }
    }
    var l = n - 1
    p += " L" + X1[l] + " " + (bottom - rad[l]) + arc(rad[l], X1[l] - rad[l], bottom, 1)
        + " L" + (X0[l] + rad[l]) + " " + bottom + arc(rad[l], X0[l], bottom - rad[l], 1)
    for (var j = n - 1; j > 0; j--) {
        var yy = R[j].y0
        if (X0[j - 1] < X0[j]) {
            var su = step(R[j].x0 - R[j - 1].x0, R[j - 1].r)
            var yu = yy - d
            p += " L" + X0[j] + " " + (yu + su.F) + arc(su.F, X0[j] - su.F, yu, 0)
                + " L" + (X0[j - 1] + su.r) + " " + yu + arc(su.r, X0[j - 1], yu - su.r, 1)
        } else if (X0[j - 1] > X0[j]) {
            var sd = step(R[j - 1].x0 - R[j].x0, R[j].r)
            var yd = yy + d
            p += " L" + X0[j] + " " + (yd + sd.r) + arc(sd.r, X0[j] + sd.r, yd, 1)
                + " L" + (X0[j - 1] - sd.F) + " " + yd + arc(sd.F, X0[j - 1], yd - sd.F, 0)
        }
    }
    return p + " L" + X0[0] + " " + (top + rad[0]) + arc(rad[0], X0[0] + rad[0], top, 1) + " Z"
}

function roundRect(x0, y0, x1, y1, r) {
    return outline([{ x0: x0, x1: x1, y0: y0, y1: y1, r: r }], 0, 0)
}
