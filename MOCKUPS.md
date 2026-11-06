# Making mockups that match the shell

A mockup is only useful if choosing from it tells you what the shell will look
like. Abstract boxes, invented colours and a generic UI font don't: the pick
gets made on the mockup and then looks different on screen. Draw the real
thing, from the real numbers, and check it against a screenshot of the real
shell.

Mockups are self-contained interactive HTML artifacts (see `AGENTS.md`). Never
commit them or their helper files.

## Quick recipe (for local models such as Ollama)

The sidebar's Ollama models read this section only. Do these in order and
keep the whole page small.

1. Run `qs ipc call theme css`. Paste the `:root { ... }` block into the page
   unchanged. It holds the user's real colours, spacing, radii, bar and row
   sizes, and `--font`. Use only `var(--...)` for colours and sizes: no hex
   codes, no px values of your own. `--panel` is a flyout's ground,
   `--surface` fields and section grounds, `--overlay` hover and selected
   fill, `--base` meter tracks, `--subtext` secondary text, `--accent` marks.
2. Set `font-family: var(--font), monospace; font-size: var(--font-size)`.
   Icons are Nerd Font glyphs in that same font; don't use emoji.
3. Put the mockup on the real bar: a `--bar-height` strip in `--bar`, the
   modules in a row, then the flyout `--flyout-offset` below the top, with
   `--radius-panel` corners and `--panel-pad` padding, on a dark wallpaper
   colour. Never draw a flyout on an empty page.
4. Inside the flyout, each run of rows between headings is its own box:
   `--surface` ground, `--radius-section` corners, `--space-s` gaps. Rows are
   `--row-height` tall, chips and segmented buttons `--chip-height`. Selected
   things use `--selected-fill` with a `--selected-stroke` outline; hover uses
   `--hover-fill`.
5. Use the user's real content (names, numbers, apps), plus one long name and
   one disabled row. Make hover, click, toggles and sliders work.
6. Several options for several elements: give each element its own picker and
   render the whole mockup from one state object like
   `{header:"B", rows:"A", controls:"C"}`. Every combination must look right;
   never offer "Option 1/2/3" as whole designs only. Start on what the shell
   has today and add a Reset button.
7. Add a "Copy picks" button at the top and the bottom that copies the state
   object as text, and leave 200px of padding at the bottom.

Everything below is the long form of the same rules.

## 1. Start from the live shell, not from memory

Before drawing anything:

1. **Screenshot what exists.** Run `grim` on the main monitor (DP-2 on the
   desktop) with the module's flyout, window or overlay open. `CLAUDE.md`
   says how to open a flyout from a temporary `IpcHandler` in `shell.qml`;
   remove it afterwards. Read the PNG and keep it as the reference for every
   check below.
2. **Read the user's real settings**, not the defaults:
   `~/.local/state/singularity/appearance.json` (look, accent, bar height,
   spacing, roundness, font, font size, style, bar layout).
3. **Read the tokens.** `qs ipc call theme css` prints the live values as a
   CSS `:root` block; use it as the base. `services/Theme.qml` is the source for every size and
   colour; `services/Looks.js` has each look's ten-role palette and accent.
   `qs/DESIGN.md` describes the frames and layouts (grep its `##` headings
   and read only the section you need).
4. **Read the QML of the thing you're mocking**: `flyouts/FlyoutPanel.qml`,
   `PanelFrame.qml`, `SectionRuns.qml`, the module's own `*Flyout.qml`, and the
   shared rows it uses (`FlyoutRow`, `FlyoutHeading`, `FlyoutSegmented`,
   `FlyoutChip`, `Slider`, `Meter`...). Use
   `python3 tools/context.py qs/flyouts/FlyoutRow.qml` for a quick outline.

## 2. Copy the tokens into CSS variables

Put every value in `:root` once and use only the variables below it. Nothing
in the mockup should be a number or colour that isn't traceable to `Theme`
or the user's settings.

**Colour roles** (from the active look's palette in `Looks.js`, or the
user's colour overrides):

```css
:root {
  --base:#0b0b0b; --bar:#121212; --panel:#141414; --surface:#1a1a1a;
  --overlay:#242424; --border:#303030; --muted:#4d4d4d; --subtext:#7a7a7a;
  --text:#d0e2fa; --bright:#ebebeb;
  --accent:#5555c8; --good:#7d9b7d; --alert:#a87676;
}
```

Use the roles as the shell does: `panel` is a flyout's ground, `surface` the
fields and section grounds, `overlay` hover and selected fills, `base` meter
tracks, `muted` unselected strokes, `subtext` secondary text. Don't pick
"a slightly lighter grey" by eye.

**Spacing and size.** `Theme.sp(n)` is `round(n * spacing / 100)`, and every
text size goes through `Theme.fs(n)`, which scales with Font Size. Compute
the real pixel values for the user's settings and name them like the shell
does:

```css
:root {
  --space-xs:2px; --space-s:4px; --space-m:6px; --space-l:8px;
  --space-xl:12px; --space-xxl:16px;
  --panel-pad:10px; --window-pad:16px;
  --radius:6px;                 /* Settings.radius */
  --radius-section:9px;         /* radius + 3 */
  --bar-height:32px;
  --font-size:16px;             /* fs(16) */
}
```

Derived values (`panelFrameRadius`, `channelWidth`, `sectionInset`,
`flyoutOffset`, `moduleHeight`) are formulas in `Theme.qml`; compute them
rather than guessing.

**Font.** The shell uses one font for text and icons, a non-Mono Nerd Font
(default UbuntuMono Nerd Font). Load the real file with `@font-face` from
`file:///usr/share/fonts/TTF/UbuntuMonoNerdFont-Regular.ttf`, set the
user's family and size, and match `line-height` to the QML row heights.

**Icons.** Don't substitute emoji, Lucide or Font Awesome. Use the same Nerd
Font codepoints the QML uses. If the browser won't load the font in the
viewer, `tools/glyph-svg.py F057E F00AF ...` emits each glyph as an inline
SVG outline that sizes with `font-size`.

## 3. Build with the shell's own structure

- **Same components, same nesting.** A flyout is a `FlyoutPanel` holding
  section runs: each run of rows between headings and dividers sits in its
  own frame, not under divider lines. Build the mockup out of the same
  pieces (heading, row, segmented control, chip line, slider, meter) with
  the same padding. If the QML has a component for it, the mockup has a
  matching class for it.
- **The frame follows the style.** Channel, double stroke, single stroke or
  ground-only frames come from the current style and `Theme.controlBorder()`.
  Draw the user's actual style (`DESIGN.md` has each), not a plain
  `border: 1px solid`.
- **Include the surroundings.** Draw the real bar (its height, its
  modules in the user's `barLayout` order, the hovered module) with the
  flyout hung off it at `flyoutOffset`, and the wallpaper behind it. A flyout
  floating on an empty background is the most common reason a mockup feels
  abstract. For windows and overlays, show them over the wallpaper at the
  size they open at (`windowSize`).
- **Real content.** Use the user's actual devices, network names, apps,
  tracks and numbers, plus the awkward cases: a long name that truncates,
  an empty list, a value at 100%, a disabled row. Lorem ipsum and "Item 1"
  hide layout problems.
- **Real states.** Show hover, selected, focused and pressed using
  `hoverFill`, `selectedFill` and `selectedStroke`, and make hovering and
  clicking actually work where the shell's does.
- **Real behaviour.** Wire the controls the way they'll work: toggles toggle,
  sliders drag, the segmented control switches content, and a row that opens
  a sub-page does open it. Check against `DESIGN.md` "Wording and
  behaviour".
- **Respect gates.** If a row only exists with a capability (battery,
  backlight, lid), say so or show it only in the matching hardware case.

## 4. Check fidelity before showing it

1. Render the mockup in a headless browser at 1:1 pixels, with the
   device-pixel ratio of the monitor you screenshotted:
   `floorp --headless --no-remote --profile <scratch dir> --screenshot out.png file://<path>`
2. Put it next to the `grim` screenshot of the current shell. Existing
   elements (bar, unchanged rows, the frame) must be indistinguishable in
   size, spacing, colour, radius and text. Zoom in on corners, strokes and
   text baselines.
3. Anything that differs and wasn't meant to is a bug in the mockup. Fix it
   from the tokens, not by nudging pixels.
4. Click through every interaction once (a jsdom run is fine for the picks
   logic) and check no console errors.

If the mockup can't be made to match the existing parts, don't ship it: the
new parts will be judged against something that doesn't look like the
shell.

## 5. Options must be independent

When a mockup offers choices for several elements of the same design (for
example the header, the row layout, the control style, the bar module), the
choices are **separate axes**, not bundled variants.

- **Every element gets its own picker.** The user can choose header B with
  rows A and controls C. Never present "Option 1 / Option 2 / Option 3" as
  three whole designs when the pieces could be mixed.
- **Any combination must work.** Each variant of an element has to be
  designed to sit next to any variant of every other element. If B-header and
  C-rows can't coexist, the options weren't independent: redesign them so
  they can, or split the axis differently.
- **The preview is live and composed.** Selecting an option re-renders the
  whole mockup with the current choice on every axis, so the user sees the
  combination they'd get. Build it from a state object, e.g.
  `{header:"B", rows:"A", controls:"C"}`, and render from it. Don't swap
  between pre-drawn images.
- **Defaults and reset.** Start each axis on what the shell has today, and
  offer a reset to that.
- **Show the options side by side as well.** A small strip of each axis's
  options (all drawn with the other axes held at the current choice) helps
  compare, but the strip never replaces the composed preview.
- **Whole-design presets are extras.** Named bundles ("A system", "B system")
  are fine as shortcuts that set every axis at once, but the user must be
  able to change any axis afterward.
- **Record picks per axis, per page.** Save `{axis: choice}` plus a note for
  each page or subpage, with a "use this for every page" shortcut, and a
  Copy picks button at the top and bottom (keep large bottom padding so
  the viewer doesn't hide it). Save them in the artifact's `db`, one doc per
  page: `picks/<page>` with `{choices:{...}, note}`. Read them back when the
  user says they're done.
- **Options span every subpage.** A choice for a module applies across its
  subpages and overlays (e.g. the Super+W grid), and may change the bar
  module itself (what it shows, what clicking does), not just the flyout.

## Checklist

- [ ] Screenshot of the live shell taken as the reference
- [ ] Tokens read from `appearance.json`, `Theme.qml`, `Looks.js`; all in `:root`
- [ ] Real font and real Nerd Font glyphs
- [ ] Same component structure, frames and section runs as the QML
- [ ] Real bar and wallpaper around the flyout/window
- [ ] Real content, long names, empty and disabled states
- [ ] Hover, selected and focus states and behaviour work
- [ ] Headless screenshot compared against the live one at 1:1
- [ ] Each element has its own independent picker; every combination renders
- [ ] Picks saved per page, copyable from the top and the bottom
- [ ] Nothing mockup-related staged for commit
