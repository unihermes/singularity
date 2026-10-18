#!/usr/bin/env bash
# $PWD for starship's custom.path: parent folders on a grey capsule, the
# current folder as an accent pill (starship's `directory` has one style).
# Colours and shape from term-colors.sh (AppearanceSync); defaults are
# Singularity's.
N_OVERLAY='36;36;36' N_SUBTEXT='122;122;122'
N_ACCENT='85;85;200' N_ON_ACCENT='235;235;235' T_ROUND=1
. "$HOME/.local/state/singularity/term-colors.sh" 2>/dev/null

GREY="48;2;$N_OVERLAY;38;2;$N_SUBTEXT"
PILL="1;48;2;$N_ACCENT;38;2;$N_ON_ACCENT"

p=${PWD/#"$HOME"/\~}
if [[ $p == / ]]; then
  parent="" last=/
elif [[ $p == */* ]]; then
  parent=${p%/*}/ last=${p##*/}
else
  parent="" last=$p
fi

out=""
if [[ -n $parent ]]; then
  (( T_ROUND )) && out+=$'\033[38;2;'"$N_OVERLAY"$'m'
  out+=$'\033['"$GREY"'m '"$parent"' '
  (( T_ROUND )) && out+=$'\033[38;2;'"$N_ACCENT"$'m'
elif (( T_ROUND )); then
  out+=$'\033[38;2;'"$N_ACCENT"$'m'
fi
out+=$'\033['"$PILL"'m '"$last"' '
if (( T_ROUND )); then
  out+=$'\033[0;38;2;'"$N_ACCENT"$'m'
fi
printf '%s\033[0m' "$out"
