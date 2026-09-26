# One boxed row for config.jsonc:  . row.sh LABEL [VALUE]
#
# Sourced, not run: fastfetch finds the terminal by walking up the process
# tree, and a shell of its own between the two fastfetch processes makes the
# Terminal row report "fastfetch".
#
# With no VALUE, LABEL is also the fastfetch module to ask. The nested call
# runs with `-c none` so it doesn't load config.jsonc again and recurse. The
# value is right-padded so the closing border lands in the same column on
# every row -- fastfetch can't pad a module to a fixed width on its own.
#
# The box is 50 columns so logo and box together fit a half-screen terminal.
# Change it here and in config.jsonc (the title's dash count and the three
# divider and bottom lines) together.
N_MUTED='77;77;77' N_SUBTEXT='122;122;122'
. "$HOME/.local/state/singularity/term-colors.sh" 2>/dev/null
label=$1
if (( $# > 1 )); then
  v=$2
else
  v=$(fastfetch -c none -s "$label" --logo none --separator $'\x1f' 2>/dev/null)
  v=${v#*$'\x1f'}
fi
# vendor noise that costs width and says nothing
v=${v//(R)/}; v=${v//(TM)/}; v=${v/ \[Integrated\]/}
[[ $v =~ ^[0-9]+th\ Gen\ (.*) ]] && v=${BASH_REMATCH[1]}
max=$(( 50 - 5 - ${#label} ))
(( ${#v} > max )) && v="${v:0:max-1}…"
pad=$(( max - ${#v} )); (( pad < 0 )) && pad=0
printf '\033[38;2;%sm%s\033[0m %s%*s \033[38;2;%sm│\033[0m' "$N_SUBTEXT" "$label" "$v" "$pad" '' "$N_MUTED"
