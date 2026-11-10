# Checks

The pre-commit hook runs these when relevant files are staged; run them before committing:

- `python3 tools/check-unused.py`: anything declared and never read fails.
- `python3 tools/check-settings-index.py`: Settings fields vs the search index.
- `node --test tools/test-processes.mjs`: write queue and AI lifecycle ordering;
  includes an isolated native QML smoke test when `qs` is installed.
- `node --test tools/test-settings.mjs`: settings public setters and stored-value repair.
- `node --test tools/test-js.mjs`: plain-JS modules, Hyprland Lua readers/writers,
  and window geometry/commands in an isolated Lua harness (requires `lua`).
- `tools/check-hardware.sh`: `packages/hardware/*.txt` against `scripts/hardware.sh`'s capabilities.
- `python3 tools/test-state-paths.py`: XDG migration, conflicts and compatibility paths.
- `python3 tools/test-tools.py`: compact inventory, syntax detection and pre-commit check selection.
- `python3 tools/check-syntax.py [files...]`: shell (including extensionless helpers), Python and Lua syntax.
- `python3 tools/test-ai-host.py`: independent sidebar host startup and command routing.
- `node --test tools/test-notification-routing.mjs`: sidebar and desktop notification routing.
- `python3 tools/test-ollama-agent.py`: the Ollama proxy's request adaptation and empty-reply retries.
- `python3 tools/test-ollama-status.py`: model capability discovery and GPU offload reporting.

