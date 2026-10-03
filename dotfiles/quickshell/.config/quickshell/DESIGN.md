# Singularity design reference

The design decisions for the shell's UI, element by element. Read this before
changing or adding UI, so new pieces match what is already there. Values come
from `services/Theme.qml`; the look that sets them is `singularity` in
`services/Looks.js`.

The current design is **Channel** (settled 2026-10-01): grayscale, rounded,
double-lined, with one indigo accent (`#5555c8`) for marks.

## Styles

How the chrome is drawn is one setting, `style` (`services/Styles.js`):
Channel, Lined, Flat, Retro, Minimal, Basic, Capsule, Glass, Tabbed and
Terminal. A style sets the frame, bar modules, hover, level chips, focused
window mark, flyout titles, heading prefix and where flyouts sit, all at
once. Beside it are only dials that move everything together (Roundness, Bar
shape, Density, See-through) and Finish switches that are safe with any style
(separators, shadows, shaded grounds, heavy lines, heading caps and rule).

Across every style, a chosen segment, tab or chip fills with the accent
(text in `Theme.textOnAccent`); only Channel adds its groove round it. Tabbed
draws the open module as a real tab: its sides and top are stroked down
into the flyout, whose edge is left open under it (`FlyoutPanel`'s tab).
Terminal keeps every corner square whatever Roundness says (the style's
`square`), and its brackets hug their content with the gap between chips, and its
level chips show five blocks beside the icon. The shell's layers blur what's
behind them (a Hyprland layer rule), so Glass and see-through grounds stay
readable.

Don't add a setting that changes one piece's frame on its own: that's what
made combinations clash. A new look of a piece belongs in a style. Theme reads
the derived values through `Styles.resolve()`; the sections below describe
Channel.

## The channel

The signature shape. Every frame is three bands, outside in, then the ground:

| Band       | Colour            | Width            | Theme token          |
|------------|-------------------|------------------|----------------------|
| Outer line | muted `#4d4d4d`   | 1px              | `channelOuter`       |
| Groove     | base `#0b0b0b`    | 2px              | `channelGroove`      |
| Inner line | border `#303030`  | 1px              | `channelInner`       |
| Ground     | depends on element | —               | —                    |

- `channelWidth` (4px) is the first clear pixel inside the bands.
- A **lit** channel (open, on, focused, selected) turns the groove accent.
- Corners are rounded and concentric: each band's radius is the outer radius
  minus its inset.
- Draw it with `flyouts/Channel.qml`. A frame joined across shapes (a flyout
  grown from its bar group) uses `flyouts/GrownFrame.qml`, which builds the
  path with `services/ChannelPath.js`. Where widths change, inside corners get
  a fillet of `channelFillet` (7px). A flyout keeps its own width unless it's
  within a fillet and corner of its group's; that close it takes the
  group's width, so both sides run straight instead of making a jog too
  short to read as a step. Flyouts from the centre group stay
  centred on their module (the calendar on the clock) and never snap.

Style: `channel` (frame `channel` in `Styles.js`).

## Bar

- **Groups:** left, centre and right are each one channel around their visible
  modules (the style's `modules: "grouped"`). The channel is `groupHeight`
  (bar height − 4) tall with radius `groupRadius` (radius + 4) and a surface
  ground. Drawn in `shell.qml` (`groupRect()`).
- **Modules** sit flush inside the inner line, with no frame of their own:
  - at rest: nothing
  - hover: overlay fill
  - open (its flyout is showing): overlay fill and a 2px accent ring
- **Level chips** (volume, brightness, battery) fill the **whole chip** from the
  left, in the level colour (accent2, green for battery). The icon is centred
  on top. Never show a level as an underline or thin rule.
- **Show desktop** ends the right group: a slim slot past a hairline, whose
  rounded end is the group's own corner. Hover is the overlay fill; while
  the desktop shows it fills with the accent.
- Icon-only, by design; no text readouts beside icons.

## Flyouts

- **Grown from the group** (the style's `attach: "grown"`): the flyout hangs straight
  off the bottom of the whole group its module sits in, with one channel
  outline around both. Rounded inside corners join them where the widths
  differ, and the sides are straight where they line up (at the screen edge,
  for instance). It only fades in, since its frame is joined to the bar.
- **Frame:** a channel with a surface ground and radius `channelPanelRadius`
  (13px).
- **Sectioned:** each run of rows between headings and dividers sits in its
  own frame (panel ground, radius + 3), in place of divider lines. The frame
  is the style's: a channel, a double or single stroke, a sunken bevel, or
  the ground alone (`SectionRuns`). Settings pages and the System window
  are sectioned the same way under every style.
  `FlyoutPanel` works out the runs from the column's children. To start a new
  section, put a `FlyoutDivider` (or an item with `isSectionBreak: true`)
  **directly** in the flyout's column; a divider nested inside a sub-Column
  won't split the section.
- Content clears both frames: `padX` and `padY` in `FlyoutPanel`.

### Clock flyout

- **Tabs**, one shown at a time, picked from a segmented strip in its own
  section at the top: **Month**, **Today** (it reads **Day** once another day
  is picked) and **Timer** (it reads **Timer ●** while one runs).
- It opens on Today, or on Month when no calendar feeds are set up (then
  there's no Today tab).
- Picking a day in the month switches to that day's events.
- The Refresh row sits under the events, in its own section.
- Timer tab: the time large (`fontHero`) with what it is underneath, then the
  minute stepper and the chips.

## Settings pages

Every page sets `sectioned: true` on its `SettingsPage`. The System
window's pages (`SystemPage`) and the Keybinds window (the same page as
Settings') are laid out the same way.

- **Header (untabbed pages):** the page's heading and a one-line
  description, eliding if needed.
- **Notes and empty states:** a note under a heading is one line of
  `SettingsNote` (`alert` for a problem); an empty list is a disabled
  `FlyoutRow`, as in the flyouts. No paragraphs.
- **Sidebar:** the page on show has the accent tick, not a fill; the row
  the arrow keys are on (while searching) has the hover fill.
- A Repeater's Column that holds its own heading and rows sets
  `isSectionGroup: true` and `sectioned`, so its rows get sections as if
  they sat in the page.
- A heading sharing its line with a control (Copy specs, the CPU / MEM
  sort) sits in an item marked `isSectionBreak` and `sectioned`; the
  control takes the heading's `lift` so the two stay level.

- **Tabs:** one segmented strip at the top, an icon and a name per tab
  (names elide when tight), replacing the page heading and description.
- **Sections:** each group of rows between headings sits in its own channel
  (`SectionRuns`, as in the flyouts). Rows are inset to clear it.
- **Hints:** one line, eliding if needed. Write them short, at most about 42
  characters ("Frames, chips and dividers"), with no lists of every choice.
  The label column is wider (`fit(320)`).
- **Live preview (Appearance):** pinned above the rows on the Colours, Style,
  Text, Bar and Panels tabs. It shows a scaled-down bar and flyout built
  from the real components (`ModuleFrame`, `PanelFrame`, `FlyoutHeading`,
  `Slider`, …) over the wallpaper, so it follows every setting and can't
  drift from the shell. It's only built while one of those tabs shows.
- **Lock Screen:** a live preview of the lock screen is pinned over the
  rows (`pinned`), with a Lock now chip on its corner, so Background and
  Clock place are plain segments. Under the clock's hint is the line as it
  will read. The lid is one row: [Suspend | Screen off] after [N min].
- **Visual pickers:** a choice judged by eye (Style, Density) is a grid of tiles
  (`SettingsTiles`), four across, or three when each tile is a small
  screen. Each tile draws what its value does; the current one has the lit
  groove. Numbers stay steppers, and on/off stays a switch.
- **Spot pickers:** a place on the screen (where notification popups
  appear) is one small screen beside the label with a spot per choice,
  drawing the thing where it is (`PopupSpot`).
- **Which pages are tabbed:** only Appearance. Every other page is one
  page with sections; prefer that over tabs.
- **Window Rules:** rules are one-line rows (drag handle, name, a pattern
  mark, how it opens) that open in place: Matches, Name with the pencil,
  one Opens as choice (Tiled · Float · Fullscreen · On top), Size from a
  dropdown of presets, shares of the screen and Custom…, Workspace, and
  Remove. Rows reorder by dragging the handle. Add a rule… is the last row,
  as Other network… is. Workspace layouts are segments per workspace.
  The tab showing has white text on its accent fill, never dark. Two tabs at least, each with more than one row; a page
  whose sections are short stays one page. Tab content is `SettingsTab`.
- **Rows that open in place:** a row whose action needs more input (a
  network's passphrase, a hidden network, a saved network's settings)
  opens a block under itself, set in by a rule down its left side, and
  takes the accent tick while open. Not a prompt elsewhere on the page.
- **Marks that line up:** icons at a row's end that repeat down a list (a
  network's lock and strength) go in `FlyoutRow.trailingIcons`, one fixed
  cell each, so every row's marks sit in the same columns.
- **Copyable values:** an address worth pasting elsewhere is a
  `SettingsValue` with `copyable`: hover fills it, a click copies it, and it
  reads Copied in the good colour for a moment.
- **Long lists:** the ten most useful rows, then a "Show all N" row. Network
  puts the joined network in a card at the top (name large, strength icon,
  security, band, the radio switch) and leaves it out of the lists below.
- **Bluetooth:** the adapter is a card the same way (its name, hci id, how
  many paired and connected, the power switch). Device rows carry the type
  icon on the left, and on the right the battery and Connected / Not
  connected (nearby ones say what they are). A paired device opens in place
  (`SettingsIndent`): Connect, battery as level chips (one per bud and the
  case), Reconnect by itself, rename, type, address, Remove. Scan sits on
  the IN RANGE heading, its icon turning while it runs (`FlyoutChip.icon`
  and `spinning`), and the unnamed devices are a last "Show N unnamed" row.
  Discoverable's hint counts down to BlueZ's timeout.
- **Display:** the arrangement picture is always there: every connected
  display to scale, one that's off drawn dashed to the left (Off · lid
  shut). Dragging arranges, a click opens that display, and the open one
  has the lit groove. Extend / Duplicate, Primary (segments by display
  name) and Reset workspaces only show with two displays on; while the
  saved primary is off, a note says which one stands in. Each display is
  a row (type icon, name, the connector as its `note`, a Primary `badge`,
  what it's running) that opens in place: Resolution (a dropdown, native
  marked), Refresh rate (segments, or a readout when there's one), Scale
  (100–200% segments, the hint saying what it looks like) and Rotation.
  An off display opens to one Status line. Every change writes a rule for
  that display alone, so nothing on the page names hl.monitor() rules.
- **Notifications:** a status card (the bell large, Notifications on or
  Do Not Disturb, why and until when, the history's count, the switch),
  with a History row under it (Open, and Clear all in two clicks). Then
  Popups (the spot picker, Group by app, and Send a test on the heading),
  How long popups stay as segments (4 s · 8 s · 16 s · 30 s · Never),
  Quiet hours (the switch; on, a midnight-to-midnight strip with the
  window filled and a marker at now, then Starts and Ends), and Apps:
  each app in the history is a row that opens a Popups switch, and a
  silent app's notifications go straight to the history (critical ones
  still pop up).
- **Audio:** each device is a row (type icon, a plain name such as
  Speaker or Dell S2417DG, where it is as the `note`, its level or Muted);
  the default has the Default badge and the tick, and a click on another
  makes it the default. Outputs with nothing plugged in (pactl's port
  availability) fold into a Show N row. Under the rows sit the default's
  Volume (grey and reading Muted while muted) and a Mute switch. Each app
  playing or recording is a row (its icon, name, what it's playing, its
  level, and "on <output>" when that isn't the default) that opens to
  Volume, Mute and Plays on, which moves it with pactl.
- **Startup:** your entries are fields with the app's icon
  (`SettingsField.image`), the command or comment as the hint, the switch
  and Remove (asking Remove Spotify?). Add an app… is the list's last row
  and opens a search with the matching apps under it, with their icons; a
  click adds one. From packages lists only the entries that can run here,
  saying when a user service already does the job; ones for other
  desktops aren't shown at all.
- **File Types:** each common kind is a field whose hint says what it
  covers (Links and web pages), or which of its types have no default,
  with a dropdown of apps and their icons (`SettingsDropdown.iconFor`).
  The dropdown offers the apps that declare the kind's main type; the
  others that could open it sit behind its last entry, Other apps that
  can open it (N)…. Office documents, spreadsheets, presentations and
  calendar invites are common kinds too. Every type is a search with a
  Show all N types row; each type is a row named in words (Markdown
  document, its type small) with its app, opening to the apps that can
  take it, the current one ticked.
- **Terminal:** a preview of Alacritty heads the page: the wallpaper
  through the background at the opacity, the prompt (the path pill, then
  ❯) in the look's colours at the font size, and the cursor's shape and
  blink. Opacity is a level from 30% to solid, written when the drag ends.
  The cursor's shape is three tiles, each drawing it between two letters,
  with Blinking a switch. Each alias is a row (name, its command as the
  note) that opens to the name and command with Save, and Remove alias in
  two clicks; Add an alias… is the last row.
- **Date & Time:** a clock card heads the page (the time large and
  ticking, then the date, the place with its abbreviation and offset, and
  whether it's synchronised). Time zone is a row (the city and offset as
  its note) that opens to a search by city, country or abbreviation; each
  place shows its time now and offset, and a click sets it. A zone set by
  an old alias (US/Eastern) offers its current name. Hour format's hint
  reads the time as it will look, and a strip of weekday letters shows
  where the calendar's week starts.
- **Software Update:** a status card heads the page (the update icon,
  accent while there are some and a green tick when up to date, the count
  large, when it last checked, the last upgrade and how many packages it
  changed, then Check now and Update now). Check for updates' hint says
  when the next check runs, and Include the AUR how many AUR packages there
  are. Each pending package is one row (package icon, name, the version
  change as its note with the moving part brighter, repo or AUR at the
  end); Ignore takes the end on hover (`FlyoutRow.actionText`, a chip that
  acts on one click, for what's easily undone). Ten, then Show all N.
  Ignored packages are rows saying what each holds back, with Stop
  ignoring on hover; Ignore a package… is the last row and opens a search
  of installed packages. Upkeep holds Orphaned packages and Reclaimable
  space, whose Clean up asks with the size first.
- **Input:** each keyboard layout is a row (its name in words, the
  variant or code as the note, Main on the first of two or more) that
  opens to its Variant as a dropdown in words, Make it the main one and
  Remove; Add a layout… searches evdev.lst by name or code. kb_layout and
  kb_variant are always written together. The common XKB options are
  named: Caps Lock key and Compose key dropdowns, and Switch layouts with
  (segments) once there are two layouts; the rest of kb_options is Other
  XKB options, whose hint shows the whole string. Repeat delay and rate,
  Pointer speed (a tick at the device's own speed) and Scroll speed are
  levels written when the drag ends, with a Try it field for the repeat.
  Focus follows mouse is four tiles drawing two windows, the keyboard's in
  accent and the wheel's dashed: Click, Always, Hover scrolls, Apart. The
  touchpad's rows are grouped by `SettingsSubhead` (Clicking, Scrolling
  and typing) inside the one section, and every hint says what the
  current setting does.
- **Keybinds:** one page, no tabs: your binds, then SUGGESTED (the
  presets you don't have yet, by pack; Show added brings the rest). Each
  bind is one line (keycaps, the description, the command quieter in the
  rest of the line, a lock on the few that can't be edited) and opens in
  place: the editor (Keys with Record, Does as Command or Lua, Description,
  Options, Section, Delete asking first), or for a locked one what it runs,
  why, and Open at line N. Lua actions are editable; one over several
  lines is kept as written. Each group ends with Add a bind…, its section
  chosen. Press keys beside the search looks a combo up by pressing it,
  showing the bind on it or offering Add a bind on it. The search and the
  lookup filter both lists; the ticked-presets bar sits under the list.
- **Power & Idle:** the profile segments carry their icons and the hint
  says what the chosen one does. The battery is a card (charge large, then
  state, time left, the Custom band and health) over a full-fill level chip
  of the charge; in Custom the resume-to-stop band sits on the chip and its
  ends are dragged, in steps of 5, in place of steppers. The idle steps
  have a timeline above them (each step's icon at its time, muted when
  off), and each step a switch: off comments its block out of
  hypridle.conf with `#~ `. Steps that differ only by power source carry a
  battery or plug mark (`SettingsField.mark`).
- **No look summary card:** the Look tab's Changes list alone shows
  what's changed.
- **Changes are counted from the saved default** when one was saved with
  the look in use (`Settings.lookBaseline`), so Set as default empties the
  list. Otherwise they're counted from the look as designed. Undo, Undo
  all and the fields' ● marks go back to the same baseline.

## System window

Laid out like the sectioned Settings pages (`SystemPage`).

- **Overview:** four cards (CPU, Memory, Temp, Battery), each with its
  last minute as a line over its level (`StatCard.history`; temperature
  drawn from 30 °C), then the network's minute as one slim strip with its
  live rates. SystemStats samples its cheap per-second files from shell
  start, so every graph opens full. Health is a card (the count or All
  clear, when the checks ran, Run checks and Open Health) with rows only
  for what needs a look, each opening where it's fixed, and one quiet line
  for what's fine. Process CPU is a share of the whole machine with a
  small level (`ProcessTable.machineShare`); ending one asks End <name>?
  in the row. At a glance is two columns. Quick actions are rows with an
  icon and a note saying what each does; Restart audio asks first.
- **Health:** the same status card heads it (Check again on it), then TO
  LOOK AT (problems, worst first, each with its fix) and PASSING, each
  heading carrying its count and left out when empty. A fix that deletes
  or switches something off (clean, disable) asks first.

## Headings

- Bold spaced caps, value in white (`VOLUME  45%`).
- An accent `//` before each one, drawn a little lighter than the accent. It
  comes from the look's `heading.prefix`.
- A line from the end of the heading to the right edge (`headingRule`).
- In sectioned flyouts they get room above and below so the section frames
  clear them.

## Rows and selection

- **Hover:** overlay fill, with the text going white.
- **Selected or current:** a short 2px accent tick on the left edge, with the
  text going white. No fill, so it isn't mistaken for hover.
- Readout rows (`trailingIsValue`, `enabled: false`): grey label and white
  value.

## Controls (level-chip style)

Controls are small channels: an outer line plus a groove. They light the
groove, or fill with the accent, when active.

- **Switch:** no knob. When off it is a dark well with the inner line; when on
  it fills with the accent inside a dark groove.
- **Slider:** a 16px level chip. A dark groove holds an accent fill up to the
  value, with a thin white marker at the level.
- **Segmented:** a channel strip, `rowHeight` tall (taller than chips). The chosen segment fills with the accent
  inside a 2px dark groove, with white text.
- **Chip/button:** surface ground with an outer line and groove. Hover
  brightens the outer line, and selected fills with the accent. Armed
  (confirm-twice) is the alert fill.
- **Input:** surface ground with an outer line and groove; when focused, the
  groove turns into a 2px accent band.
- Read-only meters (`Meter.qml`) stay thin bars.

## Type

- UbuntuMono Nerd Font for everything: text and icons.
- **All text is bold** (`textWeight: "bold"`): UbuntuMono has no medium
  weight. Every Text takes `Theme.weightBody`; emphasis and headings use
  `Theme.weightStrong`. A new Text sets `font.weight: Theme.weightBody`, and
  a conditional emphasis is `font.weight: cond ? Theme.weightStrong :
  Theme.weightBody`, never `font.bold: cond`, which would drop the off state
  to regular.
- Sizes: body 16, headings 14, captions 12, and the bar's own size
  (`barFontSize`).

## Colour

- Grayscale ramp: base `#0b0b0b`, bar `#121212`, panel `#141414`, surface
  `#1a1a1a`, overlay `#242424`, border `#303030`, muted `#4d4d4d`, subtext
  `#7a7a7a`, text `#d0e2fa`, bright `#ebebeb`.
- Accent `#5555c8`, for marks only: selection, open and lit states, `//`.
- Good `#7d9b7d` and alert `#a87676`, desaturated on purpose.

## Wording and behaviour

These are carried over from the 2026-09-27 consistency sweep:

- **Case:** feature and page names in Title Case; action labels in sentence
  case.
- **Punctuation:** use "…" and "—".
- **Destructive actions** take two clicks (`confirm`, `confirmText`).
- **Booleans** are switches.
- Every flyout has an **empty state**.
- Device flyouts end with "More in Settings".

## Adding UI

- Reach for the shared components (`FlyoutRow`, `FlyoutHeading`,
  `FlyoutDivider`, `Switch`, `Slider`, `FlyoutSegmented`, `FlyoutChip`,
  `FlyoutInput`, `PanelFrame`, `Channel`) before drawing your own.
- **No hand-picked colours or sizes:** take every colour, size and duration from
  `Theme`. A control frames itself through `Theme.controlBorder()`,
  `Theme.controlStroke()` and `ControlEdge`, so it follows the frame style.
- **Mock first:** before building UI, make HTML mockups in the real look and let
  the user pick. When a choice is made, record it here.
