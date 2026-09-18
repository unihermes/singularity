# Singularity — Future Work & Feature Ideas

This backlog contains concrete, actionable improvements to the Hyprland desktop setup, Quickshell shell, and related dotfiles. Every item has a clear goal and a verification step. Items are organized by subsystem and type (Fixes, Architecture, Features), ordered by priority within each category.

---

## Fixes

### Hyprland / System Layer

#### ~~1. Fix toggleMinimize/maximizeFocused interaction desync~~ ✅

**Done:** Refocusing a hidden window by any route restores it and clears its entry (`maximizeFocused` → `restoreMinimized`).

**Goal:** Ensure minimize state stays consistent when a minimized window is refocused via alt-tab or workspace overlay, not just SUPER+C.

**Issue:** When a monocle window is minimized with SUPER+C (moved off-screen), the `minimized[addr]` entry is recorded. If the window is refocused by any route other than SUPER+C—such as ALT+Tab, the workspace overlay, or clicking its bar entry—`window.active` fires `maximizeFocused()`, which sees the window is off-screen but not marked `keptSmall`, so it silently teleports it back on-screen. The `minimized[addr]` entry is never cleared, so the next SUPER+C press incorrectly takes the "restore" branch and moves the now-full window back to its stale pre-minimize position, causing an unexpected jump.

**Verify:** Open two windows in monocle mode, minimize one with SUPER+C, then ALT+Tab to it. Confirm it reappears, then press SUPER+C again. Expected after fix: it minimizes again normally; currently it jumps to a different position because `minimized[addr]` is stale.

**File:** `dotfiles/hypr/.config/hypr/hyprland.lua:1009-1029` (minimize) and `:859-913` (focus hook).

---

#### ~~2. Fix toggleMinimize silently no-ops on tiled windows~~ ✅

**Done:** SUPER+C on a tiled window now shows a notification and records nothing.

**Goal:** Make SUPER+C either minimize any window (float it first) or provide clear feedback when it can't.

**Issue:** `hl.dispatch(hl.dsp.window.move(...))` only affects floating windows; in dwindle mode (SUPER+M toggle) or on monocle-exempt windows, pressing SUPER+C does nothing silently—no error, no notification. The `minimized[addr]` entry still gets written with the window's current position (even though nothing moved), corrupting the next toggle.

**Verify:** SUPER+M to dwindle mode, focus a tiled window, press SUPER+C. Expected after fix: window either visibly disappears/hides or a notification clearly states the action isn't possible; currently nothing happens and the window stays in place.

**File:** `dotfiles/hypr/.config/hypr/hyprland.lua:1011-1029`.

---

#### ~~3. Prune keptSmall/minimized tables on window close~~ ✅

**Done:** `window.close` hook drops the window's whole `windowState` entry.

**Goal:** Prevent stale entries from accumulating and leaking onto reused window addresses.

**Issue:** Both `keptSmall` and `minimized` tables grow monotonically over a session, with no cleanup on `window.close`. Hyprland window addresses are C++ pointer values, which can be reused after a window is destroyed. A new window opening with a reused address inherits stale entries from an unrelated, already-closed window—causing it to unexpectedly open at 70% size or be treated as already minimized.

**Verify:** Open a window, shrink it with SUPER+equal (adds to `keptSmall`), close it, then open several more windows and close them to encourage address reuse. Watch whether a newly-opened monocle window ever unexpectedly opens at 70% size instead of full. (This is difficult to trigger deterministically, but the fix—clearing tables on close—is trivial and removes the risk category entirely.)

**File:** `dotfiles/hypr/.config/hypr/hyprland.lua:763` (`keptSmall` definition) and `:1010` (`minimized` definition); needs a new `hl.on("window.close", ...)` hook.

---

#### ~~4. Verify: hyprland.start refire on hyprctl reload config-only~~ ✅

**Done:** Verified 2026-09-18: `hyprctl reload config-only` left quickshell/alttab-relay PIDs unchanged and opened no second startup terminal. No change needed.

**Goal:** Confirm that the autostart block doesn't relaunch every process on every settings change.

**Issue:** Animation Speed and Primary Display settings both rely on `hyprctl reload config-only` to re-run the config file and pick up changed state. If Hyprland's `"hyprland.start"` event fires on a config-only reload (not just genuine startup), every settings change would re-run the entire autostart block (lines 141-205): relaunching quickshell, alttab-relay (colliding with the already-running instance), wallpaper.sh, and spawning a second neutrino-startup terminal.

**Verify:** Note `pgrep -fa quickshell` and `pgrep -fa alttab-relay` PIDs. Toggle Animation Speed in Settings → Appearance (which triggers `hyprctl reload config-only`). Re-run the same `pgrep` commands and confirm the PIDs are unchanged and no second `neutrino-startup` Alacritty window appeared. If they match and no new terminal exists, the event is correctly scoped to startup only.

**File:** `dotfiles/hypr/.config/hypr/hyprland.lua:141-205`.

---

### Quickshell Services & Settings

#### 5. Fix camera privacy detection bitmask check

**Goal:** Camera privacy indicator should light up when a video-capture application is actually running.

**Issue:** The check uses strict equality (`===`) on a Pipewire node type bitmask: `n.type === (PwNodeType.Video | PwNodeType.Stream | PwNodeType.Source)`. A real webcam-capture node likely carries the `VideoSource` bit (and others) in addition to these three, so the strict equality never matches. The mic check above it works correctly because `AudioInStream` is a single dedicated bit, but the camera check has no equivalent and silently fails.

**Verify:** Start a video call or open a camera app (e.g. `cheese` or a browser video call) while the bar is visible. Check whether the camera privacy indicator appears. If it never does while the mic indicator correctly activates for audio capture, this confirms the bug.

**File:** `dotfiles/quickshell/.config/quickshell/services/Privacy.qml:39`.

---

#### ~~6. Fix primary-display write error handling~~ ✅

**Done:** `setPrimary()` goes through `AtomicFileWrite`. It only reports success once the write, `hyprctl reload` and the workspace move have all worked; otherwise it shows what failed, and a failed write also restores the previous selection.

**Goal:** Report write failures clearly instead of claiming success unconditionally.

**Issue:** Unlike every other settings write on the page, `setPrimary()` has no `stdout`/`stderr`/`onExited` handler. It calls `say(name + " is the primary display")` immediately after firing the process, regardless of whether `mkdir`, the state-file write, `hyprctl reload`, or the workspace move actually succeeded.

**Verify:** Make `~/.local/state/neutrino` read-only (`chmod -w`) or rename `hyprctl` off `$PATH`, then click a different "Primary" chip in Settings > Display. The UI will report success even though nothing happened, and the primary display won't change on next login. After fix, expect an error message or no success message at all.

**File:** `dotfiles/quickshell/.config/quickshell/settings/SettingsPageDisplay.qml:184-187` and the `setPrimary()` function.

---

#### ~~7. Fix FailedUnits.act() running guard~~ ✅

**Done:** Actions go through a FIFO queue, run one at a time.

**Goal:** Ensure only one systemctl action runs at a time; queue or skip rapid successive clicks.

**Issue:** `act()` has no guard against re-entrancy, unlike `refresh()`. If "Restart" is triggered on unit A and, before that process exits, "Reset failed" is triggered on unit B, the second call reassigns `actProc.command` while `actProc.running` is already `true`—a no-op in Quickshell. The action assigned last is what eventually executes; one of the user's actions is silently dropped.

**Verify:** With two failed units showing, rapidly click "Restart" on unit A and "Reset failed" on unit B (within <1 second). Check `systemctl --user status B` and `systemctl status A` afterward. One of the two actions will not have run.

**File:** `dotfiles/quickshell/.config/quickshell/services/FailedUnits.qml:40-46`.

---

#### ~~8. Fix window-rules page clobbering hand-edits~~ ✅

**Done:** The page now checks, at write time, that the file still holds the rules it's showing. If not, the click is refused and the page reloads from disk. Goes through `AtomicFileWrite` (#17).

**Goal:** Settings page should re-read `window-rules.json` before writing, preventing loss of concurrent edits.

**Issue:** `save()`/`write()` serialize the in-memory `rules` array straight to the file on every click without re-reading first. Since `window-rules.json` is a stow-linked, repo-tracked file that users might reasonably hand-edit or `git pull` a change into while the shell is running, any settings click after that overwrites the external edit.

**Verify:** With Settings open on "Window Rules", edit `~/.config/singularity/window-rules.json` by hand in a terminal (add a new rule object), then click any toggle in the UI (e.g. "Open fullscreen"). Check the file afterward—the hand-added rule is gone.

**File:** `dotfiles/quickshell/.config/quickshell/settings/SettingsPageWindowRules.qml:103-121`.

---

#### ~~9. Fix notifications write path atomicity~~ ✅

**Done:** Writes to `<target>.tmp` then `mv -f`, resolving the stow symlink first.

**Goal:** Prevent config.json corruption on process crash; use temp-file + atomic rename like every other settings page.

**Issue:** The write command writes directly over `config.json` with no temp file / atomic rename, unlike all other settings pages. If the shell/process is killed mid-write (crash, `kill -9`, disk-full), `config.json` is left truncated/corrupted instead of falling back to the last-good file.

**Verify:** Code-level inspection: compare `SettingsPageNotifications.qml:54` against the `.new`-file pattern in `SettingsPageShell.writeFile()` or `SettingsPageWindowRules.write()`. To reproduce: fill the disk (or use `strace` to block `printf`) mid-write, inspect `~/.config/swaync/config.json` for truncation/invalid JSON, versus other pages which leave the original intact.

**File:** `dotfiles/quickshell/.config/quickshell/settings/SettingsPageNotifications.qml:54`.

---

### Quickshell Bar, Flyouts & Windows

#### ~~10. Fix ALT+Tab switcher overflow~~ ✅

**Done:** Cards wrap onto a `Grid` sized to the columns that fit (13 on a 1920-wide screen), and the frame clips anything past the screen height. Not yet checked with 14+ real windows.

**Goal:** Make all open windows reachable and visible in the alt-tab card row, even with 14+ windows open.

**Issue:** With many windows, the card row's natural width exceeds the frame's clamp and the screen width. Cards spill past the frame's border and off-screen, becoming invisible and unreachable except by repeated Tab (blind navigation).

**Approach:** Add `clip: true` to the `PanelFrame` and implement either horizontal scroll (mouse wheel or swipe) or wrap behavior (cards flow to a second row) so all cards remain accessible.

**Verify:** Open 14+ windows on one workspace. Hold ALT and tap Tab repeatedly, and verify all windows remain visible in the frame and reachable via mouse click or repeated Tab key presses.

**File:** `dotfiles/quickshell/.config/quickshell/flyouts/AltTabSwitcher.qml:229-297` and `flyouts/FlyoutPanel.qml`.

---

#### ~~11. Fix iwd network-list parsing fragility~~ ✅

**Done:** There's no `iwctl --json`, so the list now comes from iwd's D-Bus API via `busctl --json=short` (GetManagedObjects + Station.GetOrderedNetworks). A failure shows "Couldn't read networks from iwd" in the flyout. This also fixed a bug: the old parser showed every network at 4 bars, because iwctl marks the empty bars with colour only. Verified against live iwctl output (same order and bars).

**Goal:** Make network scanning robust to future iwd output format changes; fail visibly instead of silently.

**Issue:** `shell.qml:783-856` parses `iwctl`'s human-formatted table using hardcoded `substr()` column offsets. Any iwd version change that reflows columns silently breaks parsing (empty/garbled SSID list) with no error surfaced to the user.

**Approach:** Either switch to `iwctl --json` output (if available in the installed version) for structured parsing, or add a validation check: if parsing yields suspiciously empty results, log a warning and/or show a fallback UI state indicating "network unavailable" rather than silently showing nothing.

**Verify:** Check the installed iwd/iwctl version for JSON output support. After implementation, update `iwctl` to a version with different column widths (or mock new column widths in testing), and verify the network flyout still shows valid SSIDs and signal bars, or shows a clear error message instead of silently breaking.

**File:** `dotfiles/quickshell/.config/quickshell/shell.qml:783-856`.

---

#### ~~12. Fix widget metadata desync~~ ✅

**Done:** Labels and icons moved to `Settings.widgetMeta`, next to `widgetDefaults`. The item ids have to stay in `BarModules.widgetItems`, so `shell.qml` warns at load when the three disagree. Verified by deleting an entry in a scratch copy.

**Goal:** Prevent a bar widget from appearing with a blank icon and raw key due to table desync.

**Issue:** `BarModules.widgetItems` and `ControlCentre.widgetMeta` are independently maintained; adding a widget requires editing both. Forgetting `widgetMeta` leaves the widget with a fallback `{label: key, icon: ""}`.

**Approach:** Extract widget metadata to a single shared definition (e.g. `constants/WidgetRegistry.qml` or a unified object in `Settings.qml`), and use it for both the bar module list and the Control Centre's Widgets page.

**Verify:** After consolidation, open Control Centre → Bar Widgets and add/remove a widget from the bar. Confirm the row always shows the correct label and icon (no blank/fallback), and the bar immediately reflects the change.

**File:** `dotfiles/quickshell/.config/quickshell/bar/BarModules.qml:37-44` and `flyouts/ControlCentre.qml:286-305` → unified definition.

---

## Architecture

### Hyprland / System Layer

#### ~~13. Consolidate per-window state into a single table~~ ✅

**Done:** `keptSmall` and `minimized` merged into `windowState[addr] = { small, minimized }` with one close hook. `monocleEnabled` stays separate; it's global, not per-window.

**Goal:** Replace three uncoordinated tables with one, with a single `window.close` cleanup hook.

**Issue:** `monocleEnabled`, `keptSmall`, and `minimized` each track different window state, addressed inconsistently. This makes cleanup ambiguous—when a window closes, which tables need pruning? It's exactly what let bug #3 above happen.

**Approach:** Create `windowState[addr] = { monocle = bool, small = bool, minimized = {x, y} }` (or similar) with one cleanup hook that removes all facets at once.

**Verify:** After consolidation, open two windows, minimize one, shrink one, toggle monocle—all four operations work exactly as before, and closing windows properly cleans up all associated state.

**File:** `dotfiles/hypr/.config/hypr/hyprland.lua:757-1029` (state definitions and use sites).

---

#### ~~14. Extract JSON decoder to a module~~ ✅

**Done:** Decoder is in `~/.config/hypr/json.lua`, loaded with `pcall(dofile, ...)` so a missing or broken file means no rules, not a broken config. Verified: rules still apply (Thunar opens floating at 1240×690 with `monocle-exempt`), and the decoder runs standalone under `lua`.

**Goal:** Move ~70 lines of hand-rolled JSON parsing out of the main config for reuse and unit testing.

**Issue:** `hyprland.lua:586-655` contains a complete general-purpose JSON decoder with no connection to window-rule semantics, living inline in the 1065-line file that also owns monocle emulation, autostart, and keybindings. As `window-rules.json`'s schema grows, the decoder should be independently testable.

**Approach:** Create `~/.config/hypr/json.lua` with the decoder function, `require` it at the top of `hyprland.lua`, and replace the 70-line inline block with a call.

**Verify:** After extraction, window-rules.json still loads and applies rules identically. The rules can still use `"regex": true` and `"negative:"` prefixes as before.

**File:** `dotfiles/hypr/.config/hypr/hyprland.lua:586-655` → `~/.config/hypr/json.lua` (new file).

---

#### ~~15. Extract workspace count constant~~ ✅

**Done:** `MAX_WORKSPACES` defined at the top of `hyprland.lua`, used by the bind loop and the rule loader.

**Goal:** Replace two independently hardcoded `5`s with a shared constant.

**Issue:** Workspace count is hardcoded in two places: keybinds loop (`hyprland.lua:424`, `for i = 1, 5`) and JSON rule loader (`hyprland.lua:711-712`, `ws >= 1 and ws <= 5`). If the count ever changes, both sites must be updated in lockstep with no compiler/linter to catch a miss.

**Approach:** Define `MAX_WORKSPACES = 5` near the top of the file, use it in both places.

**Verify:** After consolidation, SUPER+1 through SUPER+5 still focus their respective workspaces, and the rule loader still accepts workspace 1-5 as valid.

**File:** `dotfiles/hypr/.config/hypr/hyprland.lua:330-425` (add constant) and `:424`, `:711`.

---

### Quickshell Services & Settings

#### ~~16. Make HyprLuaWrite a singleton~~ ✅

**Done:** `pragma Singleton`. Results come back through per-call callbacks instead of signals, so each page only sees its own. Verified with two concurrent patches against a scratch `HOME`: both landed.

**Goal:** Prevent concurrent editors of hyprland.lua from racing and clobbering each other's changes.

**Issue:** `HyprLuaWrite` is instantiated as a plain `Item` by `SettingsPageDisplay.qml:205`, `SettingsPageInput.qml:71`, and the Keybinds editor. Each instance keeps its own `confFile` snapshot and `queue`. Two windows open at once (e.g. standalone Keybinds + Settings > Input) can each read the file at time T0; whichever finishes last overwrites the other's change. The shared backup at `backupPath` only preserves the latest writer's backup, breaking undo for the other editor.

**Approach:** Mark `HyprLuaWrite.qml` with `pragma Singleton` (like `Settings`, `Theme`, etc.), so there is exactly one write queue for `hyprland.lua` regardless of open windows. Update each page's import to use `HyprLuaWrite { ... }` instead of constructing an instance.

**Verify:** Open standalone Keybinds and Settings > Input side by side. In Input, toggle "Natural scrolling"; within 1 second, add or edit a bind in Keybinds. Inspect `hyprland.lua` afterward—both changes should be present, not one overwritten.

**File:** `dotfiles/quickshell/.config/quickshell/services/HyprLuaWrite.qml:1` (add `pragma Singleton`); update `SettingsPageDisplay.qml`, `SettingsPageInput.qml`, and other pages to use the singleton.

---

#### ~~17. Consolidate atomic-write shell scripts~~ ✅

**Done:** `services/AtomicFileWrite.qml`: a shared queue, a fresh read and transform at write time, optional `bash -n`/`luac -p` check, backup, `readlink -m` + temp file + `mv`, then an optional reload command. HyprLuaWrite and the Shell, Power, Window Rules and Notifications pages all use it. Tested in a throwaway Quickshell config (queue order, refusal, unchanged, syntax, stow symlink kept).

**Goal:** Replace five near-duplicate write-to-temp + verify + atomic-rename + reload helpers with one shared component.

**Issue:** `HyprLuaWrite.writeScript` (`services/HyprLuaWrite.qml:118-129`), `SettingsPageShell.writeFile` (`settings/SettingsPageShell.qml:164-176`), `SettingsPageNotifications.setKey` (`settings/SettingsPageNotifications.qml:54`), `SettingsPagePower.writeIdle` (`settings/SettingsPagePower.qml:110-118`), and `SettingsPageWindowRules.write` (`settings/SettingsPageWindowRules.qml:117-119`) each reimplement "write to temp, verify, atomic-rename, reload, report ok/failure" with inconsistent atomicity (`cat >` vs `mv -f`) and inconsistent staleness checking.

**Approach:** Create a generic `AtomicFileWrite.qml` singleton taking a path, a transform function, optional post-write reload command, and optional staleness check. Use it everywhere; this also closes bug #8 (window-rules staleness) and fixes #9 (notifications atomicity) for free.

**Verify:** After consolidation, toggling settings on Power, Keybinds, Audio, Window Rules, and Notifications pages all succeed and the files update atomically. No regression in any page's write behavior.

**File:** New file: `dotfiles/quickshell/.config/quickshell/services/AtomicFileWrite.qml`; update the five settings pages to use it.

---

#### ~~18. Fix mkdir -p bootstrap pattern duplication~~ ✅

**Done:** No shared helper was needed. Quickshell's `FileView` writes (`setText`, `writeAdapter`, atomic or not) create missing parent directories themselves (tested), so all three `mkdir -p` processes were removed. The animation-speed write moved to `AtomicFileWrite`, which also creates directories.

**Goal:** Establish one shared startup utility for ensuring `~/.local/state/neutrino` exists before any writes.

**Issue:** Three separate services (`Settings.qml:249-252`, `AppearanceSync.qml:86-90`, `Wallpaper.qml:93-96`) each spin up their own one-shot `mkdir -p` process, only one of which (`AppearanceSync`) correctly gates the first write on `onExited`. This is a duplication and inconsistency vector.

**Approach:** Create a shared utility (either a singleton service or a well-documented convention) that ensures the directory exists before any other state writes are attempted. Update all three to use it consistently.

**Verify:** Delete `~/.local/state/neutrino`, restart the shell, and trigger early actions (appearance sync, wallpaper change, settings load) rapidly at startup. All three should succeed and their state files should be written correctly; no silent failures from mkdir races.

**File:** New file or documented pattern; update `Settings.qml`, `AppearanceSync.qml`, and `Wallpaper.qml`.

---

#### 19. Split System.qml into focused components

**Goal:** Reduce System.qml from 1,334 lines to ~300-400 line files; make stats sampling and UI reusable independently.

**Issue:** System.qml mixes non-visual data (CPU/mem/net/disk polling, Process definitions), formatting helpers (`pct`, `gib`, `rate`, etc.), and three-column UI + inline components (`Gauge`, `Spark`, etc.). Each concern should be independently readable/testable.

**Approach:** Extract non-visual sampling into a `services/SystemStats.qml` singleton (or non-visual `Item`), move format helpers to a shared utility, and split the UI into separate column files (`SystemUsageColumn.qml`, `SystemProcessColumn.qml`, `SystemSpecsColumn.qml`). Reuse `Gauge` and `Spark` components elsewhere (e.g. a future battery-history graph).

**Verify:** After split, the System window still opens showing identical live CPU/mem/net/process values and 60s graphs animate the same as before. No file exceeds ~400 lines. `Gauge` and `Spark` components are reusable in other modules.

**File:** `dotfiles/quickshell/.config/quickshell/windows/System.qml` (split into multiple files).

---

#### 20. Extract network service to services/Network.qml

**Goal:** Move shell.qml's inline network/brightness/battery logic into the existing services singleton pattern.

**Issue:** `shell.qml:339-922` contains Pipewire/UPower/Bluetooth helpers, brightness sysfs polling, and ~150 lines of `iwctl` Process plumbing as properties/children of the `PanelWindow`, rather than as standalone services like `Weather`, `Media`, `Updates`. This is why bug #23 above (rapid Process command drops) is easy to introduce.

**Approach:** Extract into a `services/Network.qml` singleton (mirroring `Weather`, `Updates`, etc.), move all Process definitions and connection logic there, and use the singleton from flyouts instead of direct Process construction. This also fixes the Process re-entrancy issue.

**Verify:** After extraction, the Network bar module, Network flyout, and Control Centre's Wi-Fi quick-action all show live SSID/signal/power state and can connect/disconnect exactly as before. `shell.qml` shrinks by ~600 lines.

**File:** New: `dotfiles/quickshell/.config/quickshell/services/Network.qml`; update `shell.qml` and flyouts.

---

#### 21. Factor out OverlayWindow base component

**Goal:** Eliminate duplicated full-screen overlay boilerplate across 4-5 flyout files.

**Issue:** `AltTabSwitcher.qml:160-186`, `WorkspaceOverlay.qml:43-57`, `LevelToast.qml:35-48`, `LayoutToast.qml:27-43`, and `FlyoutPanel.qml:63-81` each independently declare ~15 lines of identical boilerplate: `screen`, `anchors`, `implicitWidth`/`implicitHeight`, `exclusionMode`, `color`, `WlrLayershell.layer`, `WlrLayershell.namespace`. This is the exact pattern the repo warns against elsewhere.

**Approach:** Create a shared `OverlayWindow.qml` base component (screen-spanning transparent overlay layer, parameterized by namespace/keyboard-focus) that these four compose instead of copying.

**Verify:** After factoring out the base, trigger each surface (SUPER+W workspace overlay, hold ALT+Tab, volume/brightness key, SUPER+M layout toggle) on a multi-monitor setup and confirm each still appears full-screen only on the focused monitor, sized and positioned identically to before. No regression in any overlay's behavior.

**File:** New: `dotfiles/quickshell/.config/quickshell/flyouts/OverlayWindow.qml`; update `AltTabSwitcher.qml`, `WorkspaceOverlay.qml`, `LevelToast.qml`, `LayoutToast.qml`, `FlyoutPanel.qml`.

---

## Features

### Hyprland / System Layer

#### 22. Alt-tab relay wire-format health check

**Goal:** Detect silent breakage from future Quickshell updates; log failures clearly instead of letting them pass silently.

**Issue:** `alttab-relay.cpp:29-35` documents the risk: *"a future Quickshell update could silently change [the wire format] out from under this file."* Today, a format mismatch fails silently—the relay stays reachable but writes a struct shape Quickshell no longer understands.

**Approach:** On relay startup, send a known-good `alttab cancel` (or equivalent safe ping) and verify no unexpected disconnect/error against `~/.cache/alttab-relay.log`. A format mismatch should produce a clear warning.

**Verify:** After implementation, `tail -f ~/.cache/alttab-relay.log`, trigger `~/quickshell-git` package update that changes wire format (hypothetically), restart the relay, and confirm a clear warning appears rather than silent failure.

**File:** `dotfiles/hypr/.config/hypr/alttab-relay.cpp` (add self-test on startup).

---

#### 23. AC/battery-aware hypridle timeout

**Goal:** Shorten idle timeout on battery power (e.g. 10 min suspend vs 20 min on AC) to improve battery life.

**Issue:** `hypridle.conf:22-55` uses one fixed timeout ladder (4/5/5.5/20 min) regardless of power source. `install.sh:408-458` already installs udev-driven AC/battery signaling (`/usr/local/bin/singularity-power-profile`) solely for CPU governor switching. Reusing that signal for hypridle would directly improve battery life on a laptop-first setup.

**Approach:** Modify `hypridle.conf` to listen on the power-profile signal (or create a lightweight wrapper script) and dynamically adjust the suspend timeout: ~10 min on battery, ~20 min on AC. This likely requires `hypridle` supporting D-Bus signal listening, or a separate idle-aware script that restarts hypridle when AC state changes.

**Verify:** Unplug AC and sit idle; confirm suspend triggers meaningfully sooner than 20 minutes. Plug back in and confirm the longer timeout returns.

**File:** `dotfiles/hypr/.config/hypr/hypridle.conf` and related scripts.

---

#### 24. Per-workspace monocle-vs-tiled override

**Goal:** Allow pinning specific workspaces to always-tiled or always-monocle, independent of SUPER+M global toggle.

**Issue:** SUPER+M (`toggleLayout`) is global—every workspace on the current output switches between monocle and dwindle together. There's no way to say "workspace 1 is always monocle, workspace 3 is always tiled" even though the machinery already exists in the code.

**Approach:** Extend `window-rules.json` schema with a `"layout": "monocle" | "dwindle"` per-rule field, or add per-workspace settings to the Settings window's Display page. The toggle machinery in `toggleLayout()` is already there; it just needs a per-workspace override check.

**Verify:** After implementation, set workspace 1 to always-monocle and workspace 3 to always-tiled via Settings. SUPER+M should affect workspaces 2/4/5 but leave 1/3 in their pinned layouts. When focusing windows on 1/3, they should respect their pinned layouts rather than the global mode.

**File:** `dotfiles/hypr/.config/hypr/hyprland.lua` (modify `toggleLayout` and workspace-rule loading); `dotfiles/singularity/.config/singularity/window-rules.json` schema (add optional `layout` field).

---

### Quickshell Services & Settings

#### ~~25. FailedUnits failure notifications~~ ✅

**Done:** New failed units (including on the first poll) send a critical `notify-send`. Verified with a `systemd-run --user /bin/false` unit.

**Goal:** Notify user immediately when a systemd unit fails, not just change a bar icon.

**Issue:** The module was built specifically because *"on 2026-09-12 the polkit agent sat failed for over an hour, and nothing on screen said so."* Today it only changes a bar icon—still passive, so a failure while the user isn't looking at the bar (screen off, fullscreen app, away from desk) is just as invisible.

**Approach:** Add a `notify-send` (à la `Updates.qml`'s pattern) the first time `probe`'s result set gains a unit that wasn't in the previous `units` list. This turns a bar glyph into an actual notification.

**Verify:** `systemctl --user start` a unit configured to fail immediately (or `systemctl --user mask` + `start` a trivial one) while the Quickshell bar is not focused/visible. Expected after fix: a notification appears; currently only the bar icon changes (easy to miss).

**File:** `dotfiles/quickshell/.config/quickshell/services/FailedUnits.qml`.

---

#### ~~26. Weather retry on failure~~ ✅

**Done:** 3-minute retry timer runs only while `failed` is true.

**Goal:** Recover from transient network failures faster; reduce stale weather duration from 30 minutes to ~2-3 minutes on error.

**Issue:** `Weather.qml:109-115` only refreshes every 30 minutes, with no shorter backoff when `fetch` fails (`root.failed = true`). A single dropped request leaves the weather module stale/wrong for half an hour with no self-correction.

**Approach:** Add a short one-shot retry timer (e.g. 2-3 minutes) that fires only when `failed` is true, independent of the main 30-minute cadence.

**Verify:** Block outbound access to `wttr.in` briefly around a scheduled refresh (e.g. via `/etc/hosts` or firewall) to force `root.failed = true`, then restore access. Expected after fix: weather recovers within 2-3 minutes; currently it waits until the next full 30-minute tick.

**File:** `dotfiles/quickshell/.config/quickshell/services/Weather.qml:100-115`.

---

### Quickshell Bar, Flyouts & Windows

#### 27. Add forget action for Wi-Fi and Bluetooth

**Goal:** Let users remove stale/one-off networks and unpair devices from the UI without dropping to a terminal.

**Issue:** `NetworkFlyout.qml` and `BtDeviceRow.qml` only offer connect/disconnect/pair. There's no `iwctl known-networks <ssid> forget` or `bluetoothctl disconnect <device>` + `remove` in the UI. Given the shell's goal of avoiding terminal round-trips for system state, this is a concrete, currently-unreachable-without-a-terminal gap.

**Approach:** Add a "forget" or "remove" button/action to each known network row and each paired device row, triggering the appropriate iwctl/bluetoothctl command and re-fetching the lists.

**Verify:** Connect to a test SSID or pair a test Bluetooth device, then attempt to remove/forget it entirely from the Network or Bluetooth flyout UI. Expected after fix: a clear "forget" or "remove" button appears; currently this is impossible without a terminal.

**File:** `dotfiles/quickshell/.config/quickshell/flyouts/NetworkFlyout.qml` and `flyouts/BtDeviceRow.qml`.

---

