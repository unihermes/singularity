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
- `qs/bar/`: `Bar.qml` (window, `widgetItem(key)`), `BarModules.qml` (every module).
- `qs/flyouts/`: `FlyoutPanel.qml` (shared flyout shell: padding, position, grown mode),
  `PanelFrame.qml`, `SectionRuns.qml` (section frames), shared rows/controls
  (`FlyoutRow`, `FlyoutHeading`, `FlyoutSegmented`, ...), one `*Flyout.qml` per module,
  `ControlCentre.qml`.
- `qs/settings/`: `SettingsPage*.qml` (one per page), `appearance/` (Appearance tabs).
  Search index is `services/SettingsIndex.js`; keep it in step with the pages.
- `qs/windows/`: Settings, System, Keybinds, Notes windows.
- `dotfiles/hypr/.config/hypr/`: `hyprland.lua` requires `shared`, `displays`, `env`,
  `autostart`, `looks`, `input`, `overrides`, `binds`, `alttab`, `windows` (which requires
  `window-rules` for the static rules and `window-keys` for the arrow keys).
- `dotfiles/singularity/.config/singularity/*.defaults.*`: templates `link.sh` copies
  to the user's real files; Settings edits the copies, never the repo.
- `qs/DESIGN.md`: the UI design reference. Read the section you need (grep its `##`
  headings) before UI work, not the whole file.

## Checks

The pre-commit hook runs these when relevant files are staged; run them before committing:

- `python3 tools/check-unused.py`: anything declared and never read fails.
- `python3 tools/check-settings-index.py`: Settings fields vs the search index.
- `node --test tools/test-js.mjs`: plain-JS modules and the Hyprland Lua readers/writers.

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
