# Singularity design reference

The design decisions for the shell's UI, element by element. Read this before
changing or adding UI, so new pieces match what is already there. Values come
from `services/Theme.qml`; the look that sets them is `singularity` in
`services/Looks.js`.

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

**Each style has three options of its own** (`options` in Styles.js), shown
first under Finish on the Theme tab. An option either stands for one of the
shared Finish settings (`key`), or is an id in `Settings.styleOptions`, read
with `Theme.opt(id)`. Picking a style sets them all (`Styles.finish`); a look
can state its own `styleOptions`.

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
made combinations clash. A new look of a piece belongs in a style. The one
exception is **Chips** (Appearance > Bar, `Settings.barChips`, picked
2026-10-20): Style's own, or the bar's chips Bare (nothing until hover or
open), Outlined, or one Strip per group, under any style. Whichever it is,
hover, open and level chips still draw the style's way, and a Strip's frame
is the style's (a channel, double or single strokes). Theme reads
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
- **Show desktop** ends the right group under every Chips setting: a slim
  slot past a hairline (picked 2026-10-20), whose
  rounded end is the group's own corner. Hover is the overlay fill; while
  the desktop shows it fills with the accent. It hides every window on
  every workspace and screen, and it never animates, neither the windows
  nor its own fill, whatever the animation settings.
- Icon-only, by design; no text readouts beside icons.
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
- **Notifications** (picked again 2026-10-21): a line per notification (the app's icon, the
  summary, its age, close on hover); a click opens the whole card in
  place. Clear all on the heading, Do Not Disturb under the list; empty,
  All caught up with a green tick. Settings as a chip
  ends it.

### Claude sidebar

Built 2026-10-24 (SUPER+I, `sidebar/`, `services/Ai.qml`). Not a flyout: a
panel down the right edge of the focused screen, under the bar, in the
panel's frame with sections. It stays out until SUPER+I, its × or Escape;
a click elsewhere leaves it. It slides in from the edge and fades.

- **Heading** CLAUDE (the five-hour usage on it once past half), with
  past sessions and × as icon buttons, and a New chat chip between them while there's a conversation; then Chat,
  Desktop and Code as a segmented strip, a ● on a tab with something
  unread.
- **The tab's line:** Code's folder as a row (a click lists the folders
  in its place, with a field for any other); Desktop's changes as a row
  (a click shows the diff in its place) with Apply and Discard (two
  clicks) as chips.
- **The conversation** takes the rest: what you sent in a field with its
  screenshots small under it; replies as markdown you can select; each
  tool call a quiet line (spinner, tick, ✗) that opens in place to its
  diff or command and its output.
- **A prompt waiting** sits in its own section over the composer:
  what it wants, the command or plan in full, then Allow, the CLI's own
  "don't ask again" and Deny (Approve / Keep planning for a plan, a chip
  per option for a question).
- **Composer:** attachments as chips (hover reads Remove), the box
  (Enter sends, Shift+Enter a new line, Ctrl+L, Ctrl+N or /clear start over), then 󰐕 (Area, Window, Screen,
  Paste, Selected), the model and Code's mode as chips a click steps
  through, what it's doing (pulsing) or the context used, Send or Stop.
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

Clock, weather, now playing and system stats on the desktop (picked
2026-10-24): each a small panel drawn exactly as a flyout is (WidgetFrame:
the style's frame, ground, section runs and heading), so it follows the
style and look like everything else. Each is its own surface on the layer
under the windows (`desktop/DesktopWidgets.qml`). Off until turned on in
Appearance > Desktop > Widgets.

- **Where they start:** the clock in the bottom left corner with the
  weather beside it, the stats top right, the music bottom right, 40px in.
  A moved one is stored as fractions of the room the screen leaves it
  (`WidgetPlacement.js`), so one on an edge stays on it.
- **Edit mode** (right-click a widget, Placement in Settings, `qs ipc call
  widgets edit`): the screen dims under the bar and the widgets come over
  everything, outlined. Drag one anywhere; it snaps to the middle, the
  thirds and the margin in from each edge, an accent line showing which.
  The picked one has an accent ring and a toolbar: size (S, M, L scale the
  whole panel), Move to another screen, Hide. The shelf under the bar adds
  back hidden ones, Resets places, and is Done (or Escape).
- **Music** dims the art while paused; with no player it says Nothing
  playing and offers to open the last player of the session.
- **Stats** reads CPU, memory and temperature through SystemStats' light
  sampling, and GPU load from Cooling (desktops with nvidia-smi); a missing
  reading drops its row.

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
  hostname quieter after it, Settings' search in the rest of the line, and
  Close. No eyebrow, no separate search row. While a page is open the
  name is a link back to Home (`linked`).
- **Home** (Settings and System; picked 2026-10-18): both windows open on
  Home, one pane with no sidebar: every page as a full-width tile
  (`WindowHome`, `HomeRow`) in a centred column (`fit(760)`), under group
  headings, each group one framed block with hairlines between tiles. A
  tile: the icon in the accent, the name over what's inside, what it's set
  to or reading now on the right (System's CPU, Memory and Network add
  their minute as a small graph; only on Home), a chevron. System's Home
  has its four headline cards over the tiles. `open(page)` and More in
  Settings rows go straight to a page.
- **A page** (Settings and System; picked 2026-10-18): one framed panel
  split by a hairline: the pages on the left (`WindowSidebar`, `fit(260)`),
  the open page on the right. The sidebar groups the pages under `//`
  headings; a row is the page's icon and name over what it's set to or
  reading now (Home's status, in its colour), or what's inside where
  there's nothing (`SettingsSectionRow`). The page on show has the hover
  fill and the accent tick. The page opens under its icon (lightened
  accent) and name at `fontTitle` (`WindowPageTitle`), then its own
  one-line description. The window's name or Escape goes back to Home;
  Escape on Home closes.
- **Search** (Settings): in the title bar. Typed into on Home, Home's
  column lists the hits under a RESULTS count; on a page, the sidebar lists
  them in place of the pages (the page beside it stays). With the bar
  focused and nothing typed, the arrow keys walk Home's tiles (Enter opens
  one) or, on a page, the pages, opening each at once; with a query they
  walk the hits. The tile or hit the arrow keys are on has the hover fill
  and tick.
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
- **Appearance's tabs** (settled 2026-10-16, picks 1B…20A): Theme (four
  sections, picked 2026-10-18: Look with Style and Space under subheads,
  Space's two dials only on Custom; Shape with Finish, its switches two to
  a line; Colour with Accent and Status, Good and Alert as two swatches on
  one row, a click opening that one's hex; Text with Headings, the mark and
  its colour on one row, Case, rule and size two to a line), Bar
  (two sections, picked 2026-10-18: BAR with its position, shape and size,
  then the layout zones, Centre anchor and Reset layout under a LAYOUT
  subhead; MODULES with a subhead per module, its drawn tiles open),
  Panels (three sections, picked 2026-10-18: POPUPS with flyouts, then
  notifications and the level popup under subheads; LAUNCHER; OVERLAYS;
  neighbouring steppers and switches two to a line), Desktop (four
  sections, picked 2026-10-18: WALLPAPER with the current image's thumbnail
  beside its name, the six in one row, Folder and Colours from it two to a
  line; WINDOWS with gaps, borders, corners, shadow and tab bar; EFFECTS
  with opacity, dim and blur; MOTION with the three per-part speeds folded
  behind a "Per-part speeds…" row and the animation tiles four across;
  neighbours two to a line) and Apps (one section, picked 2026-10-18:
  System font; Icons with a few of the theme's icons on the label's line
  (`SettingsField.labelExtras`); Cursor with its size stepper beside the
  dropdown; terminal opacity lives on the Terminal page only). While anything differs from the baseline, the changes
  bar (`ChangesBar`, picked 2026-10-18) floats at the page's foot
  (`SettingsPage.footer`): "N changed from …", Review (the list opening
  above it, with Undo all and Factory reset), Save as default, Reset. A
  changed field's ● names the value it puts back when hovered.
- **Live preview (Appearance):** pinned above the rows on every tab, showing
  what that tab changes (`LivePreview.kind`): the bar and a flyout (Theme,
  Apps), the whole bar a little larger (Bar), the launcher in its layout
  (Panels), two windows with their borders, corners, opacity and dimming
  (Desktop). Built from the real components (`ModuleFrame`, `PanelFrame`,
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
- **Look tiles** open the Theme tab: each look drawn in its own colours
  (panel, bar, text, hint and accent pill), its description as the hint.
  The changes strip alone shows what's changed.
- **Each style keeps its own saved default** (`userDefaults`, by style):
  Save as default and Reset act on the style in use only, and a style
  never saved resets to its stock (the fallback look with the style's own
  Finish switches).
- **Changes are counted from the style's saved default** when one was
  saved with the look in use (`Settings.lookBaseline`), so Save as default
  empties the list. Otherwise they're counted from the look as designed. Undo, Undo
  all and the fields' ● marks go back to the same baseline.

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
  (`Settings.headingMark`). Appearance › Theme › Mark offers `//`, `::`, `»`,
  `❯`, `>_`, `├─`, `▸`, `•`, none or your own, and four shapes in place of a
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
