# Setup PATH
set -x PATH /opt/homebrew/bin $HOME/.cargo/bin $HOME/Developer/bin $PATH

# Setup terminal, and turn on colors
# set -xU TERM xterm-256color
set -xU CLICOLOR 1

set -xU EZA_CONFIG_DIR $HOME/.config/eza

starship init fish | source
zoxide init fish | source
fzf --fish | source
jj util completion fish | source
