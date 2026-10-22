#!/usr/bin/env bash
# The package lists against hardware.sh: every packages/hardware/CAP.txt
# names a capability `has` knows, every capability in hw_caps is one, and
# no package sits in two lists (it would install where it shouldn't).
set -uo pipefail
cd "$(dirname "$0")/.."

source ./hardware.sh
list() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$1"; }

bad=0
for cap in "${hw_caps[@]}"; do
  has "$cap" >/dev/null 2>&1
  if (( $? == 2 )); then
    echo "hw_caps lists '$cap', which has() doesn't answer"
    bad=1
  fi
done
for f in packages/hardware/*.txt; do
  cap=${f##*/}; cap=${cap%.txt}
  if [[ " ${hw_caps[*]} " != *" $cap "* ]]; then
    echo "$f: no capability '$cap' in hardware.sh's hw_caps"
    bad=1
  fi
done

declare -A seen
for f in packages/*.txt packages/hardware/*.txt; do
  while read -r p; do
    if [[ -n ${seen[$p]:-} ]]; then
      echo "$p is in both ${seen[$p]} and $f"
      bad=1
    fi
    seen[$p]=$f
  done < <(list "$f")
done

exit "$bad"
