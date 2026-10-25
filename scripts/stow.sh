#!/bin/sh
set -eu

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="${HOME}"
CONFIG_DIR="${TARGET_DIR}/.config"

CORE_PACKAGES="bat eza fish git helix herdr jj nvim ruff starship yazi"
GUI_PACKAGES="ghostty wezterm"

MODE="stow"
INCLUDE_GUI=1
DRY_RUN=0
FORCE=0
INTERACTIVE=1

for arg in "$@"; do
  case "$arg" in
    --core-only|-c)
      INCLUDE_GUI=0
      ;;
    --delete|-D)
      MODE="delete"
      ;;
    --dry-run|-n|--simulate)
      DRY_RUN=1
      ;;
    --force|-f)
      FORCE=1
      INTERACTIVE=0
      ;;
    --non-interactive|--batch)
      INTERACTIVE=0
      ;;
    --interactive|-i)
      INTERACTIVE=1
      FORCE=0
      ;;
    --help|-h)
      cat <<EOF
Usage: ./scripts/stow.sh [OPTIONS]

Options:
  -n, --dry-run, --simulate  Show actions without making any changes
  -i, --interactive          Prompt for each conflicting config (default when in terminal)
  -f, --force                Force update/overwrite existing configs (backs up real directories)
  -c, --core-only            Stow only core CLI packages (skip GUI: ghostty, wezterm)
  -D, --delete               Unstow (remove) symlinks
  --non-interactive, --batch Do not prompt; skip any conflicting unmanaged configs
  -h, --help                 Show this help message

Conflict Handling:
  When an existing file/directory in ~/.config is not managed by this repo, you will be
  prompted to:
    [y]es    - Overwrite / replace with dotfiles symlink
    [b]ackup - Back up existing target to <path>.bak.<timestamp> before linking
    [n]o     - Skip this package to protect existing configuration (default)
    [a]ll    - Force replace all subsequent conflicting packages
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

if ! command -v stow >/dev/null 2>&1; then
  echo "Error: GNU Stow is not installed or not in PATH." >&2
  exit 1
fi

PACKAGES="$CORE_PACKAGES"
if [ "$INCLUDE_GUI" -eq 1 ]; then
  PACKAGES="$PACKAGES $GUI_PACKAGES"
fi

echo "============================================="
echo "GNU Stow Configuration Manager"
echo "  Target directory : $TARGET_DIR"
echo "  Mode             : $MODE"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "  Execution        : DRY RUN (no files modified)"
elif [ "$FORCE" -eq 1 ]; then
  echo "  Execution        : FORCE (overwrite/update enabled)"
else
  echo "  Execution        : INTERACTIVE (prompts on conflict)"
fi
echo "============================================="

# Ensure target ~/.config directory exists
if [ "$DRY_RUN" -eq 0 ] && [ ! -d "$CONFIG_DIR" ]; then
  mkdir -p "$CONFIG_DIR"
fi

# Helper function to prompt on conflict
handle_conflict() {
  _target="$1"
  _pkg="$2"
  _item_type="$3"

  # Force mode: automatically resolve
  if [ "$FORCE" -eq 1 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[DRY RUN] Force mode: Would replace $_target ($_item_type) with package '$_pkg'."
      return 0
    fi
    if [ -L "$_target" ] || [ -f "$_target" ]; then
      rm -f "$_target"
    elif [ -d "$_target" ]; then
      _ts="$(date +%Y%m%d_%H%M%S)"
      _bak="${_target}.bak.${_ts}"
      echo "[INFO] Backing up existing directory $_target -> $_bak"
      mv "$_target" "$_bak"
    fi
    return 0
  fi

  # Dry run mode
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY RUN] Existing config detected: $_target ($_item_type). Would prompt to overwrite, back up, or skip."
    return 1
  fi

  # Non-interactive mode (without force)
  TTY="/dev/tty"
  if [ "$INTERACTIVE" -eq 0 ] || [ ! -r "$TTY" ]; then
    echo "[WARN] $_target exists ($_item_type). Non-interactive mode active; skipping '$_pkg'."
    echo "       Run with -i/--interactive to choose, or -f/--force to overwrite."
    return 1
  fi

  # Interactive prompt
  echo ""
  echo "------------------------------------------------------------------"
  echo "[CONFLICT] Target already exists for package '$_pkg':"
  echo "  Path: $_target"
  echo "  Type: $_item_type"
  printf "  Choose action: [y]es overwrite / [b]ackup & replace / [n]o skip / [a]ll force (default: n): "
  read -r _answer < "$TTY"
  echo "------------------------------------------------------------------"

  case "$_answer" in
    y|Y|yes|Yes)
      if [ -L "$_target" ] || [ -f "$_target" ]; then
        rm -f "$_target"
      elif [ -d "$_target" ]; then
        rm -rf "$_target"
      fi
      echo "  -> Replaced existing $_target"
      return 0
      ;;
    b|B|backup|Backup)
      _ts="$(date +%Y%m%d_%H%M%S)"
      _bak="${_target}.bak.${_ts}"
      mv "$_target" "$_bak"
      echo "  -> Backed up existing configuration to $_bak"
      return 0
      ;;
    a|A|all|All)
      FORCE=1
      if [ -L "$_target" ] || [ -f "$_target" ]; then
        rm -f "$_target"
      elif [ -d "$_target" ]; then
        _ts="$(date +%Y%m%d_%H%M%S)"
        _bak="${_target}.bak.${_ts}"
        mv "$_target" "$_bak"
        echo "  -> Backed up directory to $_bak"
      fi
      echo "  -> Enabled force mode for this and all subsequent conflicts."
      return 0
      ;;
    *)
      echo "  -> Skipped package '$_pkg' to protect existing configuration."
      return 1
      ;;
  esac
}

# Pre-flight check: scan each package before stowing
SKIPPED_PACKAGES=""
ACTIVE_PACKAGES=""

for pkg in $PACKAGES; do
  if [ ! -d "$DOTFILES_DIR/$pkg" ]; then
    continue
  fi

  PKG_HAS_CONFLICT=0
  for item in "$DOTFILES_DIR/$pkg"/dot-config/*; do
    [ -e "$item" ] || continue
    basename="$(basename "$item")"
    target_path="$CONFIG_DIR/$basename"

    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
      if [ -L "$target_path" ]; then
        link_target="$(readlink "$target_path" 2>/dev/null || true)"
        case "$link_target" in
          *"$DOTFILES_DIR/$pkg/dot-config/"*)
            # Already points to this modular package
            ;;
          *"$DOTFILES_DIR/config/"*)
            # Legacy monolithic symlink from earlier version of this repository
            if ! handle_conflict "$target_path" "$pkg" "legacy dotfiles symlink ($link_target)"; then
              PKG_HAS_CONFLICT=1
            fi
            ;;
          *)
            # Symlink pointing to somewhere else
            if ! handle_conflict "$target_path" "$pkg" "external symlink ($link_target)"; then
              PKG_HAS_CONFLICT=1
            fi
            ;;
        esac
      elif [ -d "$target_path" ]; then
        if ! handle_conflict "$target_path" "$pkg" "directory (unmanaged)"; then
          PKG_HAS_CONFLICT=1
        fi
      else
        if ! handle_conflict "$target_path" "$pkg" "regular file (unmanaged)"; then
          PKG_HAS_CONFLICT=1
        fi
      fi
    fi
  done

  if [ "$PKG_HAS_CONFLICT" -eq 1 ]; then
    SKIPPED_PACKAGES="$SKIPPED_PACKAGES $pkg"
  else
    ACTIVE_PACKAGES="$ACTIVE_PACKAGES $pkg"
  fi
done

echo ""
if [ -n "$SKIPPED_PACKAGES" ]; then
  echo "Skipped packages (existing configs left untouched):"
  for p in $SKIPPED_PACKAGES; do
    echo "  - $p"
  done
  echo ""
fi

if [ -z "$ACTIVE_PACKAGES" ]; then
  echo "No packages to process."
  exit 0
fi

echo "Packages to process:"
for p in $ACTIVE_PACKAGES; do
  echo "  + $p"
done
echo ""

STOW_FLAGS="--dir=$DOTFILES_DIR --target=$TARGET_DIR --dotfiles"
if [ "$DRY_RUN" -eq 1 ]; then
  STOW_FLAGS="$STOW_FLAGS --simulate -v"
fi

for pkg in $ACTIVE_PACKAGES; do
  echo "==> [$MODE] $pkg"
  if [ "$MODE" = "delete" ]; then
    # shellcheck disable=SC2086
    stow $STOW_FLAGS -D "$pkg" 2>&1 || true
  else
    # shellcheck disable=SC2086
    stow $STOW_FLAGS -R "$pkg"
  fi
done

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run complete. No modifications were made to $TARGET_DIR."
else
  echo "Stow operation completed successfully."
fi
