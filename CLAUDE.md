# Singularity

Arch + Hyprland (Lua config) + a Quickshell (QML) shell. `dotfiles/<pkg>/` mirrors `$HOME`
and is symlinked in, so `~/.config/quickshell` *is* `dotfiles/quickshell/.config/quickshell`
(called `qs/` below). Saving a QML file hot-reloads the running shell.

For compact discovery, run `python3 tools/context.py [path]`: directories show
file counts/sizes; files show imports and declarations with line numbers. Paths
accept `qs/` and `hypr/` aliases. Read relevant ranges instead of entire modules.
Use `--match function` to skip properties in large QML outlines, or any regex to
filter names. Markdown files show headings (e.g. `qs/DESIGN.md --match controls`).
Use `--largest` on a directory to rank its files recursively by size.

## Where things are

- `qs/shell.qml`: entry point, IPC handlers, one `screenScope` per screen holding the
  open flyout (`toggleFlyout`, `openFlyout`).
- `qs/services/Paths.qml`: XDG state/cache roots, shared by persistent services.
- `qs/services/Theme.qml`: every size/colour token (`spaceXs..Xl`, `sp()`, `flyoutOffset`,
  `channelWidth`). `Settings.qml`: persisted settings (`~/.local/state/singularity/appearance.json`).
  `Looks.js` / `Styles.js`: looks and styles.
- `qs/bar/`: `Bar.qml` (window, `widgetItem(key)`), `BarModules.qml` (every module; the big ones in
  `WorkspacesModule`, `WindowsModule`, `TrayModule`).
- `qs/flyouts/`: `FlyoutPanel.qml` (shared flyout shell: padding, position, grown mode),
  `PanelFrame.qml`, `SectionRuns.qml` (section frames), shared rows/controls
  (`FlyoutRow`, `FlyoutHeading`, `FlyoutSegmented`, ...), one `*Flyout.qml` per module,
  `ControlCentre.qml`.
- `qs/launcher/`: `Launcher.qml` (modes, results, Enter) and one `Launcher*.qml` per layout,
  sharing `LauncherField`, `LauncherRow`, `LauncherTile`; Mosaic packing in `services/Mosaic.js`.
- `qs/settings/`: `SettingsPage*.qml` (one per page), `appearance/` (Appearance tabs).
  Search index is `services/SettingsIndex.js`; keep it in step with the pages.
  Keybind filtering/grouping is in `services/KeybindGroups.js`; the editor is `KeybindsBody.qml`.
- `qs/windows/`: Settings, System, Keybinds, Notes windows.
- `qs/desktop/`: the desktop widgets (straight on the wallpaper, one surface each under the windows), their edit mode
  and the desktop's right-click menu;
  placement maths in `services/WidgetPlacement.js`.
- `qs/AiHost.qml`: independent sidebar process, started by `scripts/ai_host.py`;
  file watching is disabled so shell edits do not interrupt chat. Restart this
  host explicitly to apply sidebar code changes after its active turns finish.
- `qs/sidebar/`: the Claude sidebar (SUPER+I), driven by `services/Ai.qml` and
  `ClaudeSession.qml` (`claude -p` over stream-json); helpers in `scripts/ai.py`.
  `CodexSession.qml` handles Codex; both inherit state/transcript helpers from `AiSession.qml`.
- `dotfiles/hypr/.config/hypr/`: `hyprland.lua` requires `shared`, `platform`, `displays`, `env`,
  `autostart`, `looks`, `input`, `overrides`, `game-keys`, `binds`, `alttab`, `windows`
  (which requires `window-rules` for static rules, `window-keys` for arrow keys,
  and `window-geometry` for pure sizing and placement maths).
- `dotfiles/singularity/.config/singularity/*.defaults.*`: templates `link.sh` copies
  to the user's real files; Settings edits the copies, never the repo. Binds added to
  `binds.defaults.lua` reach existing `binds.lua` files through `tools/merge-binds.mjs` (link.sh).
- `system/`: root-owned files (pkexec helpers, polkit actions, ly's scripts, systemd
  configs) that install.sh's `put` copies to the same path under `/`.
- `packages/gaming/`: the `gaming` policy's lists (base.txt, then one per GPU capability).
- `qs/DESIGN.md`: the UI design reference. Read the section you need (grep its `##`
  headings) before UI work, not the whole file.
- `TODO.md`: the to-do list. "Add to the to-do" means a new numbered item there;
  remove completed items and keep the file when it is empty.

## Reference docs (read only when relevant)

- `docs/CHECKS.md`: every check/test command. The pre-commit hook runs the relevant ones; run `python3 tools/check-syntax.py` plus the check for what you touched.
- `docs/HARDWARE.md`: laptop/desktop profiles, `has`/`feature`/`Platform.has()` gating. Read before touching device or policy code.
- `docs/STATE-MIGRATION.md`: XDG state/cache paths and migration. Read before changing `Paths.qml` or state locations.

## Running and testing

- `python3 tools/test-sidebar-focus.py`: live, not in pre-commit. Clicks the real pointer on its own test
  terminals on DP-2 to check where clicks leave the sidebar and the keyboard. Restart the AI host first.
- `qs log` for errors (keeps old ones from earlier reloads; check order).
  `qs ipc show` lists IPC targets.
- To open a flyout for a screenshot, add a temp `IpcHandler` inside `screenScope` in
  `shell.qml` calling `screenScope.toggleFlyout(name, screenScope.barWindow.widgetItem(name))`,
  then `grim`. Remove it before committing.

## Conventions

- Sizes and colours come from `Theme`; reuse the shared components.
- Comments describe the code as it is, briefly. History and reasons go in commit messages.
- Commit messages: `Area: what changed, in plain words`.

