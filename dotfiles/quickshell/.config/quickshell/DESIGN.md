# Singularity design reference

The design decisions for the shell's UI, element by element. Read this before
changing or adding UI, so new pieces match what is already there. Values come
from `services/Theme.qml`; the colours are the `singularity` look in
`services/Looks.js`, the rest the style's stock in `services/Styles.js`.

The current design is **Channel** (settled 2026-10-01): grayscale, rounded,
double-lined, with one indigo accent (`#5555c8`) for marks.

## Styles

How the chrome is drawn is one setting, `style` (`services/Styles.js`):
Channel, Double, Solid, Glass (settled 2026-10-08 from two rounds of
mockups) and Flat (2026-10-16). A style sets the frame,
bar modules, hover, level chips, focused window mark and where flyouts sit,
all at once, and starts the Finish switches and the heading mark off its
own way. Beside it are dials that move everything together (Roundness, Bar
shape, Density's Spacing and Row height, See-through), Finish switches that
are safe with any style (separators, shadows, shaded grounds, heavy lines),
and sizes and colours that don't touch a frame: the palette's roles, the
status colours, the headings, the bar's height, icons and padding, and the
windows' borders, corners and shadow.

**Each style has options of its own** (`options` in Styles.js), shown
first under Advanced in Shape › Style. An option either stands for one of the
shared Finish settings (`key`), or is an id in `Settings.styleOptions`, read
with `Theme.opt(id)`. Picking a style sets them all (`Styles.finish`) as
part of its default (see Styles and settings).

**Each style draws its own controls**, keyed on `Theme.style`:

| Style | Switch | Slider | Segments | Chip/button | Current row |
|---|---|---|---|---|---|
| Channel | no knob; accent fill in the groove | level chip with a marker | channel strip | outer line + groove | tick |
| Double | stroked box, square knob turns accent | stroked well, fill inside | stroked strip, chosen ringed in accent | double-stroked chip | tick |
| Solid | fat pill, white knob | thick bar | sunken track, raised accent pill | filled block | accent-tinted ground |
| Glass | frosted track, knob glows | thin line, glowing round thumb | frosted strip | glass chip | tick |
| Flat | pill outlined in the text colour; on, accent with a white knob | thin line, upright rounded thumb | separate flat blocks, 2px apart | flat block, heavy outline on hover | tick |

- **Bar chips:** Double outlines every module with an inner stroke 2px in,
  faint at rest (lit with `lit`); Solid and Glass fill the open chip with
  the accent, and their open level chips keep the level and take an accent
  ring instead.
- **Flat** is the Windows 10 take, in the look's own colours: square, one
  hairline round panels, no frames round the runs of rows inside them
  (`Theme.sectionFramed`), sentence-case headings with no rule. Its bar
  modules are `taskbar` slots: bare, the bar's full height, packed with no
  gap, a fill on hover and while open, a 2px accent rule along the screen
  edge's side of the open one; level chips fill the whole slot at 70%. The
  open-windows strip gives each icon a wide slot, the focused one lit, its
  pip on the screen edge and the slot's full width.
- Flat's `taskbar` option rearranges the bar (`Settings.widgetLayout`):
  nothing in the centre, the clock at the right end before Show Desktop,
  the other centre modules ahead of the right's. Rearranging it in Bar
  Widgets writes `taskbarLayout`, kept apart from `barLayout`, so turning
  the option off (or leaving Flat) brings the usual arrangement back. Its
  `barPosition` option puts the bar at the bottom (an option's `off` is
  the value it takes when off).
- Glass's `blur` and `tint` change its frost.

Across every style, a chosen segment, tab or chip fills with the accent
(text in `Theme.textOnAccent`) unless its row in the table says otherwise.
Flat keeps every corner square whatever Roundness says (the style's
`square`). The shell's layers blur what's behind them (a Hyprland layer rule), so
Glass and see-through grounds stay readable. Level chips fill the whole chip
in every style.

Don't add a setting that changes one piece's frame on its own: that's what
made combinations clash. A new look of a piece belongs in a style. The
exceptions sit under Style in Shape and act across the shell: **Plain**
(`Settings.plain`, 2026-10-30) flattens any style (see the Plain bullet
under Bar), and **Bar chips** (`Settings.barChips`, picked 2026-10-20): Style's own, or the bar's chips Bare (nothing until hover or
open), Outlined, or one Strip per group, under any style. Whichever it is,
hover, open and level chips still draw the style's way, and a Strip's frame
is the style's (a channel, double or single strokes). Theme reads
the derived values through `Styles.resolve()`; the sections below describe
Channel.

## Styles and settings

Appearance is two halves (2026-10-30). **The look is the colours**:
`Looks.colourKeys` (the ten palette roles, Good and Alert, Text on the
accent, the accent, Overlay dimming, Level colour, the heading mark's
colour and the windows' border colours). **The style is everything else**:
`Settings.styleKeys`, every key `Styles.stockOf` returns (shape, space,
type, bar, panels, motion, window opacity and corners, the finish).
Colour mode, its scheme and variant, the system font, cursor and icon
theme belong to neither, so no look, style or Reset moves
them.

- **Picking a look** writes its colours only; the style and every setting
  it holds stay.
- **Picking a style** lands on its default: its stock (`Styles.stock`, then
  what `Styles.finish` and `Styles.windows` set, then the style's own
  `settings`), then this machine's own stock (`style-defaults.json` in the
  state folder: `all` for every style, or a style's name), with its saved
  default laid over. Unsaved changes to the old
  style's settings go.
- **Save as default** stores the current style's settings, not the colours,
  as that style's default (`userDefaults[style]`); it's on only while a
  style setting differs. Each style keeps its own.
- **Changes, ● marks, Undo, Reset** count from `Settings.defaults`: the
  style's default for its settings, the look as designed for colours.
  Reset puts both back; Factory reset forgets the style's saved default.
  See-through is left out in Wallpaper mode (wallpaper mode's own 85%).

What each style is (Styles.js) and its stock:

| | Channel | Double | Solid | Glass | Flat |
|---|---|---|---|---|---|
| Frame | channel (line, groove, line) | double stroke | none, grounds mark edges | one light hairline | single stroke |
| Bar chips | one strip per group | outlined | filled | filled, frosted | taskbar slots |
| Focused window | pill | pill | ground | ground | pill |
| Shadow | none | none | soft | soft | soft |
| Strokes (Heavy lines) | yes | yes | no | no | yes |
| Flyouts sit | grown from the group | flush on a full bar, else floating | floating | floating | as Double |
| Flyouts open | fade | drop | scale | fade | drop |
| Corners | Roundness (stock 6) | Roundness (6) | Roundness (10) | Roundness (10) | always square |
| Row frames in panels | yes | yes | yes | yes | no |
| Current row | tick | tick | tinted ground | tick | tick |
| Headings | UPPER, rule, `//` | UPPER, rule, `//` (option) | UPPER | UPPER | Sentence case |
| Clock island | on | on | on | on | off |
| Windows' opacity (focused / unfocused / terminal) | 100 / 100 / 90 | 100 / 100 / 90 | 100 / 100 / 100 | 95 / 85 / 75 | 100 / 100 / 90 |
| Own options (stock) | none | Inner stroke always lit (off), Heavy lines (off), `//` before headings (on) | Shadows (on), Accent-tinted chips (off), Shaded grounds (off) | Heavy blur (on), Accent-tinted glass (off), Glow on accents (on) | Taskbar layout (on), Bar at the bottom (on), Shadows (on) |

Each style also starts the Bar, Panels and Motion tabs its own way (its
`settings`; a blank is `Styles.stock`'s, Channel's column):

| | Channel | Double | Solid | Glass | Flat |
|---|---|---|---|---|---|
| Workspaces | Pills | Blocks | | Dots | Numbers |
| Open windows | Icons | Segmented | Lift | Spotlight | |
| Clock | Time + date | Day + time | Time | Time | |
| Visualizer | Mirrored | Rising | Rising | | One line |
| Launcher | List | | Grid | Grid | |
| Notification popups | Full | Compact | | Compact | |
| Window switcher | Icons | With titles | Previews | Previews | Previews |
| Workspace overview | Grid | | | Strip | |
| Backdrop (overview, ALT+Tab, full launcher, power menu) | Dimmed | | | Clear | |
| Power menu | Row | List | Full | Full | List |
| Level popup | Pill | Screen edge | | | Screen edge |
| Window animation | Pop | Fold | | Zoom | Rise |
| Shell and window speed | 100% | | | | 75% |

The rest of the stock is the same for all five: Ubuntu Mono at 16px,
Normal density (Spacing 100%, Row height 100%, bar 32px), icons 17px,
padding 6px, a full bar at the top with no edge gap, See-through 100%,
Shadows on, Heavy lines off, flyouts 100% wide.

How each setting meets the style:

- **Colour tab.** The look, accent and palette roles draw the same in every
  style; Glass alone swaps the Border role for its hairline, and Channel's
  bands are Muted, Base and Border. Level colour fills meters, sliders and
  level chips in every style. Border width "Style" is 1px, 2px with Heavy
  lines on a style with strokes.
- **Shape tab.** Roundness does nothing under Flat. Shadows does nothing
  under Channel and Double (they have none); under Solid and Flat it's one
  of the style's own options. Heavy lines does nothing under Solid and
  Glass; under Double it's an option. Shaded grounds works everywhere and is
  Solid's option. See-through works everywhere; Glass multiplies it by 0.7,
  0.6 with Heavy blur. Window shadow "Style" follows the style's shadow and
  Shadows. Density, Spacing and Row height work everywhere; Spacing is the
  gap between bar chips except in taskbar slots, which touch.
- **Type tab.** Font, size, heading size and mark colour are style-free.
  Case, rule and mark start at the style's (the Headings row above) and can
  be changed under any style.
- **Plain and Bar chips (Shape tab).** Bar chips other than Style's own
  replace the bar chips under any style; hover, open and level chips still
  draw the style's way, and a Strip's frame is the style's. Channel's
  flyouts only grow from the group while the chips are a Strip. Plain
  overrides the style's shadow, Heavy lines, Shaded grounds, glow, row
  frames, where flyouts sit and Bar shape (its rows grey out).
- **Bar tab.** Bar shape decides where Double's and Flat's flyouts sit, and
  is fixed at full width under Plain. Height
  sizes the chips (taskbar slots take the bar's full height and 4px more
  padding). Workspaces, Clock, Open windows and Visualizer start at the
  style's (table above) and any choice works under any style; the
  open-windows strip marks its focused window the style's way and widens
  its slots under taskbar chips.
  Flat's Taskbar layout rearranges the modules while it's on.
- **Panels tab.** Launcher, notification, switcher, overview, power and
  level popup styles start at the style's and any works under any style;
  their frames, controls and grounds are always the style's.
- **Motion tab.** Window animation and the speeds start at the style's.
  Flyouts open "Style" uses the style's (first table); any other choice
  holds under every style.

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
- **Show desktop** ends the right group under every Chips setting: a slim
  slot past a hairline (picked 2026-10-20), whose
  rounded end is the group's own corner. Hover is the overlay fill; while
  the desktop shows it fills with the accent. It hides every window on
  every workspace and screen, and it never animates, neither the windows
  nor its own fill, whatever the animation settings.
- Icon-only, by design; no text readouts beside icons, except under Plain.
- **Open windows** default to 18px app icons with 3px padding each side.
  Appearance > Bar > Open windows has Window icon size and Window icon
  padding controls; icons are capped to the bar's height. Lift and
  Spotlight keep their smaller inactive icons relative to that size.
- **Plain** (Shape, a switch over any style, from a classic text bar):
  the bar full width whatever Bar shape says, flat, no hairline, chips Bare
  unless Bar chips says otherwise; the levels (volume, brightness, battery)
  read as "icon 100%" text instead of a fill, a low battery's in the alert
  colour. Flyouts sit flush under the bar with their rows unframed; no
  shadows anywhere, windows' too; every stroke a hairline, windows'
  borders too; no shaded grounds or glow. The style still draws frames,
  controls and colours. Turning it on also sets separators to Lines and
  workspaces to Numbers, each changeable after.
- **Edit mode** (right-click the bar's empty space > Edit bar, Bar Widgets >
  Edit on the bar, `qs ipc call bar edit`): the edit shelf hangs under the
  bar's middle and the bar stops taking clicks. Every movable module gets a
  stroke outline (accent on hover); one that's on but has nothing to show
  stands in as its dimmed icon. A dragged module leaves an outlined gap
  filled `selectedFill` and follows the pointer as a live copy with an accent
  ring; off the bar it's a chip over the shelf, whose hidden zone lights up.
  The centre anchor wears an accent pin.

## Flyouts

- **Grown from the group** (the style's `attach: "grown"`): the flyout hangs straight
  off the bottom of the whole group its module sits in, with one channel
  outline around both. Rounded inside corners join them where the widths
  differ, and the sides are straight where they line up (at the screen edge,
  for instance). It only fades in, since its frame is joined to the bar.
- **Frame:** a channel with a surface ground and radius `panelFrameRadius`
  (15px at Roundness 6).
- **Sectioned:** each run of rows between headings and dividers sits in its
  own frame (panel ground, radius + 3, `sectionRadius`), in place of
  divider lines. The panel's corners are the sections' plus the inset
  to them (`panelFrameRadius`), so the two are concentric; a window's
  inner panels take the sections' radius, inside the window's corner. The frame
  is the style's: a channel, a double or single stroke, or the ground
  alone (`SectionRuns`). Settings pages and the System window
  are sectioned the same way under every style.
  `FlyoutPanel` works out the runs from the column's children. To start a new
  section, put a `FlyoutDivider` (or an item with `isSectionBreak: true`)
  **directly** in the flyout's column; a divider nested inside a sub-Column
  won't split the section.
- **Button regions:** a `FlyoutChipLine` alone in its section (a flyout's
  way out: Settings, System, Keys) isn't chips inside a frame. The frame
  hugs it and its buttons fill the frame in equal parts, split by the
  frame's own line, with the hover fill out to the frame's corners.
- Content clears both frames: `padX` and `padY` in `FlyoutPanel`.
- **Closing:** one flyout open across all screens. It closes on a press
  anywhere off it, with any button and on any monitor (`Backdrop`,
  `DismissGrab`), on Escape, and when its monitor's workspace changes. The
  dismissing press isn't passed through to what's under it, except on the
  bar: the bar stays live under a flyout, so another module opens its own in
  one click and its own module closes it. Overlays (launcher, power menu,
  workspace grid) close the same way. A panel's box takes every press its
  rows don't (`Absorber`).

### Flyout layouts (picked 2026-10-20)

From the redesign mockups, one pick a module; the picks are about content,
and every frame, control and chip still follows the style. Shared pieces:
`FlyoutTile` in a `TileGrid` (a glyph, a value, a caption, lit when on),
and `HeadCard`.

Every bar flyout keeps to these (settled 2026-10-20):

- **A heading first**, always; a count or reading can ride on it.
- **One width:** `Theme.flyoutMenuWidth` (Flyout width scales it).
- **One size for the leading figure:** a flyout that leads with a number
  (volume, temperature, the time, the battery) sets it at `fontHero`;
  cards' titles and tiles' values are `fontTitle`.
- **Where things stand is a `HeadCard`** (Updates, a connection, a
  connected device), its actions at its end.
- **On/off is a switch row** (`FlyoutAction`): mutes, Do Not Disturb,
  radios that aren't on the heading.
- **Scan and Rescan sit on their list's heading** as a turning
  `IconButton`.
- **Clear all takes two clicks** wherever it is.
- **Settings ends every flyout** that has a Settings page, as a chip
  (`FlyoutChipLine`) with any other way-out actions beside it.

- **Control Centre:** card + rows (picked 2026-10-21): see Control Centre
  below.
- **Workspaces** (picked 2026-10-21): the bar's pills (the current one
  long, ones with windows short, empty a stub; the terminal while the
  scratchpad has windows; the grid glyph opens the flyout), the wheel
  stepping through them. The flyout is one frame: a heading per workspace
  with its window count, each window its app's icon and name with the
  title quieter after, the focused one ticked, close on hover; the
  specials after; the empty numbers as chips. Drag a window onto another
  workspace (its heading, its windows, or an empty number) to move it.
  All workspaces and Settings as chips.
- **Windows** (picked 2026-10-21): the strip as icons (pips under an app
  with several windows; the other strip styles stay in Settings). A click
  on an app with several windows opens its flyout: a card for the app
  (its icon, the windows on how many workspaces, New window at its end),
  a row a window with its workspace (popouts indented under their owner),
  Bring all here and Close all (two clicks) as chips. A row's ⌄ opens the
  window's actions under it: Float or Tile, Full, Pin (floating only), a
  popout's Promote, MOVE to a workspace's number, Close and Kill (two
  clicks). There's no separate window menu: a right-click on any icon
  opens the same flyout with that window's actions open.
- **Music** (picked 2026-10-21; Media and the Visualizer as one module,
  under the visualizer's key): the player's icon, then the spectrum of
  the followed player's app only, a browser's by its tab (flat while
  it's silent, whatever else plays) and the track's title, each with its
  own switch (Music visualizer, Music title); with neither, a play/pause
  mark. Shown while a player is open, or only while it sounds with Hide
  when silent. Bar Widgets lists Music with its Visualizer switch
  indented under it. A click opens the flyout, a middle click plays or
  pauses (the player it shows; the media keys skip browsers, see Media's
  keyPlayer). The flyout (reworked 2026-10-23, one page): the art across
  the panel (square to 16:9, as given) with the spectrum in the bar's
  style rising from its foot over a fade while something sounds; the
  title, artist and player under it; the progress (click to seek) and
  the transport as three equal buttons; every player as a
  row when there are several (a click picks which the module follows);
  Options, folded each time it opens: Visualizer, with Style (segments)
  and Bars (a slider) under it while it's on, Title on the bar, Hide
  when silent; Settings.
- **Weather** (picked 2026-10-21): the bar as it was, the sky and the
  temperature. The flyout is three tabs under the heading (Updated on
  it): Now (the sky and the temperature large with the condition, feels
  like and the place beside; the next six 3-hour slots; humidity, wind
  and today's rain as tiles), Hours (the next 24 from Open-Meteo, a row
  each with its chance of rain as a figure and a level; wttr.in's slots
  when that fails) and Week (each day's low and high as a range on the
  week's one scale, rain shown from 20%). Refresh and the other unit as
  chips.
- **Clock** (picked 2026-10-21): the clock stays on the bar while a timer
  runs, a line along its foot running down with the time left (all of it
  for the stopwatch, quiet while paused); pointed at, the time left takes
  the date's place. The flyout as before: the time large with the
  seconds quieter and the whole date, over the Month / Today / Timer
  tabs, then Settings as a chip.
- **Updates** (picked 2026-10-21): always on the bar: the packages
  waiting as a count beside the icon, Singularity's commits as a badge, a
  quiet tick when there's nothing, the icon turning while an update runs.
  The flyout: where things stand as a card with ↻ and Update at its end;
  a row per kind with its count (Repositories, AUR, Singularity, Clean
  up), each opening a page of its own (breadcrumb back) with its list and
  its action (Update N packages, Pull now, Clean up, two clicks); then
  Settings.
- **Failed services** (picked 2026-10-21): the alert sign with the count
  as an alert-coloured badge, only while something has failed. The
  flyout: a row per unit (system or user); a click opens it in place with
  its last three log lines and Full log, Restart and Clear; Clear all
  (two clicks) after them.
- **Bongo Cat** (2026-10-24): a cat's head over a desk line, drawn in the
  icon colour at the icons' scale; its paws are raised and one comes down
  on the desk with each key press, left and right in turn, lifting once
  typing pauses. Key presses come from scripts/bongo.py (every keyboard's
  events, a tap per press, never the key), which needs the user in the
  input group; until then the module hides.
- **Drives** (2026-10-24): the USB glyph, only while a removable drive
  (lsblk's hotplug: USB sticks and disks, SD cards) is plugged in, with a
  count badge past one. The flyout: each drive a heading with its name and
  size, its filesystems as rows (label, used of size), Mount (which opens
  it once mounted) or Open at the right, then Eject (unmounts all, powers
  it off). udisksctl does the work.
- **Devices** (picked 2026-10-24, B "one list"): the phone and the
  peripherals with a battery (a wireless mouse or keyboard through UPower,
  a headset through headsetcontrol) in one module, under the old Phone
  module's key. On the bar a plain glyph: devices while the phone's
  connected, the mouse without it; Allow or Pair beside it while the phone
  waits; a red dot while one is at 15% or under and not charging, else a
  green one while the phone's on screen; a middle click mirrors. The
  flyout (2026-10-25): one DEVICES section, a row per device (glyph and
  name, a short level meter and the number, a bolt while charging, red
  when low; Off for a headset that's off). The phone's row comes first,
  with a Mirror (Stop) button at its end; a click on the phone's
  row opens its tray (Screenshot, Ring, Send file, then its
  notifications) as an opened sidebar notification does: the phone's row
  stays put and the tray sits under its label, an accent rail down from
  its icon; shut each time the flyout opens; collapsed, the row's
  note gives the notification count. A click on a notification opens it
  in place as the notification sidebar's do (2026-10-26): the icon stays
  put, an accent rail runs down from it, the title larger, then the app
  and age, the text, the reply field, and Open and its actions as links.
  A paired phone out of reach is a
  dimmed row reading away; a pair request a card. Settings as the other
  flyouts end. A notification at 15% and 5% for a peripheral.
- **Privacy** (bar picked 2026-10-21): only while something captures, a
  chip filled with the alert colour carrying a recording dot and a glyph
  per kind (mic, camera, screen) in the ground colour. The flyout: Mic,
  Camera and Screen as three tiles, lit while in use with the apps using
  them, then Mute microphone.
- **Recording**: only while recording or holding a replay. Recording: a
  red dot and the time, a click stops it. A replay held for a game: the
  replay glyph, a click saves it. No flyout; what each did shows as a toast
  (over a fullscreen game too, where the clock island can't be seen).
- **Tray menus** (picked 2026-10-21): the app's own entries as rows, its
  separators splitting them into sections; submenus drill down behind a
  breadcrumb heading. At the top level its Show/Open and Quit entries come
  out as Show window and Quit chips at the end (Show window raises its
  window, else the tray's showApp).
- **Cooling** (flyout picked 2026-10-21): the last three minutes of CPU
  and GPU as one graph on a °C scale (rules at 40, 60, 80), under a key
  with their readings and the drive's; the GPU's load and draw on the
  time axis; every fan as a row (its name, Auto when the board or card
  drives it rather than CoolerControl, its duty as a level, its speed; the
  card's own last); CoolerControl's modes as a segmented strip while it
  has any (its daemon's API, with the GUI's token); CoolerControl and
  System as chips.
- **Bluetooth** (picked again 2026-10-21): the radio's switch on the
  heading; each connected device under DEVICES (Scan on that heading) as
  a card (its kind, battery, Disconnect), an earbuds' left, right and
  case as tiles under it; the other paired ones as rows (Connect on
  hover); what a scan found; Settings as a chip. The bar icon turns to
  the connected glyph while a device is on.
- **Network** (picked again 2026-10-21): the connection as a card (the cable while it's up, else the
  joined network, with the address); Down and Up as tiles over the last
  minute's graph (SystemStats samples while it's open); the Wi-Fi switch;
  NEARBY with Rescan; Show all N; Settings as a chip.
- **VPN** (2026-10-24): on the bar once a server's imported, the shield
  while it's up, the VPN glyph dimmed while off (the alert colour when the
  server doesn't answer); a middle click turns it on or off. The flyout:
  the on/off switch on the heading; the tunnel as a card (the country and
  server, what goes through it, the forwarded port, Copy port at its end);
  Route everything and, while it's on, Kill switch as switch rows; SERVERS,
  a row each (the country, the server quieter after, ⇅ on those that
  forward a port), a click connecting; Settings as a chip.
- **Volume** (picked 2026-10-21): one panel: the level large with the output beside it (a
  click opens the outputs in place to switch), its slider and Mute, the
  microphone's level and Mute microphone, CHANNELS (Game, Chat and Media,
  each a level shaped like an app's, and while a headset reports one the
  ChatMix dial: a `BalanceMeter` filling from the middle toward Game or
  Chat), then APPS, each app a level of
  its own (a click on its name mutes it). Settings as a chip.
  On the bar the level fills the chip and the icon says where sound
  goes: headphones (Bluetooth or a headset) or speakers.
- **Brightness** (picked again 2026-10-21): a labelled slider per
  display, this screen's first, then Night Light, then Settings as a
  chip. The bar's sun turns to the moon while Night Light is on.
- **Battery** (picked again 2026-10-21): the level large with state, time left and draw beside it;
  the charge since the shell started (a sample every five minutes, a day
  kept) as a graph; the power profile as one strip; Health. Settings as
  a chip.
- **Notifications**: see the notification sidebar below.
- **Notification popups** (picked 2026-10-25): title first, the app's
  icon beside it and the age and close at the right; the text under the
  title. Buttons show while the pointer is on it: Copy for a one-time code
  (lit, else Open is), Open, the app's own, Open link for a link in the
  text, and ··· for Copy text, Silence the app and Notification settings.
  Grouped by app, the older ones are a line each under the newest (title,
  text, age), a click opening that one.

### Notification sidebar

Built 2026-10-25 (the bell, `sidebar/NotificationSidebar.qml`). The
notification history as a panel down the right edge like the Claude
sidebar (the two take turns): out until the bell, its ×, Escape, a click
off it (the bars excepted) or opening a notification from it. Clear all on
the heading. Newest first under a subhead per day (Today, Yesterday, the
date), each notification a few lines: the app's icon, the title and its
age (× on hover), two lines of
its text. A click opens it in place, the icon staying put: the title
larger, an accent rail down from the icon, and under the title the app and
age, the text, the picture and the buttons as links (Open · the app's own
· More). Do Not Disturb and Settings at the foot. While it's out nothing
pops up; it all arrives in the list.

### Claude sidebar

Built 2026-10-24 (SUPER+I, `sidebar/`, `services/Ai.qml`). Not a flyout: a
panel down the right edge of the focused screen, under the bar, in the
panel's frame with sections. It stays out until SUPER+I, its ×, Escape or
a click off it (the bars excepted). It slides in from the edge and fades.

- **Codex** (`services/CodexSession.qml`, `codex app-server`): Chat and
  Code can run on Codex instead, a Claude/Codex chip in the composer
  switching the tab (each engine keeps its own conversation, model and
  past sessions). The same transcript, attachments and prompt cards: its
  command and file-change approvals are Allow / Allow for this session /
  Deny. Code's mode picks its sandbox (Ask first and Plan read-only,
  Accept edits and Auto writing in the folder, Auto never asking); Chat's
  Codex only reads. The heading reads CODEX while it's on.
- **Heading** CLAUDE, with
  past sessions and × as icon buttons, and a New chat chip between them while there's a conversation; then Chat,
  Desktop and Code as a segmented strip, a ● on a tab with something
  unread.
- **Usage** under the heading, then a break: a meter each for Claude's
  five-hour and weekly windows and Codex's limit, used % and when it
  resets (the time today, the weekday this week, else the date); alert
  colour from 90%. Read by `ai.py usage` (Claude's usage endpoint with
  Claude Code's token; Codex's newest session log) every two minutes while
  the sidebar shows, and after each reply's rate-limit event.
- **The tab's line:** Code's folder as a row (a click lists the folders
  in its place, with a field for any other); Desktop's changes as a row
  (a click shows the diff in its place) with Apply and Discard (two
  clicks) as chips.
- **The conversation** takes the rest: what you sent in a field with its
  screenshots small under it; replies as markdown you can select
  (`services/Markdown.js`: inline code tinted, tables ruled), each fenced
  block in a darker box of its own with its language and Copy; each
  tool call a quiet line (spinner, tick, ✗) that opens in place to its
  diff or command and its output.
- **Files dropped** anywhere on the panel (from a file manager) attach to
  the next message: an image scaled like a screenshot, text as text,
  anything else as its path; the panel shows "Drop to attach" while one
  hovers.
- **While it's away**, a finished reply or a prompt waiting is a
  notification ("Claude · Code: done") with Open, which brings it out on
  that tab.
- **A prompt waiting** sits in its own section over the composer:
  what it wants, the command or plan in full, then Allow, the CLI's own
  "don't ask again" and Deny (Approve / Keep planning for a plan, a chip
  per option for a question).
- **Composer:** attachments as chips (hover reads Remove), the slash
  commands matching a / typed at the start (↑↓ pick, Tab or Enter take:
  /clear, /new, /model, /mode, /past and /compact, then the CLI's own),
  the box (Enter sends, Shift+Enter a new line, Ctrl+L, Ctrl+N or /clear
  start over), then 󰐕 (Area, Window, Screen, Paste, Selected), the model
  (the one running when left on Default) and Code's mode as chips a click
  steps through, what it's doing (pulsing) or the context used, Send or
  Stop.
- **Bar module** (key `claude`, the old module's, so a saved hide holds): the
  robot glyph, a spinner while it works, accent while a prompt waits or a
  reply is unread.

### Power menu and workspace grid

Picked 2026-10-11. The power menu's list style is large rows: the icon at
title size, the action over a line saying what it does, the key in a
keycap at the end. The workspace grid (SUPER+W, picked 2026-10-21) is a
miniature of every workspace: its monitor's shape over the wallpaper,
each window drawn where it sits with its app's icon, the current one
lit; specials with windows get one too, under them the name and the
window count. Click a miniature to jump, a window to focus it; drag a
window onto another miniature to move it (its icon follows the pointer).

### Brightness flyout

Each bar's brightness module is the monitor under it: over DDC/CI when the
monitor answers (`DdcBrightness`), else the backlight. The flyout's
heading is that monitor's level, then a labelled slider each (the model
name, this bar's monitor first and marked, the built-in panel last), then
Night Light.

### Cooling

Desktops only (`services/Cooling.qml`). The bar module is a plain fan icon,
as slim as Bluetooth's, with no level fill (settled 2026-10-09); it turns
the alert colour only when the CPU or GPU reaches 85 °C. The flyout is as
picked above. Fan names come from the machine's `fan-names.json` in the
state directory, never the repo.

### Clock flyout

- The time large (`fontHero`, the seconds quieter) and the whole date sit
  in their own section at the top.
- **Tabs**, one shown at a time, picked from a segmented strip in its own
  section under it: **Month**, **Today** (it reads **Day** once another day
  is picked) and **Timer** (it reads **Timer ●** while one runs).
- Picking a day in the month switches to that day's events.
- The Refresh row sits under the events, in its own section.
- Timer tab: the time large (`fontHero`) with what it is underneath, then the
  minute stepper and the chips.

### Control Centre

Picked 2026-10-21, page by page: a card saying where things stand, rows
for the rest, chips for the way out.

- **Root:** a `HeadCard` (the Arch glyph, user@host, how long it's been up
  and the look; the power button at its end opens Power), and in the same
  frame the five toggles as `FlyoutToggle`s (Quiet, Night, Awake, Game,
  Airplane), Warmth under them while Night Light is on, then the power
  profile as a segmented strip (gone while PPD isn't answering). Then Applications,
  Appearance and Bar Widgets as rows; the screen tools (Shot, Colour,
  Text, and Rec, Stop while recording) and the windows (Settings, System, Keys) as two `FlyoutChipLine`s.
- **Submenus** have no Back row: the heading reads
  `CONTROL CENTRE › APPEARANCE`, the first part smaller and quieter, and
  clicking it goes back (`FlyoutHeading.crumb`).
- **Power:** a card with how long it's been up, since when and the windows
  open; each action with what it does under it (Reboot's chevron opens
  the one-off targets); Restart shell and Settings as chips.
- **Applications:** the search, then every app as a row.
- **Appearance:** the look as a card (`LookStepper`: the name large between
  ‹ and ›, "N of M · K changed", the palette as a band; a click on the name
  opens the list); the wallpaper as a card (the picture with its name and
  transport, every wallpaper as a strip under it); then a setting a line:
  Style, Colours (Look · Wallpaper, Intensity once it's Wallpaper), Bar,
  See-through, Font size, Animations; Reset (two clicks) and Settings as
  chips.
- **Bar Widgets:** your bar in small as a card, a glyph per module in its
  group, dim while hidden, a click hides or shows it; the list by group to
  drag and switch; Edit, Reset (two clicks) and Settings as chips.

## Desktop widgets

Clock, weather, now playing and system stats on the desktop. They have a
look of their own, the same under every style and look (asked for
2026-10-24): a square card (no rounding, like conky) with a hard hairline
edge round an evenly see-through dark ground (35%), no gradient, no blur
(`desktop/WidgetCard.qml`); the content in white and bold with a tight
dark shadow round every mark, the system font (Appearance > Type, else
the shell's), nothing under 13px, dimmed and faint tiers kept strong, the
accent lifted. A feathered shade
with no edge and a top-to-bottom fade were tried and dropped. Each is its own
surface on the layer under the windows (`desktop/DesktopWidgets.qml`),
named outside the shell's blur rule. Off until turned on in Appearance >
Panels > Desktop Widgets.

- **Type** (`WidgetCard`): past each widget's one large figure (the time,
  the temperature, the uptime) three sizes, caption 13, body 14, title 16,
  and two weights: medium for anything read, the figures too, bold for
  what names or leads. A widget leads with a caption (`WidgetCaption`:
  spaced bold capitals in the accent: the day, the place, the player, the
  note, the host); the stats' labels and the groups' heads are captions
  too, dimmed where the accent would be noise.
- **Sizes sit on one grid** so they line up: small is one unit square
  (164px at the base text size), medium two units and the 16px gap wide,
  large two by two. Two smalls and a gap are a medium's width.
- **Where they start:** the clock in the bottom left corner with the
  weather a gap beside it, the stats top right, the music bottom right,
  flush with the screen's edges (no margin, like conky).
  A moved one is stored as fractions of the room the screen leaves it
  (`WidgetPlacement.js`), so one on an edge stays on it.
- **Edit mode** (right-click the desktop > Edit widgets, right-click a
  widget, Placement in Settings, `qs ipc call widgets edit`): the screen
  dims under the bar and the widgets come over everything, outlined. Drag
  one anywhere; it snaps to the other widgets (in line, or a gap beside),
  the middle, the thirds and the margin in from each edge, an accent line
  showing which. The picked one has an accent ring and a toolbar: size
  (S, M, L), Move to another screen, Hide. A sticky note has no S, M, L:
  an accent dot on its corner drags it to any size (at least a unit wide
  and 0.6 high, inside the margin), catching on the grid's widths and
  heights; the size is kept in card units with its place. The shelf under the bar adds
  back hidden ones, Resets places, and is Done (or Escape). The edit chrome
  is the style's, like the bar's edit mode.
- **The desktop's menu** (right-click bare desktop, at the pointer): Edit
  widgets, New sticky note, Next wallpaper, Desktop settings. A full-screen surface under
  the widgets takes the right-click.
- **Clock:** the day in the accent over the time, its seconds small beside it; medium adds the month,
  ISO week and this week as a strip with today lit, large the whole month.
- **Weather:** where, the temperature, the sky and today's high and low;
  medium adds five days as columns, large the next day's temperature as a
  curve (rain as faint bars, the sky every 3 hours) and five days as rows
  with their range against the week's.
- **Music:** the art (dimmed while paused), the player in the accent, the
  track, a thin progress line (click to seek) and bare transport glyphs;
  with no player it says Nothing playing and offers the last one.
- **Sidebar** (`desktop/DesktopSidebar.qml`, Appearance > Panels >
  Sidebar): a conky-style column flush with the primary display's right
  edge, from the bar to the foot, on a see-through dark ground (50%) with a
  hairline on its left; the same white ink and shadow, the shell's font,
  body 16. Laid out like a classic conky: sections under ruled headings
  with the heading mark (Info, CPU, GPU, RAM, Drives, Network, Fans,
  Battery), "Label: value" lines with the label dimmed, outlined meters
  beside their labels (each core gets one, two columns; the alert colour
  from 85%), "used / total [ n% ]" right-aligned under them, the busiest
  processes by CPU and by memory, and the last minute as sparklines. A
  section or line the machine can't fill is left out. It always fits the
  height: the sections spread out to fill it, or the whole column scales
  down when they'd run past. It takes no input, and the widgets' room on
  that screen stops short of it. While it's on, the System window's
  sampling runs.
- **Sticky notes:** any number, each a Notes tab (SUPER+N) pinned to the
  desktop; every note lives in the Notes window, where 󰐃 on a tab pins or
  unpins it. On the desktop: the title in the accent, + for a new note
  beside it (under, else over, else to the left), × to unpin it (it stays
  in the window), the text under it to type in (the surface takes the
  keyboard once clicked into and keeps it wherever the pointer goes, until
  a click lands off it or Escape; input.lua's click event lets it hand the
  keys back when Hyprland wouldn't; hovering never takes them, since it asks
  for the keyboard only from the press on). New ones also come from the
  desktop's menu (where the click was) and edit mode's shelf (the middle).
  Their places live in notes.json with the tabs. The first starts a gap
  under the stats.
- **System info:** a head of the distro's mark in the accent beside the
  host (bold) and a dimmed line, over a hairline rule. Medium: the system
  and kernel under the host, then uptime, packages and local IP as three
  captioned figures. Large: the user and uptime under the host, then a
  System group (OS, kernel, WM, packages, IP) and a Hardware one (CPU, GPU,
  memory), dimmed labels and their values lined up past the widest.
  Small: the mark, then the host over the uptime and when it booted. What
  doesn't change is read once; packages (pacman's database) and the IP
  once a minute. Starts top left.
- **Stats:** a bar each for CPU, GPU (Cooling, desktops with nvidia-smi),
  memory, temperature and the root disk, label left and value right (over
  the bar when small); large adds the last minute of CPU and the memory and
  disk in use. The bars step each second, unanimated, so the surface draws
  once a second; the disk is read every 30s. CPU and
  temperature are the mean of the last five seconds, GPU of the last two
  readings, like the System window's. A missing
  reading drops its bar.

## Settings pages

Every page sets `sectioned: true` on its `SettingsPage`. The System
window's pages (`SystemPage`) and the Keybinds window (the same page as
Settings') are laid out the same way.

- **Header (untabbed pages):** the page's heading and a one-line
  description, eliding if needed.
- **Notes and empty states:** a note under a heading is one line of
  `SettingsNote` (`alert` for a problem); an empty list is a disabled
  `FlyoutRow`, as in the flyouts. No paragraphs.
- **Window frame** (Settings, System, Keybinds; picked 2026-10-11): one
  title bar line (`WindowHeader`): the accent bar, the name with the
  hostname quieter after it, and Close. While a sub-page is open the name
  is a link back to its parent (`linked`).
- **Settings' structure** (picked 2026-10-30, round one A): no Home. One
  flat sidebar of short pages under headings (Connections, Device, Look,
  Apps, System), the search box at its top; it opens on the last page used
  (Network the first time). Appearance is one page with six tabs
  (2026-10-30, below); Window Rules is a sub-page of it (its row under
  Shape › WINDOWS; the sidebar keeps Appearance lit, the title reads
  "Appearance › Window Rules", the name or Escape goes back); the lid is
  on Battery & Idle. Old page names still open (`aliases`: theme, bar, …
  → appearance and the tab now holding them; `open("appearance/bar")`
  opens a tab).
- **System's Home** (picked 2026-10-18): System opens on Home, one pane
  with no sidebar: every page as a full-width tile (`WindowHome`,
  `HomeRow`) in a centred column (`fit(760)`), under group headings, each
  group one framed block with hairlines between tiles. A tile: the icon in
  the accent, the name over what's inside, what it's reading now on the
  right (CPU, Memory and Network add their minute as a small graph), a
  chevron, under its four headline cards.
- **A page** (Settings and System; picked 2026-10-18): one framed panel
  split by a hairline: the pages on the left (`WindowSidebar`, `fit(260)`),
  the open page on the right. The sidebar groups the pages under `//`
  headings; a row is the page's icon and name over what it's set to or
  reading now (in its colour), or what's inside where there's nothing
  (`SettingsSectionRow`). The page on show has the hover fill and the
  accent tick. The page opens under its icon (lightened accent) and name
  at `fontTitle` (`WindowPageTitle`), then its own one-line description.
- **Page layout** (2026-10-30: every page, after a per-page mix was
  tried and dropped): cards. A card on top says what the page is set to
  now where the page has one worth saying (`status`, `statusDetail`,
  `statusControl`: Lock Screen; a lone "Off" was tried and dropped, and
  Appearance's was dropped with its tabs), then framed sections
  showing their first three rows; the rest fold away behind More (n) at
  the heading's rule end (Less folds them again). A search hit in the
  folded rows brings them back.
- **Search** (Settings): the box at the top of the sidebar. Typed into,
  the sidebar lists the hits under a RESULTS count in place of the pages
  (the page beside it stays). With the box focused and nothing typed, the
  arrow keys walk the pages, opening each at once; with a query they walk
  the hits. The hit the arrow keys are on has the hover fill and tick.
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
- **Appearance's tabs** (picked 2026-10-30: tabs C, strip A, preview A,
  sections B): one page, the tabs grouped by what they change, in the
  segmented strip under the page's name. Colour (SCHEME: look, palette,
  shade; ACCENT; WINDOW BORDERS; WALLPAPER), Shape (STYLE with the finish;
  SPACE: density and the shell's and windows' gaps; GLASS: see-through,
  window opacity, dim, blur; WINDOWS: corners, shadow, the Window Rules
  row), Bar (BAR with the layout zones; MODULES with a subhead per
  module; MUSIC AND TRAY), Panels (POPUPS; LAUNCHER; OVERLAYS; DESKTOP
  WIDGETS), Motion (SPEED; ANIMATIONS: window animation, flyouts open) and
  Type last (SHELL FONT; HEADINGS; APPS: system font, icons, cursor). No status
  card. Every section shows all its rows (`essentialRows: 0`), its rarely
  changed ones folded behind an Advanced (n) row at its foot
  (`SettingsAdvanced`; a search for one opens it); a section of only
  those (Headings) is that one row. Cut in the same round: Text on the
  accent (Auto decides), Your mark (a mark set before stays on the Mark
  list), Colours from it (Palette does it). Neighbours still go two to a
  line. While anything differs from the baseline, the changes
  bar (`ChangesBar`, picked 2026-10-18) floats at the page's foot
  (`SettingsPage.footer`): "N changed from …", Review (the list opening
  above it, with Undo all and Factory reset), Save as default, Reset. A
  changed field's ● names the value it puts back when hovered.
- **Live preview (Appearance):** pinned above the rows on every tab, showing
  what that tab changes (`LivePreview.kind`): the bar and a flyout
  (Colour, Type), the whole bar a little larger (Bar), the launcher in its
  layout (Panels), two windows with their borders, corners, opacity and
  dimming (Shape, Motion). Built from the real components (`ModuleFrame`, `PanelFrame`,
  `FlyoutHeading`, `Slider`, …) over the wallpaper, so it follows every
  setting and can't drift from the shell.
- **Bar layout on the Bar tab** (`BarZones`): Left, Centre and Right as
  zones of module chips and a Hidden zone under them; a dragged chip is a
  ghost following the pointer, an accent marker shows where it lands, and
  the drop writes the layout and visibility like Bar Widgets.
- **Lock Screen:** four sections (picked 2026-10-18). BACKGROUND has a
  live preview of the lock screen, with a Lock now chip on its corner,
  beside Background, Blur and Dim, so Background and Clock place are plain
  segments. CLOCK puts Clock size beside Clock place; under the clock's
  hint is the line as it will read, its parts as chips. FINGERPRINT (picked
  2026-10-20) has the unlock switch, then two drawn hands (`FingerHands`)
  whose fingers are the buttons: lit when enrolled, a dark one enrolls and
  fills from the palm as the touches pass (the Fingers hint counts them,
  Cancel beside it), a lit one removes in two clicks. LOCKING holds the
  grace period, then the lid under a LID subhead: one row [Suspend |
  Screen off] after [N min], and Lock right away beside Hibernate.
- **Visual pickers:** a choice judged by eye (Style, Workspaces, Open
  windows, Clock, Control Centre icon, Visualizer, Launcher layout, Power
  menu, Window animation; `ModuleArt` draws the pictures) is a grid of tiles
  (`SettingsTiles`), four across, or three when each tile is a small
  screen. Each tile draws what its value does; the current one has the lit
  groove. Numbers stay steppers, and on/off stays a switch.
- **Spot pickers:** a place on the screen (where notification popups
  appear) is one small screen beside the label with a spot per choice,
  drawing the thing where it is (`PopupSpot`).
- **Which pages are tabbed:** only Appearance. Every other page is one
  page with sections; prefer that over tabs.
- **Window Rules** (picked 2026-10-18, 1B 2B 3B 4B 5A): the Apps list
  holds every app with a rule or a remembered size, under three subheads
  by how it opens: FILLS, FLOATS, OWN SIZE. Its rows carry the app's icon,
  a good-coloured dot while it has a window open, and how it opens in
  words (Filled, Fullscreen, 21% × 43%, Float 960×540). A row opens in
  place: Name (what it matches as the hint, the pencil, Remove rule),
  Opens (As left · Float · Full · On top) beside Workspace, for As left
  First time (Own size · Filled) beside Last left with Forget, a note on
  what the choice does, and Size for Float and On top. An app with only a
  remembered size gets its rule on its first change. Add a rule… is the
  last row, as Other network… is. Popups and dialogs is its own section:
  three switches on one line (Block their window, Open over it, Remember
  sizes), then the rules matched by title. Workspace layouts are segments
  per workspace.
  No reordering: new rules go on top of the file.
  The tab showing has white text on its accent fill, never dark. Two tabs at least, each with more than one row; a page
  whose sections are short stays one page. Tab content is `SettingsTab`.
- **Rows that open in place:** a row whose action needs more input (a
  network's passphrase, a hidden network)
  opens a block under itself, set in by a rule down its left side, and
  takes the accent tick while open. Not a prompt elsewhere on the page.
- **Marks that line up:** icons at a row's end that repeat down a list (a
  network's lock and strength) go in `FlyoutRow.trailingIcons`, one fixed
  cell each, so every row's marks sit in the same columns.
- **Copyable values:** an address worth pasting elsewhere is a
  `SettingsValue` with `copyable`: hover fills it, a click copies it, and it
  reads Copied in the good colour for a moment.
- **Long lists:** the ten most useful rows, then a "Show all N" row.
- **Network** (picked 2026-10-18, 1C 2A 3B 4B 5B 6A): the joined network
  in a card (name large, strength icon, security, band, the radio switch)
  with the link's details two to a line under it in the same block. Then
  one IN RANGE list with Rescan on its heading: saved networks first,
  tagged Saved, each row's strength as a word beside the bars, Other
  network… last. SAVED rows carry everything: where it is, security and
  when it last joined as the hint, the Auto-join switch, and Forget as a
  bin on hover (two clicks).
- **Devices:** a section per kind of thing: PHONE (a card with the
  phone's name, how it's joined and its battery, and Mirror, Screenshot,
  Ring and Send file as chips on it; pairing over Wi-Fi under it), PHONE
  LINK, HEADSET (a card, then only the settings headsetcontrol says it
  has; a level reads — until one is picked, as the headset can't say),
  WIRELESS (UPower's batteries), DRIVES (a row per drive with Eject, its
  filesystems set in under it with Open and Mount / Unmount) and USB (a
  row per device, its kind and speed as the hint, its vendor:product id
  copyable).
- **Bluetooth** (picked 2026-10-18, 1B 2B 3B 4B 5A): the adapter is a card
  the same way (its name, hci id, how many paired and connected, the power
  switch), with Discoverable and Pairable as toggle chips right after the
  name (`HeadCard.besideTitle`);
  Discoverable's chip counts down to BlueZ's timeout (Visible 2:59).
  Paired devices are two-line rows (`BtPairedRow`): type icon, the name
  over its type and state, the battery as level chips (`BatteryChips`: one,
  or L / R / Case for earbuds) on the right, Connect / Disconnect in their
  place on hover. Opened (`SettingsIndent`): Connect · Rename · Remove as
  one line of chips, Battery, Reconnect by itself, then a line of fine
  print (type, the address, which copies, and the advertised name). Scan
  sits on the IN RANGE heading, its icon turning while it runs
  (`FlyoutChip.icon` and `spinning`), and the unnamed devices are a last
  "Show N unnamed" row.
- **Display** (picked 2026-10-18, 1B 2B 3B 4B 5A): with one display, THIS
  DISPLAY is a card (type icon, name, connector, what it's running) with
  its settings straight under it, nothing to open: Resolution (a dropdown,
  native marked), Refresh rate (segments, or a readout when there's one),
  Scale (100–200% segments, the hint saying what it looks like) and
  Rotation; an off display shows one Status line. With several, the
  ARRANGEMENT picture comes first (every display to scale, one that's off
  dashed to the left; dragging arranges, a click picks whose settings
  show, the picked one has the lit groove), with Extend / Duplicate,
  Primary and Reset workspaces; the section under it is named after the
  picked display, a segmented strip of names over its settings. Then
  EVERY DISPLAY: Vibrance and Variable refresh. A mode, scale or rotation
  change waits in a bar floating at the page's foot (`SettingsPage.footer`):
  Keep this?, Revert / Keep, and an accent line draining as the 15 s run
  out. Every change writes a rule for that display alone, so nothing on
  the page names hl.monitor() rules.
- **Notifications** (three sections, picked 2026-10-18): STATUS is a
  status card (the bell large, Notifications on or Do Not Disturb, why and
  until when, the history's count, the switch), a History row (Open, and
  Clear all in two clicks), then Quiet hours (the switch; on, a
  midnight-to-midnight strip with the window filled and a marker at now,
  then Starts beside Ends). POPUPS has the spot picker on the left with
  Position (and Send a test) and Group by app beside it, then a HOW LONG
  THEY STAY subhead: Normal, Low and Critical as three dropdowns on one
  line. APPS: each app in the history is a row with its Popups switch; a
  silent app's notifications go straight to the history (critical ones
  still pop up).
- **Audio** (picked 2026-10-18, 1B 2B 3B 4A 5A): OUTPUT and INPUT each
  open on the default device as a card (its icon, plain name, where it is,
  Default) with its Volume under it; the other devices follow as rows
  (type icon, name, where it is as the `note`, its level or Muted), a
  click making one the default. Outputs with nothing plugged in aren't
  listed. Every level is a mute button (red while muted, `IconButton
  .warn`), the slider (grey while muted) and the percent. CHANNELS:
  Game, Chat and Media each a Volume field, then ChatMix (the dial's
  `BalanceMeter` between Game's and Chat's icons). PLAYING and
  RECORDING are a mixer, one row an app however many streams it plays
  (its level the loudest's, its moves all of them): each app's icon (`Audio.appIcon`), name over what it's playing,
  and on the right the channel or output it plays on (a dropdown, the
  channels first, moved with pactl)
  and its level; nothing opens.
- **Startup** (two sections, picked 2026-10-18): WHEN THE PC STARTS, then
  AT LOGIN. Your entries are fields with the app's icon
  (`SettingsField.image`), the command or comment as the hint, the switch
  and Remove (asking Remove Spotify?). Add an app… is the list's last row
  ("nothing of yours yet" after it while the list is empty) and opens a
  search with the matching apps under it, with their icons; a click adds
  one. A FROM PACKAGES subhead lists only the entries that can run here
  and that no user service already runs (unless one is on), its note
  counting the ones left out; ones for other desktops aren't shown at all.
- **File Types** (picked 2026-10-18): the common kinds sit under four
  subheads (WEB AND MAIL, FILES, MEDIA, DOCUMENTS); each is a field whose hint says what it
  covers (Links and web pages), or which of its types have no default,
  with a dropdown of apps and their icons (`SettingsDropdown.iconFor`).
  The dropdown offers the apps that declare the kind's main type; the
  others that could open it sit behind its last entry, Other apps that
  can open it (N)…. Office documents, spreadsheets, presentations and
  calendar invites are common kinds too. Every type is a search with a
  Show all N types row; each type is a row named in words (Markdown
  document, its type small) with its app, opening to the apps that can
  take it, the current one ticked.
- **Terminal** (two sections, picked 2026-10-18): TERMINAL has the app
  first, Alacritty or Ghostty as segments, then a preview of it on the
  left (the wallpaper through the background at the opacity, the prompt
  with the path pill then ❯ in the look's colours at the font size, the
  cursor's shape and blink) with Font size, Opacity and Cursor beside it.
  Opacity is a level from 30% to solid, written when the drag ends; Cursor
  is Block · Beam · Underline with the blink switch beside it. Font size
  and cursor are written to both terminals. BASH ALIASES: each alias is a
  row, its command lined up in a column after the name
  (`FlyoutRow.labelColumn`), that opens to the name and command with
  Save, and Remove alias in two clicks; Add an alias… is the last row.
- **Date & Time:** a clock card heads the page (the time large and
  ticking, then the date, the place with its abbreviation and offset, and
  whether it's synchronised, with the Network time switch; picked
  2026-10-18). Time zone is a row (the city and offset as
  its note) that opens to a search by city, country or abbreviation; each
  place shows its time now and offset, and a click sets it. A zone set by
  an old alias (US/Eastern) offers its current name. Hour format's hint
  reads the time as it will look, and a strip of weekday letters in First
  day of the week's hint line (`SettingsField.hintExtras`) shows where the
  calendar's week starts.
- **Software Update** (three sections, picked 2026-10-18: STATUS,
  PACKAGES, UPKEEP): a status card heads STATUS (the update icon,
  accent while there are some and a green tick when up to date, the count
  large, when it last checked, the last upgrade and how many packages it
  changed, then Check now and Update now). Singularity's Repository row follows in it
  says how far the clone is behind its upstream (and local commits, which
  disable Update since update.sh only fast-forwards), then a row naming
  packages the pull would install, then the incoming commits, newest first
  with their time, ten then Show all N. Check for updates' hint says
  when the next check runs, and Include the AUR how many AUR packages there
  are. PACKAGES has a PENDING subhead only while updates wait (the card
  says when there are none); each pending package is one row (package icon, name, the version
  change as its note with the moving part brighter, repo or AUR at the
  end); Ignore takes the end on hover (`FlyoutRow.actionText`, a chip that
  acts on one click, for what's easily undone). Ten, then Show all N.
  Under an IGNORED subhead, ignored packages are rows saying what each holds back, with Stop
  ignoring on hover; Ignore a package… is the last row and opens a search
  of installed packages. Upkeep holds Orphaned packages and Reclaimable
  space, whose Clean up asks with the size first.
- **Input** (picked 2026-10-18, 1A 2A 3A 4B 5B): each keyboard layout is a row (its name in words, the
  variant or code as the note, Main on the first of two or more) that
  opens to its Variant as a dropdown in words, Make it the main one and
  Remove; Add a layout… searches evdev.lst by name or code. kb_layout and
  kb_variant are always written together. The common XKB options are
  named: Caps Lock key and Compose key dropdowns, and Switch layouts with
  (segments) once there are two layouts; the rest of kb_options is Other
  XKB options, whose hint shows the whole string, folded behind an
  Advanced… row at the end of the keyboard section (a search for it opens
  the row). Repeat delay and rate,
  Pointer speed (a tick at the device's own speed) and Scroll speed are
  levels written when the drag ends, with a Try it field for the repeat.
  Focus follows mouse is four tiles drawing two windows, the keyboard's in
  accent and the wheel's dashed: Click, Always, Hover scrolls, Apart. The
  touchpad's rows are grouped by `SettingsSubhead` (Clicking, Scrolling
  and typing) inside the one section, the four clicking switches two to a
  line, and every hint says what the current setting does.
- **Keybinds:** one page, no tabs: your binds, then SUGGESTED (the
  presets you don't have yet; Show added brings the rest). Each
  bind is one line (keycaps, the description, a lock on the few that
  can't be edited; the command shows once it's opened) and opens in
  place: the editor (Keys with Record, Does as Command or Lua, Description,
  Options, Section, Delete asking first), or for a locked one what it runs,
  why, and Open at line N. Lua actions are editable; one over several
  lines is kept as written. Each group ends with Add a bind…, its section
  chosen. Press keys beside the search looks a combo up by pressing it,
  showing the bind on it or offering Add a bind on it. The search and the
  lookup filter both lists; the ticked-presets bar sits under the list.
  SUGGESTED is one row per pack (picked 2026-10-18: what it's for, how
  many of its binds are left to add) that opens to its tick boxes with
  Tick all; a search or lookup opens them all.
- **Power & Idle** (picked 2026-10-18, 1B 2A 3B 4B 5B): one POWER section:
  the battery card (charge large, then state, time left, the Custom band
  and health) over a full-fill level chip of the charge (in Custom the
  resume-to-stop band sits on it and its ends drag, in steps of 5), then
  Profile (segments with their icons, the hint saying what it does) and
  Charging. WHEN IDLE: a timeline of the steps (each step's icon at its
  time, muted when off) whose dots drag to set the time, snapping to the
  times on offer; then a row per step with its time as a dropdown (1 min
  to 1 h, then Never, which comments its block out of hypridle.conf with
  `#~ `). Suspend on battery and plugged in share one Suspend row, a
  battery and a plug mark before their two dropdowns.
- **Look tiles** open the Colour tab: each look drawn in its own colours
  (panel, bar, text, hint and accent pill), its description as the hint.
  The changes strip alone shows what's changed.
- **Each style keeps its own saved default** (`userDefaults`, by style),
  holding the style's settings and never the colours: Save as default and
  Reset act on the style in use only, and a style never saved resets to its
  stock (`Styles.stockOf`). Picking a style lands on its default.
- **Changes are counted from `Settings.defaults`**: the style's default for
  its settings, the look as designed for the colours. Undo, Undo all,
  Reset and the fields' ● marks go back to the same values.

## System window

Laid out like the sectioned Settings pages (`SystemPage`).

- **Home:** four cards (CPU, Memory, Temp, Battery; `HomeFigures`), each
  with its last minute as a line over its level (`StatCard.history`;
  temperature drawn from 30 °C), then the tiles in four groups: Status
  (Health), Running, Devices, This machine. SystemStats samples only while
  the window is open, so the graphs start empty and fill over the first
  minute. Only the Health tile says something needs a look (its count,
  red for a problem); there's no banner. No Overview page.
- **Processes in a page's summary:** process CPU is a share of the whole
  machine with a small level (`ProcessTable.machineShare`); ending one
  asks End <name>? in the row.
- **Health** (picked 2026-10-18): a status card heads it (the count or
  All clear, when the checks ran, Check again; no subtitle over it), then
  TO LOOK AT (problems, worst first, each with its fix) and PASSING (two to
  a line), each heading carrying its count and left out when empty. A fix that deletes
  or switches something off (clean, disable) asks first. A row can carry
  more than one fix: Shell log offers View, Dismiss (hides the lines there
  are now until new ones appear) and Fix with Claude (Claude Code in the
  repo, handed those lines).
- **Head cards:** a System page that has one answer opens on it in a
  `HeadCard` (glyph, the answer large, a line or two, the page's actions
  at its end), under a NOW or STATUS heading.
- **CPU** (picked 2026-10-18): the card (how busy, average and peak
  clock, temperature and profile) with the minute's graph at its right;
  threads as levels two across; DETAILS two to a line (load and its
  per-thread figure, the governor, Power profile a row into Settings, then
  the silicon facts); heaviest processes as a share of the machine
  with All processes under them.
- **Memory:** the card (in use, of what, available, swap) with the
  minute at its right; BREAKDOWN: the stacked strip with its parts two
  across under it, then swap and writeback two across under a subhead; the largest processes sorted by memory.
- **Processes:** a NOW card (threads, runnable, who it runs as, the
  machine's CPU, memory and load), then the full table with CPU as a share
  of the machine and its level, and the terminal tools two to a line,
  each saying what it shows.
- **Storage:** the card (free on /, how full, reading and writing) with
  the minute at its right; filesystems as levels with free and percent,
  the disks as rows under a subhead; Upkeep as on Software Update (Health's
  orphans and reclaimable space two to a line, Clean up asking with the
  size); tools two to a line.
- **Network:** the card (the network's name, rates, signal in words and
  dBm, traffic since the link came up, the minute and Settings at its
  right); the connection two across, then each interface a row under a
  subhead (In use badge, its address as the note) opening to its
  addresses; tools two to a line.
- **Power:** the card (charge and state, draw and time left, capacity
  against new, Settings on it) over the charge as a full-width level;
  BATTERY two across, then the pack under a subhead with its wear as its
  own level; the profile segments with their one-line point; SESSION with
  Idle and lid into Settings, Suspend asking first and the history, two
  to a line.
- **Hardware:** the card (the machine's name, CPU and RAM, GPU, Copy specs
  on it) over the identity two across; GRAPHICS AND AUDIO: the GPU, the
  displays and (under a subhead) the audio output as rows into their
  Settings pages; the ten hottest sensors as levels two across, then Show
  all N, fans as rows; input devices two to a line (named as Hyprland
  matches them); tools two to a line.
- **Config:** the repository as the card (its name and branch, what's
  uncommitted, the last commit; git status, Terminal and Editor on it);
  FILES: a search that matches name, purpose or path, then the files in
  one section, a subhead per group, the folders last; logs two to a line.

## Headings

- Bold spaced caps, value in white (`VOLUME  45%`).
- An accent `//` before each one, drawn a little lighter than the accent
  (`Settings.headingMark`). Appearance › Type › Mark offers `//`, `::`, `»`,
  `❯`, `>_`, `├─`, `▸`, `•`, none (or one set before), and four shapes in place of a
  mark (`shape-*`, `Theme.headingShape`): an accent bar, the label in
  brackets, the label in a notch of the rule, the label on an accent pill.
- A line from the end of the heading to the right edge (`headingRule`).
- A heading that folds its section shows its chevron only while the
  pointer is on it, or while the section is folded (picked 2026-10-11).
- In sectioned flyouts they get room above and below so the section frames
  clear them.

## Rows and selection

- **Hover:** overlay fill, with the text going white.
- **Selected or current:** a short 2px accent tick on the left edge, with the
  text going white. No fill, so it isn't mistaken for hover.
- Readout rows (`trailingIsValue`, `enabled: false`): grey label and white
  value.

## Chevrons

One meaning per glyph: right goes somewhere, down opens here, left goes
back. Always the Nerd glyphs (`Theme.fontIcon`), never a typed `>`.

| Meaning | Glyph | Where |
|---|---|---|
| A page from a window's Home | 󰅂, muted until hovered | `HomeRow` |
| Page on show in a window's sidebar | fill + tick + grey 󰅂 | `WindowSidebar` |
| Row the arrow keys are on | fill + tick + grey 󰅂 | Launcher, Settings search hits |
| Tab on show | accent fill, no chevron | Settings tabs, `FlyoutSegmented` |
| Goes deeper in the same flyout or window | 󰅂 | submenus, tray submenus, other System pages, Open Health |
| Leaves for another window | 󰁔 | More in Settings, System's "Settings" |
| Opens in place | 󰅂 → 󰅀 | expandable rows, "12 more" |
| Dropdown | 󰅀 → 󰅃 | `DropdownMenu`, `SettingsDropdown` |
| Back | breadcrumb heading (`crumb`), no Back row | Control Centre, tray menu |
| Breadcrumb separator | 󰅂 | `FlyoutHeading` |
| Stepper | 󰅁 󰅂 | `LookStepper`, `FlyoutStepper` (wrap), calendar months |

## Controls (level-chip style)

Controls are small channels: an outer line plus a groove. They light the
groove, or fill with the accent, when active.

- **Switch:** no knob. When off it is a dark well with the inner line; when on
  it fills with the accent inside a dark groove.
- **Slider:** a 16px level chip. A dark groove holds an accent fill up to the
  value, with a thin white marker at the level.
- **Segmented:** a channel strip, `rowHeight` tall (taller than chips). The chosen segment fills with the accent
  inside a 2px dark groove, with white text.
- **Stepper:** one control, not three: a field frame (outer line and
  groove) holding −, the value and +, the buttons bare inside it and
  filled on hover (`FlyoutStepper`, which every flyout and Settings
  stepper uses). A ring of names (a style) shows ‹ › and wraps.
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
- Device flyouts end with a Settings chip.

## Adding UI

- Reach for the shared components (`FlyoutRow`, `FlyoutHeading`,
  `FlyoutDivider`, `Switch`, `Slider`, `FlyoutSegmented`, `FlyoutChip`,
  `FlyoutInput`, `PanelFrame`, `Channel`) before drawing your own.
- **No hand-picked colours or sizes:** take every colour, size and duration from
  `Theme`. A control frames itself through `Theme.controlBorder()`,
  `Theme.controlStroke()` and `ControlEdge`, so it follows the frame style.
- **Mock first:** before building UI, make HTML mockups in the real look and let
  the user pick. When a choice is made, record it here.
