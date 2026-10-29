#!/usr/bin/env bash
# The screen-share picker xdg-desktop-portal-hyprland runs (xdph.conf). A
# window discord-share.sh noted in the last few seconds is shared straight
# away; any other request gets hyprland-share-picker.
#
# XDPH_WINDOW_SHARING_LIST is each window as
# id[HC>]class[HT>]title[HE>]address[HA>], the address in decimal; the
# answer is [SELECTION]/window:id.
note="${XDG_RUNTIME_DIR:-/tmp}/singularity-share-window"

if [[ -s $note ]] && (( $(date +%s) - $(stat -c %Y "$note") <= 5 )); then
  want=$(<"$note")
  rm -f "$note"
  want=$((16#${want#0x}))
  list=${XDPH_WINDOW_SHARING_LIST:-}
  while [[ $list == *'[HA>]'* ]]; do
    entry=${list%%'[HA>]'*}
    list=${list#*'[HA>]'}
    address=${entry##*'[HE>]'}
    if [[ $address == "$want" ]]; then
      echo "[SELECTION]/window:${entry%%'[HC>]'*}"
      exit 0
    fi
  done
fi

exec hyprland-share-picker "$@"
