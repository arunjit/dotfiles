#!/bin/sh
set -eu

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES_DIR"

RUN_PACKAGES=1
RUN_STOW=1
CORE_ONLY=0
DRY_RUN=0
FORCE=0
INTERACTIVE=1

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run|--simulate)
      DRY_RUN=1
      RUN_PACKAGES=0
      ;;
    --force|-f)
      FORCE=1
      INTERACTIVE=0
      ;;
    --interactive|-i)
      INTERACTIVE=1
      FORCE=0
      ;;
    --non-interactive|--batch)
      INTERACTIVE=0
      ;;
    --stow-only)
      RUN_PACKAGES=0
      ;;
    --packages-only)
      RUN_STOW=0
      ;;
    --core-only)
      CORE_ONLY=1
      ;;
    -h|--help)
      cat <<EOF
Usage: ./setup.sh [OPTIONS]

Options:
  -n, --dry-run          Simulate operations without modifying files or installing packages
  -i, --interactive      Prompt before replacing any existing unmanaged config (default)
  -f, --force            Force-update packages (backs up existing directories/files automatically)
  --stow-only            Skip package installations and only link configurations
  --packages-only        Install dependencies without modifying symlinks
  --core-only            Install/link only headless core CLI packages (skip GUI apps)
  --non-interactive      Do not prompt; automatically skip any conflicting unmanaged configs
  -h, --help             Show this help message
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

OS="$(uname -s)"
echo "==> Detected OS: $OS"

# 1. Package Installation
if [ "$RUN_PACKAGES" -eq 1 ]; then
  case "$OS" in
    Darwin)
      echo "==> Running macOS package installer..."
      "$DOTFILES_DIR/scripts/install-mac.sh"
      ;;
    Linux)
      echo "==> Running Linux package installer..."
      "$DOTFILES_DIR/scripts/install-linux.sh"
      # On Linux headless servers, default to core-only unless graphical display detected
      if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
        CORE_ONLY=1
      fi
      ;;
    *)
      echo "Warning: Unsupported OS '$OS'. Skipping automated package installation." >&2
      ;;
  esac
fi

# 2. Stow Configurations
if [ "$RUN_STOW" -eq 1 ]; then
  echo "==> Checking and stowing configuration packages..."
  STOW_ARGS=""
  if [ "$CORE_ONLY" -eq 1 ]; then
    STOW_ARGS="$STOW_ARGS --core-only"
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    STOW_ARGS="$STOW_ARGS --dry-run"
  fi
  if [ "$FORCE" -eq 1 ]; then
    STOW_ARGS="$STOW_ARGS --force"
  elif [ "$INTERACTIVE" -eq 0 ]; then
    STOW_ARGS="$STOW_ARGS --non-interactive"
  else
    STOW_ARGS="$STOW_ARGS --interactive"
  fi
  # shellcheck disable=SC2086
  "$DOTFILES_DIR/scripts/stow.sh" $STOW_ARGS
fi

# 3. Post-Setup & External Resources (Idempotent)
if [ "$DRY_RUN" -eq 0 ]; then
  echo "==> Configuring external resources..."

# fzf-git helper script
FZF_GIT_DIR="$HOME/.local/share/fzf-git"
if [ ! -d "$FZF_GIT_DIR" ]; then
  echo "Cloning junegunn/fzf-git.sh to $FZF_GIT_DIR..."
  git clone --depth 1 https://github.com/junegunn/fzf-git.sh "$FZF_GIT_DIR" 2>/dev/null || true
else
  echo "Updating fzf-git in $FZF_GIT_DIR..."
  git -C "$FZF_GIT_DIR" pull --quiet 2>/dev/null || true
fi

# Build bat theme cache if bat is available
if command -v bat >/dev/null 2>&1; then
  echo "Building bat cache..."
  bat cache --build >/dev/null 2>&1 || true
elif command -v batcat >/dev/null 2>&1; then
  echo "Building batcat cache..."
  batcat cache --build >/dev/null 2>&1 || true
fi

# Set fish theme if fish is available
if command -v fish >/dev/null 2>&1; then
  echo "Setting Catppuccin Mocha theme for fish..."
  fish -c 'fish_config theme save "Catppuccin Mocha" >/dev/null 2>&1 || true'
fi
fi

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry-run check complete. No system changes were made."
else
  echo "Dotfiles setup completed successfully!"
fi
