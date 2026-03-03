export EDITOR="nvim"
export VISUAL="nvim"
export BROWSER="firefox"

export PATH="$HOME/.local/bin:$PATH"

autoload -Uz compinit
compinit

setopt autocd
setopt hist_ignore_dups
setopt share_history

HISTSIZE=10000
SAVEHIST=10000
HISTFILE="$HOME/.zsh_history"

alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate --all'
alias v='nvim'

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
