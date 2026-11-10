# State and cache migration

`Paths.qml` uses `${XDG_STATE_HOME:-$HOME/.local/state}/singularity` for
settings, notes, saved sessions and generated application config, and
`${XDG_CACHE_HOME:-$HOME/.cache}/singularity` for disposable results and images.
Python and shell helpers use the same fallbacks, including empty variables.

`state-paths.py` runs from link.sh, before compositor autostart readers, and
before starting the AI host. After changing XDG variables, run
`python3 ~/.config/singularity/state-paths.py` before launching the shell by
hand. Stop the shell and AI host first when changing these variables.
The migration copies missing files; existing destination files win. It preserves
permissions and symlinks, keeps the original directory as a sibling
`singularity.before-xdg-*` backup, and installs a compatibility link at the old
path. Repeated launches are idempotent and migrations are serialized. Backups
are never automatically deleted; recover a conflicting file from the backup
manually with the shell stopped.

Generated app configs can keep their legacy include paths through those links.
The Chat tab deliberately keeps `$HOME/.cache/singularity/ai/chat` as its cwd
identity: Claude indexes history by the spelling of this path and Codex stores
it in threads. The compatibility link follows cache relocation, while provider
history stays in the providers' own stores (`~/.claude` and `~/.codex`). No
provider history is rewritten or deleted. Preserve the Chat working files when
clearing caches. Code conversations retain their project cwd.
