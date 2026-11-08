# Singularity - shell aliases
# ~/.bash_aliases
#
# Sourced by ~/.bashrc. Settings > Terminal lists, adds and removes the
# aliases here. link.sh copies the repo's default
# (~/.config/singularity/bash_aliases.defaults.sh) only where there's none
# yet, so this file is this machine's own and never shows up in the repo.

alias ls='ls -A --color=auto'
alias grep='grep --color=auto'
alias vim='nvim'
alias vi='nvim'
alias nbash='nvim ~/.bashrc.local && source ~/.bashrc'
alias ff='clear && fastfetch'
alias singularity='cd ~/Singularity && claude'
alias clean='~/.config/singularity/clean.sh'
