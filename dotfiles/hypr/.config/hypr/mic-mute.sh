#!/bin/bash
# Singularity - mic mute
# ~/.config/hypr/mic-mute.sh
#
# The mic-mute key: flips the default mic and sets every other mic to match,
# so the keyboard's mute light (tied to the built-in mic) always agrees.

if pactl get-source-mute @DEFAULT_SOURCE@ | grep -q yes; then m=0; else m=1; fi
pactl list short sources | awk '$2 !~ /\.monitor$/ { print $2 }' | while read -r s; do
    pactl set-source-mute "$s" "$m"
done
