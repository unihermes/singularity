#
# ~/.bashrc
#
# The LazyVim setup in ~/.config/nvim is the editor for everything that
# asks for one (git commit, sudoedit, crontab -e, less's `v`). Set before
# the guard so non-interactive shells pick it up too; it prints nothing.
export EDITOR=nvim
export VISUAL=nvim
export SUDO_EDITOR=nvim

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Below the interactive guard on purpose: bash sources this file for some
# non-interactive shells too (notably `ssh host command`), and anything that
# writes to stdout there corrupts the stream -- scp and rsync fail with
# "protocol error" when a greeting turns up in the middle of their transfer.
#
# fastfetch and starship use Quickshell's copies of their configs in the
# current look's colours (AppearanceSync.qml) when those exist.
look_state=~/.local/state/neutrino
fastfetch() {
  if [[ -r $look_state/fastfetch.jsonc ]]; then
    command fastfetch -c "$look_state/fastfetch.jsonc" "$@"
  else
    command fastfetch "$@"
  fi
}
[[ -r $look_state/starship.toml ]] && export STARSHIP_CONFIG=$look_state/starship.toml
fastfetch

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias vim='nvim'
alias vi='nvim'

eval "$(starship init bash)"

# unihermes edits
alias nbash='nvim ~/.bashrc && source ~/.bashrc'
alias ff='clear && fastfetch'
alias clean='~/.config/singularity/clean.sh'
alias diagnose='~/.config/singularity/diagnose.sh'
alias singularity='cd ~/Git/singularity/ && claude'
