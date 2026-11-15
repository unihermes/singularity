// A Glass flyout's tab: the body plus the concave flare on each top corner
// that runs it into the bar's edge. A flare is left out on a side that
// touches the screen edge. Panel-local coordinates.
.pragma library

function attachment(width, height, x, screenWidth, anchorX, radius, fillet, atBottom) {
    var left = Math.min(fillet, Math.max(0, x))
    var right = Math.min(fillet, Math.max(0, screenWidth - x - width))
    return { width: width, height: height, flareLeft: left < 1 ? 0 : left, flareRight: right < 1 ? 0 : right,
        radius: Math.max(0, Math.min(radius, width / 2, height / 2)),
        originX: anchorX, originY: atBottom ? height : 0 }
}

// The body's outline as SVG path data for a bar above it, from the left
// flare down round the body and up to the right flare; `closed` adds the
// bar-side edge so it can be filled.
function path(a, closed) {
    var l = a.flareLeft, r = a.flareRight, w = a.width, h = a.height, c = a.radius
    var p = "M" + (-l) + " 0"
    if (l > 0) p += " A" + l + " " + l + " 0 0 1 0 " + l
    p += " L0 " + (h - c) + " A" + c + " " + c + " 0 0 0 " + c + " " + h
        + " L" + (w - c) + " " + h + " A" + c + " " + c + " 0 0 0 " + w + " " + (h - c)
        + " L" + w + " " + r
    if (r > 0) p += " A" + r + " " + r + " 0 0 1 " + (w + r) + " 0"
    return closed ? p + " Z" : p
}
