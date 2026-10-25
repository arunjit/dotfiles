#!/bin/sh
set -eu

echo "Starting Linux / Debian / Raspberry Pi OS setup..."

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# Ensure ~/.local/bin is in PATH for current subshell
case ":$PATH:" in
  *:"$BIN_DIR":*) ;;
  *) PATH="$BIN_DIR:$PATH" ;;
esac

# 1. Install packages via apt if on Debian/Ubuntu/Raspberry Pi OS
if command -v apt-get >/dev/null 2>&1; then
  echo "Debian-based system detected. Updating apt packages..."
  SUDO=""
  if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  fi

  $SUDO apt-get update -y
  $SUDO apt-get install -y \
    build-essential \
    curl \
    file \
    git \
    fish \
    stow \
    fzf \
    ripgrep \
    jq \
    direnv \
    bat \
    fd-find \
    xclip \
    ca-certificates \
    tar \
    gzip \
    xz-utils

  # Link Debian specific binary names to standard names in ~/.local/bin
  if command -v batcat >/dev/null 2>&1 && [ ! -e "$BIN_DIR/bat" ]; then
    echo "Creating symlink $BIN_DIR/bat -> $(command -v batcat)"
    ln -sf "$(command -v batcat)" "$BIN_DIR/bat"
  fi

  if command -v fdfind >/dev/null 2>&1 && [ ! -e "$BIN_DIR/fd" ]; then
    echo "Creating symlink $BIN_DIR/fd -> $(command -v fdfind)"
    ln -sf "$(command -v fdfind)" "$BIN_DIR/fd"
  fi
fi

# 2. Install Starship
if ! command -v starship >/dev/null 2>&1; then
  echo "Installing Starship prompt..."
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$BIN_DIR"
fi

# 3. Install Zoxide
if ! command -v zoxide >/dev/null 2>&1; then
  echo "Installing Zoxide..."
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | BIN_DIR="$BIN_DIR" sh
fi

# 4. Architecture detection for standalone binaries
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)
    TARGET_ARCH="x86_64"
    ;;
  aarch64|arm64)
    TARGET_ARCH="aarch64"
    ;;
  armv7l|armhf)
    TARGET_ARCH="arm"
    ;;
  *)
    TARGET_ARCH=""
    ;;
esac

# Helper to fetch latest GitHub release tag
get_latest_release() {
  repo="$1"
  curl -s "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | \
    grep '"tag_name":' | \
    sed -E 's/.*"([^"]+)".*/\1/' || true
}

# 5. Install Jujutsu (jj)
if ! command -v jj >/dev/null 2>&1 && [ -n "$TARGET_ARCH" ]; then
  echo "Installing Jujutsu (jj)..."
  JJ_TAG="$(get_latest_release "jj-vcs/jj")"
  if [ -n "$JJ_TAG" ]; then
    TMP_DIR="$(mktemp -d)"
    JJ_ARCHIVE="jj-${JJ_TAG}-${TARGET_ARCH}-unknown-linux-musl.tar.gz"
    JJ_URL="https://github.com/jj-vcs/jj/releases/download/${JJ_TAG}/${JJ_ARCHIVE}"
    if curl -fsSL "$JJ_URL" -o "$TMP_DIR/jj.tar.gz" 2>/dev/null; then
      tar -xzf "$TMP_DIR/jj.tar.gz" -C "$TMP_DIR"
      find "$TMP_DIR" -type f -name jj -exec cp {} "$BIN_DIR/jj" \;
      chmod +x "$BIN_DIR/jj"
      echo "Installed jj ${JJ_TAG} to $BIN_DIR/jj"
    fi
    rm -rf "$TMP_DIR"
  fi
fi

# 6. Install git-delta
if ! command -v delta >/dev/null 2>&1 && [ -n "$TARGET_ARCH" ]; then
  echo "Installing git-delta..."
  DELTA_TAG="$(get_latest_release "dandavison/delta")"
  if [ -n "$DELTA_TAG" ]; then
    TMP_DIR="$(mktemp -d)"
    DELTA_ARCHIVE="delta-${DELTA_TAG}-${TARGET_ARCH}-unknown-linux-musl.tar.gz"
    DELTA_URL="https://github.com/dandavison/delta/releases/download/${DELTA_TAG}/${DELTA_ARCHIVE}"
    if curl -fsSL "$DELTA_URL" -o "$TMP_DIR/delta.tar.gz" 2>/dev/null; then
      tar -xzf "$TMP_DIR/delta.tar.gz" -C "$TMP_DIR"
      find "$TMP_DIR" -type f -name delta -exec cp {} "$BIN_DIR/delta" \;
      chmod +x "$BIN_DIR/delta"
      echo "Installed delta to $BIN_DIR/delta"
    fi
    rm -rf "$TMP_DIR"
  fi
fi

# 7. Install eza
if ! command -v eza >/dev/null 2>&1 && [ -n "$TARGET_ARCH" ]; then
  echo "Installing eza..."
  EZA_TAG="$(get_latest_release "eza-community/eza")"
  if [ -n "$EZA_TAG" ]; then
    TMP_DIR="$(mktemp -d)"
    EZA_ARCHIVE="eza_${TARGET_ARCH}-unknown-linux-musl.tar.gz"
    EZA_URL="https://github.com/eza-community/eza/releases/download/${EZA_TAG}/${EZA_ARCHIVE}"
    if curl -fsSL "$EZA_URL" -o "$TMP_DIR/eza.tar.gz" 2>/dev/null; then
      tar -xzf "$TMP_DIR/eza.tar.gz" -C "$TMP_DIR"
      find "$TMP_DIR" -type f -name eza -exec cp {} "$BIN_DIR/eza" \;
      chmod +x "$BIN_DIR/eza"
      echo "Installed eza to $BIN_DIR/eza"
    fi
    rm -rf "$TMP_DIR"
  fi
fi

echo "Linux package and toolchain setup complete."
