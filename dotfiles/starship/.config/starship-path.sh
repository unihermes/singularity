#!/usr/bin/env bash
# Emits $PWD for starship's custom.path module: the parent folders on a grey
# capsule and the current folder as an accent pill on its end, the way the
# bar marks the active workspace. Starship's own `directory` module has one
# style for the whole path, so it can't draw the two parts differently.
#
# Colours and capsule shape come from term-colors.sh, which Quickshell
# (AppearanceSync.qml) writes for the current look: round caps when the look
# has a radius, square blocks at 0. Defaults are Singularity's.
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
