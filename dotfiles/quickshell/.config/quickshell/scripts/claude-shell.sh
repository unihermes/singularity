#!/usr/bin/env bash
# Singularity - Quickshell
# ~/.config/quickshell/scripts/claude-shell.sh
#
# The plumbing behind the bar's Claude module (services/ClaudeShell.qml).
#
# Claude never edits the live repo. Everything in ~/.config is a stow symlink
# into it, and Quickshell and Hyprland hot-reload on write -- an edit to a QML
# file mid-run would reload the shell and kill the very process doing the
# editing. So each session works on a staging copy, and nothing reaches the
# real files until the diff has been looked at and applied.
#
# The copy is snapshotted with its own throwaway git dir and index rather
# than the repo's: the repo's working tree is usually dirty and has untracked
# files, and the diff has to be against exactly what was copied, not HEAD.
#
# The shell's own settings (appearance.json, outside the repo) ride along
# under .live/ so "make the bar thinner" can be answered too. They're merged
# back key by key on apply, not copied over, so a setting changed from the UI
# while Claude worked isn't reverted.
#
#   claude-shell.sh start              fresh staging copy
#   claude-shell.sh run PROMPT [ID]    stream-json on stdout; ID resumes
#   claude-shell.sh diff               staged changes as a unified diff
#   claude-shell.sh apply              patch the real repo, then discard
#   claude-shell.sh discard            drop the staging copy
#
# SINGULARITY_SETTINGS is the path of appearance.json; the service passes it.

set -uo pipefail

state="${XDG_CACHE_HOME:-$HOME/.cache}/singularity/claude-shell"
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

# Settings are merged per key, not patched: the file is small enough that a
# line patch's context almost always overlaps a setting changed from the UI
# in the meantime. Only the keys Claude touched are carried over.
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
        ;;

    run)
        prompt="${2:?prompt}"; session="${3:-}"
        [ -f "$state/base" ] || start
        cd "$work" || exit 1
        extra=()
        [ -n "$session" ] && extra=(--resume "$session")
        exec claude -p "$prompt" "${extra[@]}" \
            --output-format stream-json --verbose \
            --permission-mode acceptEdits \
            --tools "Read,Edit,Write,Glob,Grep" \
            --strict-mcp-config \
            --append-system-prompt "You were invoked from the Claude module in the user's Singularity bar. \
The working directory is a staging copy of their Singularity repo: an Arch Linux + Hyprland + Quickshell \
desktop whose dotfiles live under dotfiles/<app>/ and are symlinked into \$HOME with GNU stow \
(dotfiles/quickshell/.config/quickshell is ~/.config/quickshell, and so on). \
.live/appearance.json is the shell's live settings file (bar height, radius, fonts, look, widget layout); \
edit it for requests about those rather than changing defaults in code. \
Your edits are not live yet: the user reviews the diff and applies it, and then Quickshell and Hyprland \
hot-reload. You cannot run commands. Make focused, minimal edits that match the surrounding code's style \
and comment density. End with one to three plain sentences (no markdown, no code) saying what you \
changed; the diff is shown separately. If the request is only a question, just answer it."
        ;;

    diff)
        [ -f "$state/base" ] || exit 0
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
        sed -n '/^#   claude-shell/p' "$0" >&2
        exit 2
        ;;
esac
