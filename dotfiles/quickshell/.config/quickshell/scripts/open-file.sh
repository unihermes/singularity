#!/bin/bash
# Singularity - open a file the way the desktop should
# ~/.config/quickshell/scripts/open-file.sh
#
# Used by the launcher's file-search mode (services/Files.qml). Plain
# `xdg-open` silently does nothing for a good half of what a file search
# turns up on this machine, in two separate ways:
#
#   - No handler at all. `xdg-mime query default text/markdown` and
#     text/x-shellscript are both empty here, so xdg-open exits 0 having
#     done nothing at all -- the file search looked broken because of it.
#   - A handler that wants a terminal. text/plain maps to nvim.desktop,
#     which is Terminal=true, and launching those needs xdg-terminal-exec,
#     which isn't installed (and isn't in the repo's package list). xdg-open
#     again does nothing.
#
# So: honour the configured handler when it can actually be launched, run
# terminal handlers in a terminal, fall back to the editor for anything
# text-shaped, and otherwise open the containing folder, which at least puts
# the file in front of you with Thunar's own "Open With" a right-click away.
#
#   open-file.sh <path>
set -u

term=alacritty
editor=nvim
filemanager=thunar

f=${1:-}
[[ -n $f ]] || { echo "usage: open-file.sh <path>" >&2; exit 2; }
[[ -e $f ]] || { echo "no such file: $f" >&2; exit 1; }

# a directory is its own answer
if [[ -d $f ]]; then
    exec "$filemanager" "$f"
fi

edit() { exec "$term" -e "$editor" "$f"; }
reveal() { exec "$filemanager" "$(dirname -- "$f")"; }

type=$(xdg-mime query filetype "$f" 2>/dev/null | head -1)
type=${type%%;*}
handler=$(xdg-mime query default "$type" 2>/dev/null | head -1)

if [[ -n $handler ]]; then
    # Find the .desktop file the handler names, to see whether it needs a
    # terminal. Only the standard search path, and only the first hit,
    # which is what xdg-open itself would use.
    desktop=""
    IFS=: read -ra dirs <<< "${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    for d in "${dirs[@]}"; do
        [[ -r "$d/applications/$handler" ]] && { desktop="$d/applications/$handler"; break; }
    done

    if [[ -n $desktop ]] && grep -qix 'Terminal=true' "$desktop"; then
        # Exec= with its field codes (%f, %U, ...) stripped: they are
        # placeholders for the file, which is passed as an argument anyway.
        exec_line=$(grep -m1 '^Exec=' "$desktop" | cut -d= -f2- | sed -E 's/%[fFuUdDnNickvm]//g')
        [[ -n $exec_line ]] && exec "$term" -e bash -c "$exec_line \"\$1\"" _ "$f"
        edit
    fi
    # a normal graphical handler: let xdg-open do its job
    exec xdg-open "$f"
fi

# No handler. Anything that is text opens in the editor; the rest is handed
# to the file manager rather than guessed at.
case $type in
    text/*|application/json|application/xml|application/javascript|application/x-shellscript|inode/x-empty)
        edit ;;
    *)
        reveal ;;
esac
