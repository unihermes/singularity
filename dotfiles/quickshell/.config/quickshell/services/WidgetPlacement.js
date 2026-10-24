// Singularity - Quickshell
// ~/.config/quickshell/services/WidgetPlacement.js
//
// Where the desktop widgets sit (desktop/). A rect is { x, y, w, h } in
// screen pixels; the area is the screen less the bar's strip. A placed
// widget is stored as fractions of the room the area leaves it, so it
// keeps to its edge or its middle on a screen of another size.

.pragma library

// the screen less the bar's strip
function area(screenW, screenH, barExtent, barAtBottom) {
    return { x: 0, y: barAtBottom ? 0 : barExtent, w: screenW, h: screenH - barExtent }
}

// Where each starts out: the clock in the bottom left corner with the
// weather a gap beside it, the stats top right with a sticky note a gap
// under them, the to-do top left, the music bottom right.
// sizes holds the shown widgets' { w, h }.
function startRect(key, sizes, a, margin, gap) {
    var s = sizes[key] || { w: 0, h: 0 }
    var bottom = a.y + a.h - margin - s.h
    var right = a.x + a.w - margin - s.w
    if (key === "clock") return { x: a.x + margin, y: bottom, w: s.w, h: s.h }
    if (key === "weather") {
        var c = sizes.clock
        return { x: a.x + margin + (c ? c.w + gap : 0), y: bottom, w: s.w, h: s.h }
    }
    if (key === "stats") return { x: right, y: a.y + margin, w: s.w, h: s.h }
    if (key === "todo") return { x: a.x + margin, y: a.y + margin, w: s.w, h: s.h }
    if (key.indexOf("note") === 0) {
        var st = sizes.stats
        return { x: right, y: a.y + margin + (st ? st.h + gap : 0), w: s.w, h: s.h }
    }
    return { x: right, y: bottom, w: s.w, h: s.h }
}

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

// its rect from the stored fractions, or where it starts out
function rectOf(key, place, sizes, a, margin, gap) {
    var s = sizes[key] || { w: 0, h: 0 }
    if (place.fx < 0 || place.fy < 0) return startRect(key, sizes, a, margin, gap)
    return {
        x: Math.round(a.x + clamp(place.fx, 0, 1) * Math.max(0, a.w - s.w)),
        y: Math.round(a.y + clamp(place.fy, 0, 1) * Math.max(0, a.h - s.h)),
        w: s.w, h: s.h
    }
}

// the fractions that store a rect
function fractionsOf(r, a) {
    var fx = a.w > r.w ? (r.x - a.x) / (a.w - r.w) : 0
    var fy = a.h > r.h ? (r.y - a.y) / (a.h - r.h) : 0
    return { fx: clamp(fx, 0, 1), fy: clamp(fy, 0, 1) }
}

// The lines a dragged widget is drawn to: the area's thirds and middle,
// the margin in from each edge, and the other widgets' edges, both in line
// with them and a gap beside them. Each axis snaps the widget's near edge,
// middle or far edge to the closest line within reach; the result is kept
// inside the area. guides lists the lines it took, as { dir: "v" | "h", at }.
function snap(r, a, margin, reach, others, gap) {
    others = others || []
    function axis(pos, size, start, len, near, span) {
        var lines = [start + len / 3, start + len / 2, start + len * 2 / 3]
        var edges = [{ at: start + margin, off: 0 }, { at: start + len - margin, off: size }]
        var best = null
        function tryLine(at, off) {
            var d = Math.abs(pos + off - at)
            if (d <= reach && (!best || d < best.d)) best = { d: d, pos: at - off, at: at }
        }
        for (var i = 0; i < lines.length; i++) {
            tryLine(lines[i], 0)
            tryLine(lines[i], size / 2)
            tryLine(lines[i], size)
        }
        for (var j = 0; j < edges.length; j++) tryLine(edges[j].at, edges[j].off)
        for (var k = 0; k < others.length; k++) {
            var o0 = others[k][near], o1 = o0 + others[k][span]
            tryLine(o0, 0); tryLine(o1, size); tryLine(o0, size); tryLine(o1, 0)
            tryLine(o1 + gap, 0); tryLine(o0 - gap, size)
        }
        var p = clamp(best ? best.pos : pos, start, start + Math.max(0, len - size))
        return { pos: Math.round(p), at: best && Math.round(best.pos) === Math.round(p) ? best.at : null }
    }
    var h = axis(r.x, r.w, a.x, a.w, "x", "w")
    var v = axis(r.y, r.h, a.y, a.h, "y", "h")
    var guides = []
    if (h.at !== null) guides.push({ dir: "v", at: Math.round(h.at) })
    if (v.at !== null) guides.push({ dir: "h", at: Math.round(v.at) })
    return { x: h.pos, y: v.pos, w: r.w, h: r.h, guides: guides }
}
