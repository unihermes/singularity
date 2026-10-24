#!/usr/bin/env bash
# Singularity - Quickshell
# ~/.config/quickshell/scripts/ai-desktop.sh
#
# The staging copy behind the Claude sidebar's Desktop tab (services/Ai.qml).
#
# Claude never edits the live repo (a QML write would hot-reload the shell
# mid-run): it works in a staging copy snapshotted with its own throwaway
# git dir, and nothing lands until the diff is applied. appearance.json
# rides along under .live/ and is merged back per key, so a setting changed
# meanwhile isn't reverted.
#
#   ai-desktop.sh start      fresh staging copy; prints its path
#   ai-desktop.sh diff       staged changes as a unified diff; exits 3 with
#                            no staging copy
#   ai-desktop.sh apply      patch the real repo, then discard
#   ai-desktop.sh discard    drop the staging copy
#
# SINGULARITY_SETTINGS is the path of appearance.json; the service passes it.

set -uo pipefail

state="${XDG_CACHE_HOME:-$HOME/.cache}/singularity/ai-desktop"
work="$state/work"
snap="$state/snap.git"
settings="${SINGULARITY_SETTINGS:-}"

repo=$(git -C "$(dirname "$(readlink -f "$HOME/.config/quickshell/shell.qml")")" \
    rev-parse --show-toplevel 2>/dev/null) || { echo "singularity repo not found" >&2; exit 1; }

g() { git --git-dir="$snap" --work-tree="$work" "$@"; }

snapshot() {
    g add -A >/dev/null 2>&1
    g write-tree
}

start() {
    rm -rf "$state"
    mkdir -p "$work"
    # tracked + untracked-but-not-ignored: what the repo actually holds,
    # without its .git or the build artifacts .gitignore keeps out
    git -C "$repo" ls-files -z -co --exclude-standard \
        | tar -C "$repo" --null --ignore-failed-read -T - -cf - 2>/dev/null \
        | tar -C "$work" -xf -
    if [ -n "$settings" ] && [ -f "$settings" ]; then
        mkdir -p "$work/.live"
        cp "$settings" "$work/.live/appearance.json"
    fi
    git init -q --bare "$snap"
    snapshot > "$state/base"
}

# merged per key (a line patch would clash with UI changes); only the keys
# Claude touched
merge_settings() {
    python3 - "$@" <<'EOF'
import json, sys
base, staged, live = (json.load(open(p)) for p in sys.argv[1:4])
for k in set(base) | set(staged):
    if base.get(k, KeyError) == staged.get(k, KeyError):
        continue
    if k in staged:
        live[k] = staged[k]
    else:
        live.pop(k, None)
print(json.dumps(live, indent=4, sort_keys=True))
EOF
}

notify() { notify-send -a "Claude" -i dialog-information "$@" 2>/dev/null || true; }

case "${1:-}" in
    start)
        start
        echo "$work"
        ;;

    diff)
        [ -f "$state/base" ] || exit 3
        cur=$(snapshot)
        g diff --no-color --no-ext-diff "$(cat "$state/base")" "$cur"
        ;;

    apply)
        [ -f "$state/base" ] || exit 0
        base=$(cat "$state/base"); cur=$(snapshot)
        patch=$(g diff --binary --no-ext-diff "$base" "$cur" -- . ':!.live')
        live=$(g diff --binary --no-ext-diff "$base" "$cur" -- .live/appearance.json)
        if [ -z "$patch$live" ]; then
            notify "Nothing to apply"; rm -rf "$state"; exit 0
        fi
        # both checked before either is written, so a failure leaves
        # everything as it was rather than half-applied
        if [ -n "$patch" ] && ! printf '%s\n' "$patch" | git -C "$repo" apply --check 2>"$state/err"; then
            notify -u critical "Couldn't apply Claude's changes" "$(head -c 300 "$state/err")"
            exit 1
        fi
        if [ -n "$live" ]; then
            g show "$base:.live/appearance.json" > "$state/settings.base"
            if ! merge_settings "$state/settings.base" "$work/.live/appearance.json" \
                    "$settings" > "$state/settings.new" 2>"$state/err"; then
                notify -u critical "Couldn't apply Claude's settings change" "$(head -c 300 "$state/err")"
                exit 1
            fi
        fi
        [ -n "$patch" ] && printf '%s\n' "$patch" | git -C "$repo" apply
        # a rename, so the shell's watcher never reads a half-written file
        [ -n "$live" ] && cp "$state/settings.new" "$settings.claude-tmp" && mv "$settings.claude-tmp" "$settings"
        n=$(g diff --name-only "$base" "$cur" | wc -l)
        notify "Claude's changes applied" "$n file(s) changed. Revert with git in $repo."
        rm -rf "$state"
        ;;

    discard)
        rm -rf "$state"
        ;;

    *)
        sed -n '/^#   ai-desktop/p' "$0" >&2
        exit 2
        ;;
esac
