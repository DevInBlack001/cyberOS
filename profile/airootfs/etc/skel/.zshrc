# CyberOS zsh
autoload -Uz compinit promptinit colors && compinit && promptinit && colors
HISTFILE=~/.zsh_history; HISTSIZE=10000; SAVEHIST=10000
setopt share_history hist_ignore_dups autocd correct
bindkey -e
PROMPT='%F{white}%B%n%b%f@%F{#3DBB6E}%m%f %F{#7A8F82}%~%f %F{white}❯%f '
alias ls='ls --color=auto' ll='ls -lah' grep='grep --color=auto'
alias vim='nvim' vi='nvim'
export EDITOR=nvim VISUAL=nvim
[[ -o interactive ]] && [[ -z "$TMUX" ]] && [[ -z "$SSH_CONNECTION" ]] && command -v fastfetch >/dev/null && fastfetch
