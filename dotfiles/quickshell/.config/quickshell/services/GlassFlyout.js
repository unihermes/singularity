// A Glass flyout's body and its short neck, in panel-local coordinates.
// The neck stays under the source module even when the body hits a screen edge.
.pragma library

function attachment(width, height, anchorX, anchorWidth, gap, radius, fillet, atBottom) {
    var neckWidth = Math.min(width, Math.max(1, anchorWidth))
    var neck = { x0: anchorX - neckWidth / 2, x1: anchorX + neckWidth / 2,
        y0: atBottom ? height : -gap, y1: atBottom ? height + gap : 0, r: 0 }
    var body = { x0: 0, x1: width, y0: 0, y1: height,
        r: Math.max(0, Math.min(radius, width / 2, height / 2)) }
    return { neck: neck, rects: atBottom ? [body, neck] : [neck, body],
        fillet: Math.min(fillet, gap), originX: anchorX, originY: atBottom ? height + gap : -gap }
}
