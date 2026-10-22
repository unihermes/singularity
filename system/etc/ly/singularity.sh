#!/bin/sh
# Installed by singularity's install.sh. Run by ly (start_cmd) before it takes
# the TTY: keeps the greeter off held-off monitors (outputs.sh) and loads the
# Singularity ramp into the VT palette, slots 0-15.
/etc/ly/outputs.sh
[ "$TERM" = linux ] || exit 0
i=0
for c in 0b0b0b a87676 7d9b7d 969696 a0a0a0 aeaeae b8b8b8 d0e2fa \
         303030 a87676 7d9b7d adadad b8b8b8 c8c8c8 d8d8d8 ebebeb; do
  printf '\033]P%x%s' "$i" "$c"
  i=$((i + 1))
done
# repaint with the new slot 0, or the old black shows through until ly draws
clear
