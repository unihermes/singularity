#!/usr/bin/env bash
# Dolphin's per-folder views, written once per folder (never overwrites a
# view you've set yourself). Dolphin keeps each folder's view in
# ~/.local/share/dolphin/view_properties/local/<path>/.directory.
set -euo pipefail

root=$HOME/.local/share/dolphin/view_properties
cfg=$HOME/.config/dolphinrc

# per-folder views on, not one view for every folder
if command -v kwriteconfig6 &>/dev/null; then
  kwriteconfig6 --file "$cfg" --group General --key GlobalViewProps false
  kwriteconfig6 --file "$cfg" --group General --key RememberOpenedTabs false
  kwriteconfig6 --file "$cfg" --group General --key ShowFullPath true
  kwriteconfig6 --file "$cfg" --group General --key BrowseThroughArchives true
  kwriteconfig6 --file "$cfg" --group MainWindow --key MenuBar Disabled
fi

# view <dir> <mode: 0 icons|1 compact|2 details> <sort role> <order: 0 asc|1 desc> <previews> [roles]
view() {
  local dir=$1 file
  [[ $dir == global ]] && file=$root/global/.directory || file=$root/local$dir/.directory
  [[ -e $file ]] && grep -q '^ViewMode=' "$file" && return 0
  [[ $dir == global || -d $dir ]] || return 0
  mkdir -p "$(dirname "$file")"
  {
    printf '[Dolphin]\nTimestamp=%s\nVersion=4\n' "$(date +%Y,%m,%d,%H,%M,%S)"
    printf 'ViewMode=%s\nSortRole=%s\nSortOrder=%s\nPreviewsShown=%s\n' "$2" "$3" "$4" "$5"
    if [[ -n ${6:-} ]]; then printf 'VisibleRoles=%s\n' "$6"; fi
  } > "$file"
}

details=Details_text,Details_size,Details_modificationtime
view global                 2 text             0 false "$details"
view "$HOME"                1 text             0 false
view "$HOME/Downloads"      2 modificationtime 1 true  "$details"
view "$HOME/Documents"      2 text             0 false "$details,Details_type"
view "$HOME/Pictures"       0 modificationtime 1 true
view "$HOME/Videos"         0 modificationtime 1 true
view "$HOME/Music"          2 text             0 false "Details_text,Details_size,Details_modificationtime"
view "$HOME/Projects"       2 modificationtime 1 false "$details"
view "$HOME/Git"            2 text             0 false "$details"
