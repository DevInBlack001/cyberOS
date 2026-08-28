# CyberOS zsh
PS1='\[\e[38;2;255;203;6m\]\u\[\e[0m\]@\[\e[38;2;61;187;110m\]\h\[\e[0m\] \w ❯ '
alias ls='ls --color=auto' ll='ls -lah' grep='grep --color=auto'
alias vim='nvim' vi='nvim'
export EDITOR=nvim VISUAL=nvim
[[ -z "$TMUX" ]] && [[ -z "$SSH_CONNECTION" ]] && command -v fastfetch >/dev/null && fastfetch
