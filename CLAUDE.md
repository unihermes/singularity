# Singularity

Arch + Hyprland (Lua config) + a Quickshell (QML) shell. `dotfiles/<pkg>/` mirrors `$HOME`
and is symlinked in, so `~/.config/quickshell` *is* `dotfiles/quickshell/.config/quickshell`
(called `qs/` below). Saving a QML file hot-reloads the running shell.

For compact discovery, run `python3 tools/context.py [path]`: directories show
file counts/sizes; files show imports and declarations with line numbers. Paths
accept `qs/` and `hypr/` aliases. Read relevant ranges instead of entire modules.
Use `--match function` to skip properties in large QML outlines, or any regex to
filter names. Markdown files show headings (e.g. `qs/DESIGN.md --match controls`).

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
  (which requires `window-rules` for the static rules and `window-keys` for the arrow keys).
- `dotfiles/singularity/.config/singularity/*.defaults.*`: templates `link.sh` copies
  to the user's real files; Settings edits the copies, never the repo. Binds added to
  `binds.defaults.lua` reach existing `binds.lua` files through `tools/merge-binds.mjs` (link.sh).
- `system/`: root-owned files (pkexec helpers, polkit actions, ly's scripts, systemd
  configs) that install.sh's `put` copies to the same path under `/`.
- `qs/DESIGN.md`: the UI design reference. Read the section you need (grep its `##`
  headings) before UI work, not the whole file.
- `TODO.md`: the to-do list, created when needed. "Add to the to-do" means a new
  numbered item there; remove completed items and delete the file when it is empty.

## Checks

The pre-commit hook runs these when relevant files are staged; run them before committing:

- `python3 tools/check-unused.py`: anything declared and never read fails.
- `python3 tools/check-settings-index.py`: Settings fields vs the search index.
- `node --test tools/test-js.mjs`: plain-JS modules and the Hyprland Lua readers/writers.
- `tools/check-hardware.sh`: `packages/hardware/*.txt` against `scripts/hardware.sh`'s capabilities.
- `python3 tools/test-tools.py`: compact inventory, syntax detection and pre-commit check selection.
- `python3 tools/check-syntax.py [files...]`: shell (including extensionless helpers), Python and Lua syntax.

## Laptop, desktop and hardware

- `dotfiles/singularity/.config/singularity/platform.sh` is the single detector
  (`has CAP`) and policy resolver (`feature NAME`). Its `profiles/laptop.conf`
  and `profiles/desktop.conf` select usage policies; hardware gates still apply.
- `scripts/hardware.sh` sources that resolver and adds provisioning helpers. First
  interactive install offers the detected choice; explicit laptop/desktop,
  saved choice, then detection supply it elsewhere. `--plan` is read-only.
  Install, link and update must use `select_machine`, never duplicate detection.
- Hardware packages go in `packages/hardware/CAP.txt`; policy packages in
  `packages/laptop.txt` or `packages/desktop.txt`. Hardware fixes use `has`;
  hibernation setup, cooling and other usage policies use `feature`.
- QML uses `Platform.has()` and `Platform.allows()` (fail closed until loaded).
  Hyprland uses `shared.has/allows`; `platform.lua` gates device configuration,
  including saved overrides. Keep settings visibility and search gates aligned.
- Shared files can be linked everywhere; unsupported code must not activate.
  A desktop may have an external touchpad; a laptop may lack a lid or backlight.
- `python3 tools/test-platform.py` checks profile selection, package selection,
  hardware/policy combinations, preview side effects and compositor gates.

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
