#!/usr/bin/env bash
# Builds the extension and sideloads it into the default Floorp and Zen
# profiles on this Linux machine; each browser picks it up on its next start.
# Elsewhere (Windows included), install the .xpi by hand: see README.md.
set -euo pipefail
cd "$(dirname "$0")"
id=$(python3 -c 'import json; print(json.load(open("manifest.json"))["browser_specific_settings"]["gecko"]["id"])')
xpi=$(./build.sh)

# The profile a browser starts with: its install's Default=, else the
# profile marked Default=1.
default_profile() {
    local base=$1 path=""
    if [[ -f $base/installs.ini ]]; then
        path=$(sed -n 's/^Default=//p' "$base/installs.ini" | head -n1)
    fi
    if [[ -z $path && -f $base/profiles.ini ]]; then
        path=$(awk -F= '/^\[/{p=""} /^Path=/{p=$2} /^Default=1/{if(p){print p; exit}}' "$base/profiles.ini")
    fi
    [[ -n $path ]] && printf '%s/%s\n' "$base" "$path"
}

# Unsigned add-ons need signing turned off, and profile sideloads start
# disabled unless the profile scope (1) is left out of autoDisableScopes.
# Floorp's user.js is built from the repo, which already sets both.
ensure_prefs() {
    local userjs=$1/user.js
    touch "$userjs"
    grep -q '"xpinstall.signatures.required"' "$userjs" ||
        echo 'user_pref("xpinstall.signatures.required", false);' >>"$userjs"
    grep -q '"extensions.autoDisableScopes"' "$userjs" ||
        echo 'user_pref("extensions.autoDisableScopes", 14);' >>"$userjs"
}

for base in "$HOME/.config/floorp" "$HOME/.config/zen"; do
    profile=$(default_profile "$base") || continue
    [[ -d $profile ]] || continue
    ensure_prefs "$profile"
    mkdir -p "$profile/extensions"
    # Renamed into place: a running browser keeps reading the old file
    cp "$xpi" "$profile/extensions/.$id.xpi.new"
    mv -f "$profile/extensions/.$id.xpi.new" "$profile/extensions/$id.xpi"
    echo "installed into $profile"
done
