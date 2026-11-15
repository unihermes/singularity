// A Glass flyout's outline: a rounded body under the bar, and a neck up
// through the bar round the open module's chip (rounded like the chip) that
// joins the body on concave rounded connectors, so chip and body read as one
// shape. A top corner next to the bar is square where the body touches the
// screen's edge, so no gap opens there. Panel-local coordinates, y = 0 at
// the body's bar-side edge, the bar above it (negative y).
.pragma library

// neck: { x0, x1 (the chip's span), top (its top edge, negative), radius },
// or null for a body alone; flare caps the connectors' size (default the radius)
function attachment(width, height, x, screenWidth, anchorX, radius, atBottom, neck, flare) {
    var c = Math.max(0, Math.min(radius, width / 2, height / 2))
    var a = { width: width, height: height, radius: c,
        originX: anchorX, originY: atBottom ? height : 0,
        cornerLeft: x < 1 ? 0 : c, cornerRight: screenWidth - x - width < 1 ? 0 : c,
        neck: null }
    if (neck && neck.x1 > neck.x0 && neck.top < 0) {
        var x0 = Math.max(0, neck.x0), x1 = Math.min(width, neck.x1)
        var rc = Math.max(0, Math.min(neck.radius, (x1 - x0) / 2, -neck.top / 2))
        // each connector needs room between the neck and its body corner
        var f = Math.min(c, flare === undefined ? c : flare)
        var fl = Math.min(f, x0 - a.cornerLeft, -neck.top)
        var fr = Math.min(f, width - a.cornerRight - x1, -neck.top)
        a.neck = { x0: x0, x1: x1, top: neck.top, radius: rc,
            flareLeft: fl < 1 ? 0 : fl, flareRight: fr < 1 ? 0 : fr }
    }
    return a
}

function arc(r, sweep, x, y) { return " A" + r + " " + r + " 0 0 " + sweep + " " + x + " " + y }

// The outline as SVG path data, turning counterclockwise on screen. Closed:
// the body alone, for filling. Open: the whole outline, neck included, for
// stroking.
function path(a, closed) {
    var w = a.width, h = a.height, c = a.radius, l = a.cornerLeft, r = a.cornerRight
    var n = closed ? null : a.neck
    // the body's far side: down to the bottom corners and up the right
    var bottom = " L0 " + (h - c) + arc(c, 0, c, h) + " L" + (w - c) + " " + h + arc(c, 0, w, h - c)
    var topLeft = l > 0 ? arc(l, 0, 0, l) : ""
    if (!n) return "M" + l + " 0" + topLeft + bottom + " L" + w + " " + r + (r > 0 ? arc(r, 0, w - r, 0) : "") + " Z"
    var t = n.top, rc = n.radius, fl = n.flareLeft, fr = n.flareRight
    var p = "M" + n.x0 + " " + (t + rc)
    if (n.x0 > 0) {
        // down the neck, out along the body's top to its corner, and round
        p += " L" + n.x0 + " " + (-fl) + (fl > 0 ? arc(fl, 1, n.x0 - fl, 0) : "") + " L" + l + " 0" + topLeft + bottom
    } else {
        // the neck's left side is the body's
        p += bottom
    }
    if (n.x1 < w) {
        p += " L" + w + " " + r + (r > 0 ? arc(r, 0, w - r, 0) : "") + " L" + (n.x1 + fr) + " 0"
            + (fr > 0 ? arc(fr, 1, n.x1, -fr) : "") + " L" + n.x1 + " " + (t + rc)
    } else {
        p += " L" + w + " " + (t + rc)
    }
    // the chip's rounded top
    return p + arc(rc, 0, n.x1 - rc, t) + " L" + (n.x0 + rc) + " " + t + arc(rc, 0, n.x0, t + rc) + " Z"
}
