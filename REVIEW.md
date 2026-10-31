# Consistency and context-efficiency review — 2026-10-31

## Scope

Repository-wide inventory and static pattern checks covered 422 files, including
342 QML, JS, Python, shell and Lua source files. Targeted reads covered discovery
and validation tools, installation/hardware/linking, shared UI helpers, settings,
appearance generation, AI sessions/staging, and window management. This is an
architectural and maintenance review, not a line-by-line correctness audit or a
test of every desktop interaction. No model-token savings were measured; source
size and discovery output are proxies for the context needed to make an edit.

## Addressed

- **Missed pre-commit checks:** Appearance tabs and shared Settings components
  now trigger the settings-index check; checker edits trigger their own checks;
  hyphenated Hyprland Lua filenames trigger JS tests. Editing the hook runs all
  checks. The staged file list is read once, without `git | grep -q` pipelines
  whose early reader exit could produce SIGPIPE under `pipefail`.
- **CI drift:** hardware consistency and repository-tool tests now run in CI.
  README and CLAUDE check lists describe the same checks.
- **Unhelpful large outlines:** `tools/context.py --match REGEX` filters before
  limiting output. `qs/services/Settings.qml --match function` skips hundreds
  of property declarations. Markdown outlines expose DESIGN.md's sections
  without reading its 76 KB body. Invalid regexes produce a CLI error.
- **Duplicate helpers:** `link.sh` sources the existing logging functions in
  `lib.sh`; transcript and reload-error rendering use `Markdown.esc`.
- **Shared test-log path:** the hook uses a unique temporary file and prints
  complete failures before cleanup, avoiding concurrent commits overwriting
  each other's diagnostics.

- **Desktop staging:** the QML working directory now honors `XDG_CACHE_HOME`,
  matching the helper. Snapshot/apply/write failures stop the helper and retain
  staged work; preparation failures appear in the transcript. Six integration
  tests cover custom/default cache paths, merging, conflicts, and failed writes.

- **Syntax coverage:** one checker now parses shell, Python and Lua sources,
  including extensionless shebang scripts. Both CI and the pre-commit hook run
  it; tests verify malformed extensionless helpers are rejected.

## Remaining priorities

### 1. Align paths between processes before broad XDG support

The desktop staging mismatch is fixed. Broader path inconsistencies remain in
`Settings.qml`, `DiskCache.qml`, `Notes.qml`, the chat working directory, and
helpers that already honor XDG overrides. Define shared QML state/cache paths
with an explicit migration policy: changing defaults immediately could make
saved settings, notes or chat history appear to disappear. Keep repo-backed
config paths separate from user data.

### 2. Extract pure behavior from the largest modules

The strongest candidates by size and responsibility are:

| File (under qs unless stated) | Lines at review | Useful extraction boundary |
|---|---:|---|
| `hypr/windows.lua` | 2,049 | Saved window geometry and shape calculations |
| `settings/KeybindsBody.qml` | 1,504 | Selection/editor operations and row rendering |
| `services/Settings.qml` | 1,165 | Layout transformations and setting metadata |
| `services/AppearanceSync.qml` | 1,092 | Pure per-application text renderers |
| `services/SystemStats.qml` | 834 | Parsers independent of polling/process state |

Extract one boundary at a time and test its outputs first. Preserve the public
service/component API. In particular, do not split the event hooks in
`windows.lua` solely to hit a line-count target: callback order and shared state
are part of its behavior. Existing `KeybindGroups.js`, `HyprTables.js`, and
`WidgetPlacement.js` demonstrate useful pure-module boundaries.

### 3. Reduce settings metadata drift without hiding QML dependencies

`Settings.qml` carries aliases, choices, limits, defaults and a `JsonAdapter`;
pages and `SettingsIndex.js` repeat labels and navigation metadata. The existing
index checker is valuable, but only recognizes specific textual forms and
skips computed labels. Moving stable metadata into one small table would make
settings additions cheaper to review. Retain explicit QML properties/bindings;
first add checks that choices, bounds and defaults agree, then consider
deriving search entries for static fields. Avoid generating whole pages.

### 4. Expand behavioral checks where static scans give little assurance

`check-unused.py` counts names globally and removes `//` with a regex. Shared
names, strings and comments can mask unused declarations, and this is not
scope-aware analysis. Keep it as a lightweight heuristic, not proof that every
declaration is used. The settings-index check likewise depends on formatting.

The JS suite covers useful pure logic, but QML process lifecycles, config writes,
and Lua event behavior lack equivalent regression coverage. Prioritize queued
config writes and AI reset/resume transitions before consolidating them.
Shell/Python/Lua syntax checks now cover extensionless helpers too. These parse
checks do not replace behavioral tests.

### 5. Consolidate shared session state only after lifecycle tests

`ClaudeSession.qml` and `CodexSession.qml` already inherit `AiSession.qml`, but
repeat attachment labels, user-row creation and much of reset state. A shared
reset helper could prevent drift; protocol queues, process termination and
resume behavior must stay adapter-specific. Test stop/reset/resume with late
process output before moving state transitions into the base component.

## Keep

The existing shared flyout controls, Theme tokens, hardware capability gates,
AtomicFileWrite queue, and pure JS helpers are sound reuse boundaries. Preserve
them. The exact eight-line duplicate scan found no cross-file blocks above its
300-character threshold; that narrow result does not rule out shorter or
structurally similar duplication. Avoid blanket minification, removing useful
comments, or abstracting every similar QML row just to reduce source length.

## Validation

All seven project checks passed after the follow-up, including six repository-tool
tests and six staging integration tests. The three failure tests also reproduce
against the original staging script. Shell, Lua and Python syntax checks and
`git diff --check` passed. Earlier live-shell logs contained repeated tray D-Bus
warnings; these checks do not establish full interactive QML or hardware coverage.
