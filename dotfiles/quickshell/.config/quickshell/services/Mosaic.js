// The launcher's Mosaic layout: tiles of a few sizes packed into a grid of
// columns, and the arrow keys' walk between them.
//   pack(spans, columns)   [[w, h], ...] in cells -> [{ x, y, w, h }], each
//                          tile in the first free spot reading left to right,
//                          top to bottom, so small tiles fill the gaps big
//                          ones leave
//   step(rects, from, dx, dy, ok)
//                          the index the arrow (dx, dy) moves to from `from`,
//                          among the tiles ok(i) allows; `from` when none lies
//                          that way

.pragma library

function pack(spans, columns) {
    var used = []   // used[row][col]
    function free(x, y, w, h) {
        if (x + w > columns) return false
        for (var r = y; r < y + h; r++)
            for (var c = x; c < x + w; c++)
                if (used[r] && used[r][c]) return false
        return true
    }
    var out = []
    for (var i = 0; i < spans.length; i++) {
        var w = Math.min(spans[i][0], columns), h = spans[i][1]
        for (var y = 0, placed = false; !placed; y++) {
            for (var x = 0; x <= columns - w; x++) {
                if (!free(x, y, w, h)) continue
                for (var r = y; r < y + h; r++) {
                    if (!used[r]) used[r] = []
                    for (var c = x; c < x + w; c++) used[r][c] = true
                }
                out.push({ x: x, y: y, w: w, h: h })
                placed = true
                break
            }
        }
    }
    return out
}

// the nearest tile wholly past the current one's edge the arrow's way; the
// sideways offset counts double, so Down picks the tile under you over a
// nearer diagonal
function step(rects, from, dx, dy, ok) {
    var a = rects[from]
    if (!a) return from
    var ax = a.x + a.w / 2, ay = a.y + a.h / 2
    var best = from, bestScore = Infinity
    for (var i = 0; i < rects.length; i++) {
        if (i === from || (ok && !ok(i))) continue
        var b = rects[i]
        var bx = b.x + b.w / 2, by = b.y + b.h / 2
        var past = dx > 0 ? b.x >= a.x + a.w : dx < 0 ? b.x + b.w <= a.x
            : dy > 0 ? b.y >= a.y + a.h : b.y + b.h <= a.y
        if (!past) continue
        var along = dx !== 0 ? Math.abs(bx - ax) : Math.abs(by - ay)
        var across = dx !== 0 ? Math.abs(by - ay) : Math.abs(bx - ax)
        var score = along + across * 2
        if (score < bestScore) { bestScore = score; best = i }
    }
    return best
}
