#!/usr/bin/env python3
# Nerd Font glyphs as inline SVG, for HTML mockups of the shell.
#
# Icon glyphs sit in the font's private-use area, so a page that shows them
# as text needs the font itself, and a browser that won't load it (blocked
# data: fonts, fingerprinting protection hiding local fonts) shows empty
# boxes. Outlines drawn as SVG paths show everywhere.
#
#   glyph-svg.py F057E F00AF ...      one <svg> per codepoint, as JSON
#   glyph-svg.py --font PATH ...      another font (default: the shell's)
#
# Each SVG is 1em square, centred on the glyph's advance like the text cell,
# filled with currentColor; size it with font-size or width/height.
# Needs fontTools (pip install fonttools).

import argparse
import json
import sys

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

DEFAULT_FONT = "/usr/share/fonts/TTF/UbuntuMonoNerdFont-Regular.ttf"


def glyph_svg(font, cp):
    cmap = font.getBestCmap()
    name = cmap.get(cp)
    if name is None:
        return None
    gs = font.getGlyphSet()
    asc = font["hhea"].ascent
    desc = -font["hhea"].descent
    adv = gs[name].width
    line = asc + desc
    # flip y so the baseline sits `asc` from the top, as a text line does
    pen = SVGPathPen(gs)
    gs[name].draw(TransformPen(pen, (1, 0, 0, -1, 0, asc)))
    d = pen.getCommands()
    # a square box one line tall, centred on the advance
    x = (adv - line) / 2
    return (f'<svg class="glyph" viewBox="{x:.0f} 0 {line} {line}" width="1em" height="1em" '
            f'fill="currentColor" aria-hidden="true"><path d="{d}"/></svg>')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("codepoints", nargs="+", help="hex codepoints, e.g. F057E")
    ap.add_argument("--font", default=DEFAULT_FONT)
    args = ap.parse_args()
    font = TTFont(args.font)
    out, missing = {}, []
    for c in args.codepoints:
        cp = int(c.removeprefix("U+").removeprefix("0x"), 16)
        svg = glyph_svg(font, cp)
        if svg is None:
            missing.append(c)
        else:
            out[f"{cp:X}"] = svg
    if missing:
        print("not in the font: " + " ".join(missing), file=sys.stderr)
    json.dump(out, sys.stdout, indent=1)
    print()


if __name__ == "__main__":
    main()
