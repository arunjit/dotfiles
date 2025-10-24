# Setup PATH
set -x PATH /opt/homebrew/opt/rustup/bin /opt/homebrew/bin $HOME/.cargo/bin $HOME/Developer/bin $PATH

fish_add_path /opt/homebrew/bin

# Setup terminal, and turn on colors
# set -xU TERM xterm-256color
set -xU CLICOLOR 1

set -xU EZA_CONFIG_DIR $HOME/.config/eza

fzf --fish | source
jj util completion fish | source
starship init fish | source
zoxide init fish | source

set -xU FZF_CTRL_T_OPTS "--preview 'bat -n --color=always --line-range=:500 {}'"
set -xU FZF_ALT_C_OPTS "--preview 'eza --tree --color=always {} | head -200'"
set -xU FZF_DEFAULT_OPTS "\
--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 \
--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
--color=selected-bg:#45475A \
--color=border:#6C7086,label:#CDD6F4"
