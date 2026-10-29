# Singularity

Arch + Hyprland (Lua config) + a Quickshell (QML) shell. `dotfiles/<pkg>/` mirrors `$HOME`
and is symlinked in, so `~/.config/quickshell` *is* `dotfiles/quickshell/.config/quickshell`
(called `qs/` below). Saving a QML file hot-reloads the running shell.

## Where things are

- `qs/shell.qml`: entry point, IPC handlers, one `screenScope` per screen holding the
  open flyout (`toggleFlyout`, `openFlyout`).
- `qs/services/Theme.qml`: every size/colour token (`spaceXs..Xl`, `sp()`, `flyoutOffset`,
  `channelWidth`). `Settings.qml`: persisted settings (`~/.local/state/singularity/appearance.json`).
  `Looks.js` / `Styles.js`: looks and styles.
- `qs/bar/`: `Bar.qml` (window, `widgetItem(key)`), `BarModules.qml` (every module; the big ones in
  `WorkspacesModule`, `WindowsModule`, `TrayModule`).
- `qs/flyouts/`: `FlyoutPanel.qml` (shared flyout shell: padding, position, grown mode),
  `PanelFrame.qml`, `SectionRuns.qml` (section frames), shared rows/controls
  (`FlyoutRow`, `FlyoutHeading`, `FlyoutSegmented`, ...), one `*Flyout.qml` per module,
  `ControlCentre.qml`.
- `qs/settings/`: `SettingsPage*.qml` (one per page), `appearance/` (Appearance tabs).
  Search index is `services/SettingsIndex.js`; keep it in step with the pages.
- `qs/windows/`: Settings, System, Keybinds, Notes windows.
- `qs/desktop/`: the desktop widgets (straight on the wallpaper, one surface each under the windows), their edit mode
  and the desktop's right-click menu;
  placement maths in `services/WidgetPlacement.js`.
- `qs/sidebar/`: the Claude sidebar (SUPER+I), driven by `services/Ai.qml` and
  `ClaudeSession.qml` (`claude -p` over stream-json); helpers in `scripts/ai.py`, `ai-desktop.sh`.
- `dotfiles/hypr/.config/hypr/`: `hyprland.lua` requires `shared`, `displays`, `env`,
  `autostart`, `looks`, `input`, `overrides`, `game-keys`, `binds`, `alttab`, `windows`
  (which requires `window-rules` for the static rules and `window-keys` for the arrow keys).
- `dotfiles/singularity/.config/singularity/*.defaults.*`: templates `link.sh` copies
  to the user's real files; Settings edits the copies, never the repo. Binds added to
  `binds.defaults.lua` reach existing `binds.lua` files through `tools/merge-binds.mjs` (link.sh).
- `system/`: root-owned files (pkexec helpers, polkit actions, ly's scripts, systemd
  configs) that install.sh's `put` copies to the same path under `/`.
- `qs/DESIGN.md`: the UI design reference. Read the section you need (grep its `##`
  headings) before UI work, not the whole file.
- `TODO.md`: the to-do list. "Add to the to-do" means a new numbered item there; tick
  items off by removing them once done.

## Checks

The pre-commit hook runs these when relevant files are staged; run them before committing:

- `python3 tools/check-unused.py`: anything declared and never read fails.
- `python3 tools/check-settings-index.py`: Settings fields vs the search index.
- `node --test tools/test-js.mjs`: plain-JS modules and the Hyprland Lua readers/writers.
- `tools/check-hardware.sh`: `packages/hardware/*.txt` against `hardware.sh`'s capabilities.

## Laptop, desktop and hardware

Anything only some machines can use is gated, never installed everywhere:

- On the hardware first: `hardware.sh`'s `has CAP` (sysfs checks, rerun by every
  `update.sh`). A package goes in `packages/hardware/CAP.txt` (repo or AUR), a
  fix or service in install.sh under `if has CAP`. New hardware: add a case to
  `has()` and its name to `hw_caps`.
- On the machine type (`laptop`/`desktop`, `if (( laptop ))`, `packages/desktop.txt`)
  only for a choice about use (hibernation, CoolerControl, idle timings).
- In the shell, a feature hides itself when its hardware or tool is missing
  (`Battery.present`, `Brightness.available`, `CommandProbe`), like the lid rows.

## Running and testing

- `qs log` for errors (keeps old ones from earlier reloads; check order).
  `qs ipc show` lists IPC targets.
- To open a flyout for a screenshot, add a temp `IpcHandler` inside `screenScope` in
  `shell.qml` calling `screenScope.toggleFlyout(name, screenScope.barWindow.widgetItem(name))`,
  then `grim`. Remove it before committing.

## Conventions

- Sizes and colours come from `Theme`; reuse the shared components.
- Comments describe the code as it is, briefly. History and reasons go in commit messages.
- Commit messages: `Area: what changed, in plain words`.
