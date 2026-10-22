# Singularity - helpers the scripts share
#
# Sourced by install.sh, update.sh and tools/check-hardware.sh.

log()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

# a package list without its comments and blank lines
list() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$1"; }
