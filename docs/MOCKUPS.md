# Mockups

How UI choices get made here: mock first, in the real look, let the user pick, then
build and record. The starter template is a local file, kept out of the repo (mockups and their
supporting files are never committed): `~/.claude/projects/-home-giordano-Singularity/memory/mockup-template.html`.
Copy it, fill in the modules, and deliver it as an artifact in chat (not a file in Downloads).

## The loop

1. **Review from the code, not from memory.** For each element, read its QML and the
   Settings it already has (`services/Settings.qml`, `SettingsValues.js`,
   `settings/appearance/BarTab.qml`). Write two or three honest UX notes per element.
   Say in the page that the review is from code, not screenshots, when it is.
2. **Find what already exists before proposing.** Many proposals turn out to be in the
   shell already (a drag-to-move, a connected card, tabs). Check, and don't offer it as
   new. A pick that already exists costs nothing and builds trust.
3. **Options are switches, not alternatives.** Pick-one-of-three (A/B/C) read as
   either/or and hid that most ideas combine. Each idea is its own control, and the
   mockup is rebuilt from the state, so the user composes the result and sees it.
4. **Tag every control by where it comes from:**
   - `Settings`: already a setting the user has. Shown so the mockup reflects what they
     have; never changed by the pass. List them in a "Already in Settings" line.
   - `New`: a proposal. Off (or the first choice) means the current design.
   - `Preview`: only changes the state being shown (muted, low battery, nothing
     playing, disconnected). Use these so empty and alert states can be judged.
5. **Always allow "keep current".** A per-page reset that turns every New control off.
   Defaults of New controls are the current design.
6. **Comments per page.** A textarea on each tab. Comments are instructions and win over
   a toggle that conflicts with them ("keep the module chip" overrides a bar-shows pick).
7. **Collect the picks.** A fixed bar at the bottom lists only what differs from today
   (New controls changed, plus 💬 for comments); "Copy picks" writes each page as
   `Name / Changes: … / Comment: …`. The user pastes that back as the brief.
8. **Deliver as an artifact in chat** (four-backtick fence, `artifact html Title`),
   not a file the user has to go find. Re-send the whole artifact on every change.

## Fidelity

The mock is the shell itself, so the page keeps the shell's dark look.

- **Tokens** (dark, from the stock look): base `#0b0b0b`, bar `#121212`, panel
  `#1a1a1a`, rows `#141414`, overlay `#242424`, border `#303030`, muted `#4d4d4d`,
  subtext `#7a7a7a`, text `#d0e2fa`, bright `#ebebeb`, accent `#5555c8`, mark
  `#7777dd`. Font: UbuntuMono Nerd Font, bold, via `local()` with a mono fallback.
- **The channel:** a 1px `border` outline with `inset 0 0 0 2px <ground>, inset 0 0 0 3px
  var(--muted)`: a double line. Bar chips, flyout panels and the rows frame all use it.
- **Headings:** `//` in the mark colour, the title, then a 1px rule to the right.
- **Rows:** 30px, 8px gap, hover fill `overlay`; the current row has a 2px accent tick
  on its left edge and the overlay fill. Readout rows put the value in subtext.
- **Real sizes, zoomed:** build at 1x pixel sizes and zoom the stage (`zoom: 2.6` for a
  bar module, `1.35` for a flyout, width 316 like `menuWidth`). Never scale individual
  numbers.
- **Components mirror the shared QML ones:** `FlyoutRow`, `FlyoutHeading`,
  `FlyoutSegmented` (segmented), tabs as an underline strip, `FlyoutTile` grid,
  `HeadCard` (hero), `Meter`, `Switch`, `FlyoutChip`. If the mock needs a part the
  shell has no component for, say so: it means a new component.
- **Icons:** inline SVG strokes, so the file renders anywhere. The shell uses Nerd Font
  glyphs; don't claim the mock icons are the final ones.
- **Not too heavy:** one JS engine, small HTML builders (`R`, `S`, `H`, `G`, `HERO`, …),
  each module a few lines of options plus a `bar(state)` and `fly(state)` function.
  Mock only the element, not the whole screen.
- **Surrounding context for bar chips:** a faint ghost chip either side, and the
  "module padding" Settings control applied to all of them.

## From picks to code

- Read each flyout's QML first; match picks against what exists. Note what is already
  done and what can't be done (no data source, a risky action) and say so plainly
  instead of faking it.
- Reuse the shared components; no hand-picked colours or sizes (`Theme` only).
- To look at a flyout, add a temporary `IpcHandler` inside `screenScope` in
  `shell.qml` that calls `screenScope.toggleFlyout(name, barWindow.widgetItem(widget))`,
  then `grim -g "x,y WxH"` over the flyout (each call toggles it; the monitors have
  different origins). Remove it before committing; commit with explicit paths.
- One commit per module: `Area: what changed, in plain words`. Run
  `python3 tools/check-unused.py` (removed code leaves unused ids and tokens).
- Hardware the machine lacks (battery, VPN, failed units) can't be screenshotted: say
  which pieces went unseen.
- Record the picks in `qs/DESIGN.md` with the date, what changed, what already existed
  and what was left out.

## Lessons

- Offer a visible look first; reviews are cheap, rework is not.
- A change the user reverts (the small media thumbnail) is a signal to ask for the
  layout in a sentence before building a new one.
- Greyed-out controls the player can't use look broken; hide what's unavailable.
- Comments the user writes to explain a pick matter more than the toggle itself.
