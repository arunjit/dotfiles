#!/bin/sh
set -eu

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is not installed. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

echo "Updating Homebrew formulae..."
brew update

PACKAGES="
  bat
  direnv
  eza
  fd
  fish
  fzf
  gh
  git
  git-delta
  helix
  jj
  jq
  jqp
  lua
  luajit
  luarocks
  ripgrep
  starship
  stow
  tlrc
  xq
  yazi
  yq
  zoxide
"

echo "Installing Homebrew packages..."
# shellcheck disable=SC2086
brew install $PACKAGES

echo "macOS package installation completed."
