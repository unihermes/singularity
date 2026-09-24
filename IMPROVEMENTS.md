# Singularity — improvements drawn from dwm-titus

Working document. Read the **Audit** before implementing anything: the first
draft of this file (2026-09-22, before the codebase had been read properly)
assumed Singularity was an early-stage dotfiles repo and recommended a pile of
things that already exist. Most of that draft was wrong. What follows is the
corrected version, kept as a live checklist.

Source of comparison: `~/Downloads/dwm-titus-main` (ChrisTitusTech/dwm-titus, a
Fedora/X11/dwm desktop with a Quickshell panel).

---

## How to use this file

- **Audit** says what actually exists, so nothing gets rebuilt twice.
- **Open items** is the queue, roughly in value order.
- **Decisions** records things deliberately *not* done, with reasons — read it
  before "fixing" something it covers.
- **Session log** is the handoff. Append to it; don't rewrite history.

---

## Audit — what Singularity already has

Nearly every structural recommendation from the dwm-titus comparison was
already built here, often further than dwm-titus takes it.

| Capability | dwm-titus | Singularity | Notes |
| --- | --- | --- | --- |
| Settings window | Yes, ~15 panes | **Yes**, 13 pages | `windows/SettingsWindow.qml` + `settings/SettingsPage*.qml` |
| Settings search | No | **Yes** | `/` box, backed by `services/SettingsIndex.js` |
| Control Centre | Yes | **Yes** | `flyouts/ControlCentre.qml` |
| Launcher | Yes | **Yes** | `flyouts/Launcher.qml`, `services/Apps.qml` |
| Keybind viewer | Yes (Super+/) | **Yes** | `settings/SettingsPageKeybinds.qml`, `KeybindsBody.qml` — editable, not just a cheatsheet |
| Bar widget show/hide + reorder | Yes | **Yes** | `bar/BarWidgetList.qml`, drag-reorder across LEFT/CENTRE/RIGHT |
| Theme / look system | `themes.toml` | **Yes**, richer | `services/Looks.js`, `LookStore.qml`, `Theme.qml`, user looks in `looks.json` |
| Theme push to GTK/Qt/terminal/editor | gsettings + qt6ct | **Yes**, wider | `services/AppearanceSync.qml` → gsettings, qt6ct, alacritty, nvim, wofi, swaync |
| System monitor / health | One health card | **Yes**, far richer | `windows/system/` — CPU, memory, storage, network, processes, hardware, power |
| Notifications | Yes | **Yes** | `services/Notifications.qml`, swaync integration |
| Display settings | Wizard + pane | **Yes** | `settings/SettingsPageDisplay.qml`, writes Hyprland monitor rules |
| Window rules UI | `window-rules.toml` | **Yes**, GUI | `settings/SettingsPageWindowRules.qml` |
| Screenshot helper | `dwm-screenshot` | **Yes** | `dotfiles/hypr/.config/hypr/screenshot.sh` |
| Installer | `install.sh`, profiles | **Yes** | `install.sh` + `link.sh`, idempotent, `packages/` lists |
| README / docs | Site + guides | **Yes** | `README.md`, 366 lines |
| Flyouts for every bar module | Partial | **Yes** | battery, bluetooth, brightness, calendar, media, network, privacy, updates, volume, weather, workspaces… |

**Conclusion:** the useful remainder is small and specific. It is listed below.

---

## Open items

*(Empty — the queue drawn from the dwm-titus comparison is done. What was left
of it turned out to be deliberate design, and moved to Decisions below.)*

A standing chore, not a feature: **`services/SettingsIndex.js` is maintained by
hand** and silently drifts. Two entries were already wrong by the time it was
checked, both introduced earlier in the same day's work. The drift check is
now `tools/check-settings-index.py`, run by the pre-commit hook
(`tools/git-hooks/pre-commit`, enabled by `link.sh`) whenever a Settings page or
the index is staged.

---

## Decisions — deliberately not doing

**TOML config layer (`hotkeys.toml` / `themes.toml` / `window-rules.toml`).**
The first draft of this file recommended porting dwm-titus's TOML
configuration wholesale. Do not. dwm-titus needs TOML because dwm is a C
program whose config is a compiled header — TOML is how it escapes a
recompile. Singularity has no such constraint: it already has live GUI editing
(Keybinds, Window Rules, Appearance pages), JSON state persisted through
`Settings.qml`'s `FileView`+`JsonAdapter`, and generated Hyprland config via
`HyprLuaWrite.qml`/`HyprTables.js`. Adding TOML would mean a second source of
truth for the same settings and a sync problem between them. The existing model
is the better one.

**Rebuilding the settings architecture per the first draft's file tree.** The
proposed `panes/` + `models/` split is roughly what `settings/` +`services/`
already do, under different names. Not worth the churn.

**A separate `docs/` tree.** The README is thorough and current. Split it only
if it actually outgrows one file.

**Per-widget bar options** (a volume/battery percentage as text, an SSID beside
the Wi-Fi icon, more clock formats). The bar is icon-only *on purpose* and says
so in its own comments: the volume module's reads "the bar carries the level
now, so the icon only has to say muted or not — and those two glyphs are the
same width, so the chip no longer resizes as you scroll", and the battery's
"the level is the bar's job". The numbers live in `fillValue`, and the widths
are deliberately stable. Adding text readouts would undo both. The flyout
behind each module is where the detail belongs.

**Night Light in Settings.** It already has a toggle *and* a temperature
stepper in both the Control Centre and the Brightness flyout. Putting it in
Settings → Display would mean plumbing a `shellRoot` reference through
`SettingsWindow` into its page `Loader` — no Settings page currently takes one
— to reach `nightLight`, which is deliberately transient session state on the
shell root rather than a persisted setting (only `nightLightKelvin` persists).
Real plumbing and a scope decision for a control that is already two clicks
away. Left alone.

**Weather units in Settings.** Same shape of question, smaller: `weatherUnits`
persists but is only switched from the weather flyout, which is the natural
place to change °F/°C — you are looking at the temperature at the time. There
is no general/misc Settings page it would belong to, and adding one for a
single toggle isn't worth it.

---

## Session log

### 2026-09-22 — Network settings page

**Done:**

- `settings/SettingsPageNetwork.qml` (new). Wi-Fi radio toggle, link details
  (interface, IPv4, gateway, MAC, bitrate/signal), full in-range list with
  connect / inline passphrase prompt / forget, rescan.
  - State and iwctl calls reuse `services/Network.qml` unchanged, so the bar
    module, flyout and Control Centre stay in agreement.
  - Link details come from a page-local `Process` running `ip` and `iw`,
    because nothing else wants them and a page is built on open / destroyed on
    leave. Device name is passed as an **argv parameter**, not interpolated
    into the script text.
  - Rows show lock **and** signal bars; the flyout shows one or the other for
    want of room.
- `windows/SettingsWindow.qml` — registered the page (id `network`, after
  `audio`).
- `services/SettingsIndex.js` — 7 search entries so `/` finds these settings.
- `packages/pacman.txt` — added `iw` (reads live bitrate/signal). Optional in
  practice: the Link row hides itself when `iw` is missing, which is how it
  behaved during development, since `iw` was not installed.

**Verified:** shell restarts clean (no warnings/errors in
`~/.cache/quickshell.log`), page opens via `qs ipc call settings open network`,
screenshot confirms real values (wlan0, 192.168.1.80/24, gateway, MAC, 30
networks listed, connected network ticked).

**Gotcha worth remembering:** `SettingsField`'s control slot sets
`height: childrenRect.height`, so a *direct* child of that slot must not use
`anchors.verticalCenter: parent.verticalCenter` — it makes the row's height
depend on itself and QML logs a binding loop. Wrap in a `Row`/`Column` (as
`SettingsPageAudio.qml` does) or simply don't anchor vertically. Cost me one
debug cycle; five fields, five loops.

**Also note:** the Qt LSP in this workspace cannot resolve `QtQuick` /
`Quickshell.Io` imports, so it reports floods of false "Type not found" /
"unqualified access" warnings on any new or edited QML file. Ignore them;
validate by restarting the shell and reading `~/.cache/quickshell.log`.

---

### 2026-09-22 — Bluetooth settings page

**Done:**

- `settings/SettingsPageBluetooth.qml` (new). Adapter power (with the
  rfkill-blocked state called out), adapter name and `hciN` id, discoverable
  and pairable toggles, paired list, scan control, nearby list.
  - Device rows are `flyouts/BtDeviceRow.qml` **reused unchanged** — it already
    owns connect / disconnect / pair / trust-on-pair / forget, and depends on
    nothing but the device object. No new service was needed: Bluetooth comes
    from Quickshell's own `Quickshell.Bluetooth` (BlueZ), not a `services/`
    file. There is no `services/Bluetooth.qml` and there doesn't need to be.
  - The nearby list is uncapped and has a "show N unnamed" toggle. The flyout
    caps at 10 and only *counts* the unnamed ones — they're BLE privacy
    beacons with rotating addresses that can't be paired with, so they're
    hidden by default here too, just reachable. Deliberately not persisted:
    it's a "let me look" switch, not a setting.
  - Discovery stops in `Component.onDestruction`, so leaving the page can't
    strand the radio scanning (the flyout does the same on close).
- `windows/SettingsWindow.qml` — registered (id `bluetooth`, after `network`).
- `services/SettingsIndex.js` — 6 search entries.

**Verified:** clean restart, page opens via
`qs ipc call settings open bluetooth`, screenshot shows real values (adapter
"Neutrino" / `hci0`, paired "Arctis Nova 7", radio-off state handled).

**Not verified — pick this up first if touching the page:** the radio was off
throughout, so the powered-on paths (Discoverable, Pairable, Scan, the nearby
list populating) were never exercised live. I chose not to power it on: the
paired Arctis Nova 7 would likely have auto-connected and moved the default
audio sink mid-session. Those rows are plain property bindings onto
`BluetoothAdapter`, so the risk is low, but they are unproven.

**Gotcha:** `address` is a property of `BluetoothDevice`, **not**
`BluetoothAdapter` — the adapter has `name`, `adapterId`, `dbusPath`,
`enabled`, `state`, `discoverable(+Timeout)`, `pairable(+Timeout)`,
`discovering`, `devices`. Binding `adapter.address` logs
"Unable to assign [undefined] to QString". To check a Quickshell type's real
surface:

```sh
python3 - <<'EOF'
import re
t = open('/usr/lib/qt6/qml/Quickshell/Bluetooth/quickshell-bluetooth.qmltypes').read()
for c in re.findall(r'Component \{.*?\n    \}', t, re.S):
    n = re.search(r'name: "([^"]+)"', c)
    p = re.findall(r'Property \{\s*name: "([^"]+)"', c)
    if p: print(n.group(1), '->', p, '\n')
EOF
```

**Also:** the three adapter-state helpers (`poweredOn` / `blocked` /
`setPowered`) are duplicated from `shell.qml`'s bar helpers rather than
shared. They compare against the `BluetoothAdapterState` enum, which only a
QML file importing `Quickshell.Bluetooth` can see, so there is no common place
(a `.pragma library` JS file can't import QML modules) that both the bar and a
Settings page could take them from. Six lines; left duplicated on purpose,
with a comment at each site.

---

### 2026-09-22 — Per-application mixer on the Audio page

**Done:** `settings/SettingsPageAudio.qml` grew PLAYING and RECORDING
sections listing every Pipewire stream with its own volume slider, percentage
and mute — the thing `pavucontrol` was being launched for from the volume
flyout.

- Streams are split by Pipewire's **`media.class`** (`Stream/Output/Audio` vs
  `Stream/Input/Audio`), *not* by `isSink`. On a stream that flag reads as the
  direction of the node it feeds, which is inverted relative to how it reads on
  a device and very easy to ship backwards.
- The existing `Level` component was parameterised (`title`, `subtitle`,
  `subtitleFallback`) rather than duplicated, so device rows and app rows are
  the same control.
- **The `PwObjectTracker` must include the streams.** `audio.volume` /
  `audio.muted` stay invalid on an untracked node, so without adding them every
  app row reads 0% and the slider won't move. A row showing a real percentage
  is the proof the tracker is right.
- Row titles use `application.name`, falling back to the node's own name. The
  hint shows `media.name` only when it differs, and a value that looks like a
  path is cut to its basename — a player handed a file reports the whole path,
  which wrapped over five lines.
- `services/SettingsIndex.js` — 2 entries. They name their *heading*
  (`label: "Playing"` / `"Recording"`, `section: ""`) rather than a field,
  because the rows are named after whatever is running and there is no stable
  field label to scroll to. An entry with `label: ""` would render a blank
  search result — don't.

**Verified:** all 12 Settings pages open clean (no warnings/errors). Mixer
tested against two real streams — `pw-play` under PLAYING and `cava` (the
shell's own visualiser capture) under RECORDING — both at 100% with working
mute chips, plus the empty state once the stream stopped.

**How to get a test stream** (there usually isn't one, and the section is
empty without it):

```sh
python3 -c "
import wave
w=wave.open('/tmp/silence.wav','w'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(44100)
w.writeframes(b'\x00'*(44100*4*600)); w.close()"
setsid pw-play --volume=0 /tmp/silence.wav >/dev/null 2>&1 &
pw-dump | grep -A2 '"media.class": "Stream'   # confirm the node exists
```

Silent and at zero volume, so it makes no noise. Note the stream node
disappears the moment playback *finishes* even though the process lingers —
make the file longer than the debugging session, or the section goes empty
mid-test and looks like a bug in the filter. (It did.)

**Note:** `pkill` is blocked by the harness in this environment; find the pid
with `pgrep -af` and kill that instead.

---

### 2026-09-22 — `diagnose` CLI

**Done:** `dotfiles/singularity/.config/singularity/diagnose.sh` (new), aliased
as `diagnose` in `.bashrc` beside `clean`. Read-only; safe to run and to paste
the output of.

Covers session (Hyprland/Quickshell running + versions), graphics (GPU,
driver, monitor count), audio (the three user units + default sink), network
(iwd, device, SSID, IPv4, reachability), storage (colour-graded at 85/95%),
packages, failed units, the tools the shell shells out to, and the
error/warning count from `~/.cache/quickshell.log`. `-v` adds the log lines
themselves and a filtered journal tail.

- Placement follows `clean.sh` exactly: script under
  `.config/singularity/`, alias in `.bashrc`. That directory is a *stow
  symlink to the repo*, so a new file there is live immediately — no relink.
- Deliberately depends on nothing but coreutils and whatever it reports on.
  Every tool is probed with `have()` and reports "not installed" rather than
  failing, because the case this exists for is the shell being broken.
- It correctly flags `iw` as missing right now (added to `pacman.txt` in the
  Network session but not installed on this machine) — a real finding, not a
  bug.

**Three bash traps hit, all worth remembering:**

1. **Naming a helper `head()` shadows `/usr/bin/head`.** The version helper
   pipes through `head -1`, so it silently called the function instead and
   printed `== -1` as a section header. Renamed to `sect()`. Don't name shell
   helpers after coreutils.
2. **`grep -c` prints `0` *and* exits 1** when nothing matches, so
   `$(grep -c … || echo 0)` yields `"0\n0"` and the later `(( ))` dies with
   "arithmetic syntax error". Drop the `|| echo 0`.
3. **`hostname` is not installed**; `${HOSTNAME}` (bash builtin) is.

Also: one coredump entry in the journal carries a 40-line stack trace that
buries everything else, so `-v` strips frames/ELF notes and truncates width.
The introducing "dumped core" line is kept — that's the signal.

**Note:** the coredumps visible in `-v` output are from my own `qs kill`
restarts this session, not a real fault.

---

### 2026-09-22 — Search-index drift, and closing out the queue

Started on the last open item (per-widget bar options) and found it shouldn't
be built — see Decisions. Swept for real defects instead and fixed what turned
up.

**Fixed — both were drift I introduced earlier the same day:**

- `System font` (added to the Appearance page in the font-decoupling work) had
  **no index entry at all**, so Settings search could not find it.
- The Bluetooth index entry still said `label: "Address"` after the field was
  renamed to `Interface` — the row was found by keyword but the page would
  highlight nothing, because `scrollTo` matches on the label exactly.
- `diagnose.sh` left a trailing space on the Default sink line (`[vol …]` was
  stripped without the whitespace before it).

**Audited clean:** every `source:` in `SettingsWindow.pages` resolves;
`widgetMeta` / `widgetDefaults` / `widgetItems` agree; index parses to 109
entries; all pages load with no warnings.

**The drift check, worth re-running after any field is added or renamed.**
Both directions matter — an index entry pointing at a field that no longer
exists, and a field with no entry:

```sh
cd dotfiles/quickshell/.config/quickshell
python3 - <<'PY'
import re, os
idx = open('services/SettingsIndex.js').read()
indexed = {}
for page, sec, label in re.findall(r'\{\s*page:\s*"([a-z]+)",\s*section:\s*"([^"]*)",\s*label:\s*"([^"]*)"', idx):
    indexed.setdefault(page, set()).add(label)
for f in sorted(os.listdir('settings')):
    m = re.match(r'SettingsPage([A-Z]\w+)\.qml$', f)
    if not m: continue
    page = m.group(1).lower()
    src = open('settings/' + f).read()
    labels = set()
    for blk in re.finditer(r'SettingsField\s*\{(.*?)\n    \}', src, re.S):
        lm = re.search(r'label:\s*"([^"]+)"', blk.group(1))
        if lm: labels.add(lm.group(1))
    miss = labels - indexed.get(page, set())
    if miss: print(f"{page}: field has no index entry -> {sorted(miss)}")
PY
```

**Expect false positives** and read before fixing: labels built at runtime
(`"Workspace " + key` on Window Rules, the hypridle-derived rows on Power, the
mixer's app names) can't be seen statically, and entries that name a *section*
rather than a field are legitimate — the index header documents that they open
the page and highlight nothing. Only a genuinely static field with no entry, or
an entry whose label no longer exists, is a real defect.

---

### Working method that worked well

1. `qs kill; setsid quickshell > ~/.cache/quickshell.log 2>&1 &`
2. `qs ipc call settings open <page>` — pages are lazy-loaded behind a
   `Loader`, so a clean startup log does **not** mean a new page compiles.
   Always open it.
3. `grep -E "WARN|ERROR" ~/.cache/quickshell.log`
4. `grim <file>.png` and actually look at it.
