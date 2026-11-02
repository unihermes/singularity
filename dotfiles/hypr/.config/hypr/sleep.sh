#!/bin/bash
# Session sleep hooks. Lid policy belongs only to machines with a lid;
# desktops restore DPMS without laptop timers or monitor-rule rewrites.
case ${1:-} in
    sleep|resume) ;;
    *) echo 'usage: sleep.sh sleep|resume' >&2; exit 2 ;;
esac

source "$HOME/.config/singularity/platform.sh"
if feature lid; then
    exec "${BASH_SOURCE[0]%/*}/lid.sh" "$1"
fi

if [[ $1 == resume ]]; then
    hyprctl eval 'hl.dispatch(hl.dsp.dpms({ action = "on" }))' >/dev/null
fi
