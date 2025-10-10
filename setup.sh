#!/bin/sh
set -e

pushd "$(dirname "$0")" > /dev/null

which brew > /dev/null || (echo "Go install Homebrew (https://brew.sh)" && exit 1)
which fish > /dev/null || (echo "Go install Fish-shell (brew install fish)" && exit 1)
which git > /dev/null || (echo "Go install Git-SCM (brew install git)" && exit 1)

set +x

brew install \
  bat eza fd fzf jj neovim starship stow zoxide \
  direnv gh jq jqp lua luajit ripgrep tlrc xq yazi yq

# Keep the .config dir explicit, so that it can hold untracked configs.
mkdir $HOME/.config

# Right now, all contents of config/ can be moved to the root of this dir.
# However, to keep the option of top-level dotfiles (e.g, ~/.foorc), everything
# that goes under ~/.config gets put under config.
stow config --target=$HOME/.config --dotfiles
# For example, for top-level dotfiles, put them under a new dir, e.g foo/dot-foorc:
# stow foo --target=$HOME --dotfiles

fish_config theme save "Catppuccin Mocha"
bat cache --build

mkdir -p $HOME/Developer/src
cd $HOME/Developer/src
git clone https://github.com/catppuccin/delta.git catppucin-delta
git clone https://github.com/junegunn/fzf-git.sh fzf-git
