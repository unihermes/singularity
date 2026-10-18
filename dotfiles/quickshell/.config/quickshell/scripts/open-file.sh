#!/bin/bash
# Singularity - open a file the way the desktop should
# ~/.config/quickshell/scripts/open-file.sh
#
# For the launcher's file search: xdg-open silently does nothing for files
# with no handler (markdown, shell scripts) or a terminal one (nvim, without
# xdg-terminal-exec). So: the configured handler if it can launch, terminal
# handlers in a terminal, the editor for text, else the containing folder.
#   open-file.sh <path>
set -u

term=~/.config/singularity/terminal.sh
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
    # the handler's .desktop (first hit on the standard path, as xdg-open),
    # to see whether it needs a terminal
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
