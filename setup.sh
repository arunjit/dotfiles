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

stow . --target=$HOME

fish_config theme save "Catppuccin Mocha"