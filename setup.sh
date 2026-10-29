#!/bin/sh
set -eu

# ==============================================================================
# dotfiles setup & bootstrap script
# Can be run locally: ./setup.sh [OPTIONS]
# Or via curl:        curl -fsSL https://raw.githubusercontent.com/arunjit/dotfiles/main/setup.sh | sh
# ==============================================================================

DOTFILES_REPO_URL="https://github.com/arunjit/dotfiles.git"
CORE_PACKAGES="bat eza fish git helix herdr jj nvim ruff starship yazi"
GUI_PACKAGES="ghostty wezterm"
TARGET_DIR="${HOME}"
CONFIG_DIR="${TARGET_DIR}/.config"

# Execution flags
RUN_PACKAGES=1
RUN_STOW=1
CORE_ONLY=0
DRY_RUN=0
FORCE=0
INTERACTIVE=1

# Failure tracking for resumption
FAILED_STEPS=""
STOW_FAILURES=""

log_step() {
  echo ""
  echo "==> $1"
}

log_info() {
  echo "    [INFO] $1"
}

log_warn() {
  echo "    [WARN] $1"
}

log_error() {
  echo "    [ERROR] $1" >&2
}

record_failure() {
  _step="$1"
  FAILED_STEPS="${FAILED_STEPS:+${FAILED_STEPS}, }${_step}"
}

DOTFILES_DIR_ARG=""

# ------------------------------------------------------------------------------
# 1. Argument Parsing
# ------------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    -d|--dir)
      DOTFILES_DIR_ARG="$2"
      shift 2
      ;;
    --dir=*)
      DOTFILES_DIR_ARG="${1#*=}"
      shift
      ;;
    -n|--dry-run|--simulate)
      DRY_RUN=1
      RUN_PACKAGES=0
      shift
      ;;
    --force|-f)
      FORCE=1
      INTERACTIVE=0
      shift
      ;;
    --interactive|-i)
      INTERACTIVE=1
      FORCE=0
      shift
      ;;
    --non-interactive|--batch)
      INTERACTIVE=0
      shift
      ;;
    --stow-only)
      RUN_PACKAGES=0
      shift
      ;;
    --packages-only)
      RUN_STOW=0
      shift
      ;;
    --core-only)
      CORE_ONLY=1
      shift
      ;;
    -h|--help)
      cat <<EOF
Usage: ./setup.sh [OPTIONS]

Options:
  -d, --dir <path>       Target directory for dotfiles clone (default: ~/Developer/dotfiles)
  -n, --dry-run          Simulate operations without modifying files or installing packages
  -i, --interactive      Prompt before replacing any existing unmanaged config (default)
  -f, --force            Force-update packages (backs up existing directories/files automatically)
  --stow-only            Skip package installations and only link configurations
  --packages-only        Install dependencies without modifying symlinks
  --core-only            Install/link only headless core CLI packages (skip GUI apps: ghostty, wezterm)
  --non-interactive      Do not prompt; automatically skip any conflicting unmanaged configs
  -h, --help             Show this help message

Remote Bootstrap:
  curl -fsSL https://raw.githubusercontent.com/arunjit/dotfiles/main/setup.sh | sh
  curl -fsSL https://raw.githubusercontent.com/arunjit/dotfiles/main/setup.sh | sh -s -- --dir ~/.dotfiles

Resuming:
  This script is fully idempotent. If interrupted or if a step fails, re-running
  the script will safely resume where it left off, skipping completed items.
EOF
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

OS="$(uname -s)"
echo "============================================="
echo "Dotfiles Bootstrap & Setup"
echo "  OS               : $OS"
echo "  Target directory : $TARGET_DIR"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "  Mode             : DRY RUN (no files modified)"
elif [ "$FORCE" -eq 1 ]; then
  echo "  Mode             : FORCE (overwrite with backup)"
else
  echo "  Mode             : INTERACTIVE"
fi
echo "============================================="

# ------------------------------------------------------------------------------
# Helper: Ensure Git is installed (Critical prerequisite for clone & Jujutsu)
# ------------------------------------------------------------------------------
ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return 0
  fi

  log_step "Git is not installed. Installing Git (required for dotfiles & Jujutsu)..."
  case "$OS" in
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        SUDO=""
        [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"
        $SUDO apt-get update -y || true
        if ! $SUDO apt-get install -y git curl; then
          log_error "Failed to install git via apt."
          record_failure "git"
          return 1
        fi
      else
        log_error "Please install 'git' using your system package manager."
        record_failure "git"
        return 1
      fi
      ;;
    Darwin)
      log_info "Prompting for Apple Command Line Tools installation (provides git)..."
      xcode-select --install 2>/dev/null || true
      log_warn "Apple Command Line Tools installation triggered."
      log_warn "Please complete the prompt, then re-run setup.sh to resume."
      exit 0
      ;;
    *)
      log_error "Unsupported OS: $OS. Please install git manually."
      record_failure "git"
      return 1
      ;;
  esac
  return 0
}

# ------------------------------------------------------------------------------
# 2. Resolve, Clone, or Repair Repository
# ------------------------------------------------------------------------------
if [ -n "$DOTFILES_DIR_ARG" ]; then
  DOTFILES_DIR="$DOTFILES_DIR_ARG"
else
  SCRIPT_DIR="$(cd "$(dirname "$0" 2>/dev/null || pwd)" 2>/dev/null && pwd || pwd)"
  if [ -d "$SCRIPT_DIR/fish/dot-config" ] && [ -d "$SCRIPT_DIR/git/dot-config" ]; then
    DOTFILES_DIR="$SCRIPT_DIR"
    log_info "Using local repository at $DOTFILES_DIR"
  else
    DOTFILES_DIR="${DOTFILES_DIR:-$HOME/Developer/dotfiles}"
  fi
fi

# Expand tilde in DOTFILES_DIR if present
case "$DOTFILES_DIR" in
  "~"/*) DOTFILES_DIR="$HOME/${DOTFILES_DIR#\~/}" ;;
  "~")   DOTFILES_DIR="$HOME" ;;
esac

log_step "Target dotfiles repository: $DOTFILES_DIR"

  # Resumption / Repair check for incomplete or broken clone
  if [ -d "$DOTFILES_DIR" ] && [ ! -d "$DOTFILES_DIR/fish/dot-config" ]; then
    log_warn "Incomplete or corrupted directory found at $DOTFILES_DIR."
    if [ -d "$DOTFILES_DIR/.git" ]; then
      log_info "Attempting to repair existing git repository..."
      if git -C "$DOTFILES_DIR" fetch --depth=1 origin 2>/dev/null && \
         (git -C "$DOTFILES_DIR" reset --hard origin/HEAD 2>/dev/null || \
          git -C "$DOTFILES_DIR" reset --hard origin/main 2>/dev/null); then
        log_info "Repository successfully repaired."
      else
        log_warn "Repair failed. Cleaning up for fresh clone..."
        rm -rf "$DOTFILES_DIR"
      fi
    else
      log_warn "Cleaning up non-git directory for fresh clone..."
      rm -rf "$DOTFILES_DIR"
    fi
  fi

  if [ ! -d "$DOTFILES_DIR/fish/dot-config" ]; then
    ensure_git || exit 1
    log_info "Cloning $DOTFILES_REPO_URL to $DOTFILES_DIR..."
    mkdir -p "$(dirname "$DOTFILES_DIR")"
    if ! git clone "$DOTFILES_REPO_URL" "$DOTFILES_DIR"; then
      log_error "Failed to clone dotfiles repository."
      log_warn "To resume, check your internet connection and re-run setup.sh."
      exit 1
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 3. Package Installation
# ------------------------------------------------------------------------------
if [ "$RUN_PACKAGES" -eq 1 ]; then
  # Ensure Git is present on the host
  ensure_git || true

  case "$OS" in
    Darwin)
      log_step "Installing macOS packages via Homebrew..."
      if ! command -v brew >/dev/null 2>&1; then
        log_info "Homebrew not found. Installing Homebrew..."
        if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
          if [ -x "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
          elif [ -x "/usr/local/bin/brew" ]; then
            eval "$(/usr/local/bin/brew shellenv)"
          fi
        else
          log_warn "Homebrew installation was interrupted or failed."
          record_failure "homebrew"
        fi
      fi

      if command -v brew >/dev/null 2>&1; then
        brew update || log_warn "brew update returned non-zero, continuing..."
        MAC_PACKAGES="
          bat direnv eza fd fish fzf gh git git-delta
          helix jj jq jqp lua luajit luarocks ripgrep
          starship stow tlrc xq yazi yq zoxide
        "
        # shellcheck disable=SC2086
        if ! brew install $MAC_PACKAGES; then
          log_warn "Some Homebrew packages failed to install. Continuing setup..."
          record_failure "brew packages"
        fi
      fi
      ;;

    Linux)
      log_step "Installing Linux packages..."
      BIN_DIR="$HOME/.local/bin"
      mkdir -p "$BIN_DIR"
      case ":$PATH:" in
        *:"$BIN_DIR":*) ;;
        *) PATH="$BIN_DIR:$PATH" ;;
      esac

      if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
        CORE_ONLY=1
      fi

      # 3.1 APT packages on Debian / Raspberry Pi OS
      if command -v apt-get >/dev/null 2>&1; then
        SUDO=""
        [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"

        # Repair any previously interrupted dpkg run (e.g. from Ctrl+C)
        $SUDO dpkg --configure -a 2>/dev/null || true

        log_info "Updating apt packages..."
        $SUDO apt-get update -y || log_warn "apt-get update encountered warnings, continuing..."

        # Install core packages (git is included explicitly)
        APT_PKGS="build-essential curl file git fish stow fzf ripgrep jq direnv bat fd-find xclip ca-certificates tar gzip xz-utils"
        # shellcheck disable=SC2086
        if ! $SUDO apt-get install -y $APT_PKGS; then
          log_warn "Some apt packages failed to install. You can re-run setup to retry."
          record_failure "apt packages"
        fi

        # Symlink Debian binary names to standard names
        if command -v batcat >/dev/null 2>&1 && [ ! -e "$BIN_DIR/bat" ]; then
          log_info "Creating symlink $BIN_DIR/bat -> $(command -v batcat)"
          ln -sf "$(command -v batcat)" "$BIN_DIR/bat"
        fi
        if command -v fdfind >/dev/null 2>&1 && [ ! -e "$BIN_DIR/fd" ]; then
          log_info "Creating symlink $BIN_DIR/fd -> $(command -v fdfind)"
          ln -sf "$(command -v fdfind)" "$BIN_DIR/fd"
        fi
      fi

      # 3.2 Starship
      if ! command -v starship >/dev/null 2>&1 && [ ! -x "$BIN_DIR/starship" ]; then
        log_info "Installing Starship prompt..."
        if ! curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$BIN_DIR" >/dev/null 2>&1; then
          log_warn "Starship install failed. Can be retried by re-running setup.sh."
          record_failure "starship"
        else
          log_info "Starship prompt installed (Fish integration is already included in dotfiles)."
        fi
      fi

      # 3.3 Zoxide
      if ! command -v zoxide >/dev/null 2>&1 && [ ! -x "$BIN_DIR/zoxide" ]; then
        log_info "Installing Zoxide..."
        if ! (curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | BIN_DIR="$BIN_DIR" sh 2>/dev/null); then
          log_warn "Zoxide install failed. Can be retried by re-running setup.sh."
          record_failure "zoxide"
        fi
      fi

      # 3.4 Architecture detection for release binaries
      ARCH="$(uname -m)"
      case "$ARCH" in
        x86_64|amd64) TARGET_ARCH="x86_64" ;;
        aarch64|arm64) TARGET_ARCH="aarch64" ;;
        armv7l|armhf) TARGET_ARCH="arm" ;;
        *) TARGET_ARCH="" ;;
      esac

      # Helper with API rate-limit resilience
      get_latest_release() {
        _repo="$1"
        _fallback="$2"
        _tag="$(curl -s "https://api.github.com/repos/$_repo/releases/latest" 2>/dev/null | \
          grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)"
        if [ -n "$_tag" ]; then
          echo "$_tag"
        else
          echo "$_fallback"
        fi
      }

      # 3.5 Jujutsu (jj) - Requires git!
      if ! command -v jj >/dev/null 2>&1 && [ ! -x "$BIN_DIR/jj" ] && [ -n "$TARGET_ARCH" ]; then
        if ! command -v git >/dev/null 2>&1; then
          log_warn "Git is required by Jujutsu (jj) for repository storage. Skipping jj."
          record_failure "jj (missing git)"
        else
          log_info "Installing Jujutsu (jj)..."
          JJ_TAG="$(get_latest_release "jj-vcs/jj" "v0.28.2")"
          TMP_DIR="$(mktemp -d)"
          JJ_ARCHIVE="jj-${JJ_TAG}-${TARGET_ARCH}-unknown-linux-musl.tar.gz"
          JJ_URL="https://github.com/jj-vcs/jj/releases/download/${JJ_TAG}/${JJ_ARCHIVE}"
          
          if curl -fsSL "$JJ_URL" -o "$TMP_DIR/jj.tar.gz" 2>/dev/null; then
            if tar -xzf "$TMP_DIR/jj.tar.gz" -C "$TMP_DIR" 2>/dev/null; then
              find "$TMP_DIR" -type f -name jj -exec cp {} "$BIN_DIR/jj" \;
              chmod +x "$BIN_DIR/jj" 2>/dev/null || true
              log_info "Installed jj $JJ_TAG to $BIN_DIR/jj"
            else
              log_warn "Failed to extract jj archive."
              record_failure "jj"
            fi
          else
            log_warn "Could not download jj release binary ($JJ_URL)."
            record_failure "jj"
          fi
          rm -rf "$TMP_DIR"
        fi
      fi

      # 3.6 git-delta
      if ! command -v delta >/dev/null 2>&1 && [ ! -x "$BIN_DIR/delta" ] && [ -n "$TARGET_ARCH" ]; then
        log_info "Installing git-delta..."
        DELTA_TAG="$(get_latest_release "dandavison/delta" "0.18.2")"
        TMP_DIR="$(mktemp -d)"
        DELTA_ARCHIVE="delta-${DELTA_TAG}-${TARGET_ARCH}-unknown-linux-musl.tar.gz"
        DELTA_URL="https://github.com/dandavison/delta/releases/download/${DELTA_TAG}/${DELTA_ARCHIVE}"
        
        if curl -fsSL "$DELTA_URL" -o "$TMP_DIR/delta.tar.gz" 2>/dev/null; then
          if tar -xzf "$TMP_DIR/delta.tar.gz" -C "$TMP_DIR" 2>/dev/null; then
            find "$TMP_DIR" -type f -name delta -exec cp {} "$BIN_DIR/delta" \;
            chmod +x "$BIN_DIR/delta" 2>/dev/null || true
            log_info "Installed delta $DELTA_TAG to $BIN_DIR/delta"
          fi
        else
          log_warn "Could not download git-delta binary."
          record_failure "delta"
        fi
        rm -rf "$TMP_DIR"
      fi

      # 3.7 eza
      if ! command -v eza >/dev/null 2>&1 && [ ! -x "$BIN_DIR/eza" ] && [ -n "$TARGET_ARCH" ]; then
        log_info "Installing eza..."
        EZA_TAG="$(get_latest_release "eza-community/eza" "v0.20.21")"
        TMP_DIR="$(mktemp -d)"
        EZA_ARCHIVE="eza_${TARGET_ARCH}-unknown-linux-musl.tar.gz"
        EZA_URL="https://github.com/eza-community/eza/releases/download/${EZA_TAG}/${EZA_ARCHIVE}"
        
        if curl -fsSL "$EZA_URL" -o "$TMP_DIR/eza.tar.gz" 2>/dev/null; then
          if tar -xzf "$TMP_DIR/eza.tar.gz" -C "$TMP_DIR" 2>/dev/null; then
            find "$TMP_DIR" -type f -name eza -exec cp {} "$BIN_DIR/eza" \;
            chmod +x "$BIN_DIR/eza" 2>/dev/null || true
            log_info "Installed eza $EZA_TAG to $BIN_DIR/eza"
          fi
        else
          log_warn "Could not download eza binary."
          record_failure "eza"
        fi
        rm -rf "$TMP_DIR"
      fi
      ;;
  esac
fi

# ------------------------------------------------------------------------------
# 4. Stow Configurations
# ------------------------------------------------------------------------------
if [ "$RUN_STOW" -eq 1 ]; then
  log_step "Checking and stowing configurations..."

  if ! command -v stow >/dev/null 2>&1; then
    log_error "GNU Stow is not installed or not in PATH."
    log_warn "Please install stow, then re-run setup.sh to complete linking."
    record_failure "stow (binary missing)"
  else
    [ "$DRY_RUN" -eq 0 ] && [ ! -d "$CONFIG_DIR" ] && mkdir -p "$CONFIG_DIR"

    PACKAGES="$CORE_PACKAGES"
    if [ "$CORE_ONLY" -eq 0 ]; then
      PACKAGES="$PACKAGES $GUI_PACKAGES"
    fi

    # Conflict handler
    handle_conflict() {
      _target="$1"
      _pkg="$2"
      _item_type="$3"

      if [ "$FORCE" -eq 1 ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
          log_info "[DRY RUN] Force mode: Would replace $_target ($_item_type) with package '$_pkg'."
          return 0
        fi
        if [ -L "$_target" ] || [ -f "$_target" ]; then
          rm -f "$_target"
        elif [ -d "$_target" ]; then
          _ts="$(date +%Y%m%d_%H%M%S)"
          _bak="${_target}.bak.${_ts}"
          log_info "Backing up directory $_target -> $_bak"
          mv "$_target" "$_bak"
        fi
        return 0
      fi

      if [ "$DRY_RUN" -eq 1 ]; then
        log_info "[DRY RUN] Conflict: $_target exists ($_item_type). Would prompt to overwrite or back up."
        return 1
      fi

      TTY="/dev/tty"
      if [ "$INTERACTIVE" -eq 0 ] || [ ! -r "$TTY" ]; then
        log_warn "$_target exists ($_item_type). Non-interactive mode active; skipping '$_pkg'."
        return 1
      fi

      echo ""
      echo "------------------------------------------------------------------"
      echo "[CONFLICT] Target already exists for package '$_pkg':"
      echo "  Path: $_target"
      echo "  Type: $_item_type"
      printf "  Action: [y]es overwrite / [b]ackup & replace / [n]o skip / [a]ll force (default: n): "
      read -r _answer < "$TTY"
      echo "------------------------------------------------------------------"

      case "$_answer" in
        y|Y|yes|Yes)
          if [ -L "$_target" ] || [ -f "$_target" ]; then
            rm -f "$_target"
          elif [ -d "$_target" ]; then
            rm -rf "$_target"
          fi
          log_info "Replaced $_target"
          return 0
          ;;
        b|B|backup|Backup)
          _ts="$(date +%Y%m%d_%H%M%S)"
          _bak="${_target}.bak.${_ts}"
          mv "$_target" "$_bak"
          log_info "Backed up configuration to $_bak"
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
            log_info "Backed up directory to $_bak"
          fi
          log_info "Enabled force mode for all subsequent packages."
          return 0
          ;;
        *)
          log_info "Skipped package '$_pkg' to protect existing configuration."
          return 1
          ;;
      esac
    }

    SKIPPED_PACKAGES=""
    ACTIVE_PACKAGES=""

    for pkg in $PACKAGES; do
      [ -d "$DOTFILES_DIR/$pkg" ] || continue
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
                # Already points to current modular package
                ;;
              *"$DOTFILES_DIR/config/"*)
                # Legacy symlink from earlier dotfiles versions
                if ! handle_conflict "$target_path" "$pkg" "legacy dotfiles symlink ($link_target)"; then
                  PKG_HAS_CONFLICT=1
                fi
                ;;
              *)
                if ! handle_conflict "$target_path" "$pkg" "external symlink ($link_target)"; then
                  PKG_HAS_CONFLICT=1
                fi
                ;;
            esac
          elif [ -d "$target_path" ]; then
            if ! handle_conflict "$target_path" "$pkg" "unmanaged directory"; then
              PKG_HAS_CONFLICT=1
            fi
          else
            if ! handle_conflict "$target_path" "$pkg" "unmanaged file"; then
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

    if [ -n "$SKIPPED_PACKAGES" ]; then
      echo ""
      log_info "Skipped packages (existing configs left untouched):"
      for p in $SKIPPED_PACKAGES; do
        echo "      - $p"
      done
    fi

    if [ -n "$ACTIVE_PACKAGES" ]; then
      echo ""
      log_info "Stowing active packages:"
      for p in $ACTIVE_PACKAGES; do
        echo "      + $p"
      done
      echo ""

      STOW_FLAGS="--dir=$DOTFILES_DIR --target=$TARGET_DIR --dotfiles"
      [ "$DRY_RUN" -eq 1 ] && STOW_FLAGS="$STOW_FLAGS --simulate -v"

      for pkg in $ACTIVE_PACKAGES; do
        echo "    -> Stowing $pkg..."
        # shellcheck disable=SC2086
        if ! stow $STOW_FLAGS -R "$pkg"; then
          log_warn "Failed to stow package '$pkg'."
          STOW_FAILURES="${STOW_FAILURES:+${STOW_FAILURES}, }${pkg}"
        fi
      done
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 5. Post-Setup (Idempotent)
# ------------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 0 ]; then
  log_step "Configuring auxiliary tools & caches..."

  # fzf-git helper
  FZF_GIT_DIR="$HOME/.local/share/fzf-git"
  if [ ! -d "$FZF_GIT_DIR" ]; then
    log_info "Cloning junegunn/fzf-git.sh to $FZF_GIT_DIR..."
    git clone --depth 1 https://github.com/junegunn/fzf-git.sh "$FZF_GIT_DIR" 2>/dev/null || true
  else
    git -C "$FZF_GIT_DIR" pull --quiet 2>/dev/null || true
  fi

  # Build bat theme cache
  if command -v bat >/dev/null 2>&1; then
    log_info "Building bat cache..."
    bat cache --build >/dev/null 2>&1 || true
  elif command -v batcat >/dev/null 2>&1; then
    log_info "Building batcat cache..."
    batcat cache --build >/dev/null 2>&1 || true
  fi

  # Automatically initialize Jujutsu (--no-colocate) if repository was cloned via Git
  JJ_BIN="$(command -v jj 2>/dev/null || true)"
  [ -z "$JJ_BIN" ] && [ -x "$HOME/.local/bin/jj" ] && JJ_BIN="$HOME/.local/bin/jj"
  if [ -n "$JJ_BIN" ] && [ -d "$DOTFILES_DIR/.git" ] && [ ! -d "$DOTFILES_DIR/.jj" ]; then
    log_info "Initializing Jujutsu repository on $DOTFILES_DIR (--no-colocate)..."
    if (cd "$DOTFILES_DIR" && "$JJ_BIN" git init --no-colocate >/dev/null 2>&1); then
      log_info "Repository successfully initialized with Jujutsu (--no-colocate)."
    else
      log_warn "Jujutsu automatic initialization skipped or returned non-zero."
    fi
  fi

  # Set fish theme
  if command -v fish >/dev/null 2>&1; then
    fish -c 'fish_config theme save "Catppuccin Mocha" >/dev/null 2>&1 || true'
  fi

  # Ensure fish is registered in /etc/shells so chsh succeeds without error
  FISH_BIN="$(command -v fish 2>/dev/null || true)"
  if [ -n "$FISH_BIN" ] && [ -r /etc/shells ]; then
    if ! grep -Fxq "$FISH_BIN" /etc/shells 2>/dev/null; then
      if [ -w /etc/shells ]; then
        echo "$FISH_BIN" >> /etc/shells
      elif command -v sudo >/dev/null 2>&1; then
        echo "$FISH_BIN" | sudo tee -a /etc/shells >/dev/null 2>&1 || true
      fi
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 6. Status Report & Resumption Advice
# ------------------------------------------------------------------------------
echo ""
echo "============================================="
if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry-run simulation completed. No files were modified."
elif [ -n "$FAILED_STEPS" ] || [ -n "$STOW_FAILURES" ]; then
  echo "Setup completed with warnings/incomplete items:"
  [ -n "$FAILED_STEPS" ] && echo "  - Pending tool installs : $FAILED_STEPS"
  [ -n "$STOW_FAILURES" ] && echo "  - Failed stow packages  : $STOW_FAILURES"
  echo ""
  echo "How to resume:"
  echo "  Simply re-run ./setup.sh (or the curl command)."
  echo "  All operations are idempotent; completed tasks will"
  echo "  be automatically skipped and remaining tasks resumed."
else
  echo "Dotfiles setup completed successfully!"
fi

# Default shell recommendation
if [ "$DRY_RUN" -eq 0 ]; then
  FISH_BIN="$(command -v fish 2>/dev/null || echo "fish")"
  CURRENT_SHELL="$(basename "${SHELL:-}")"
  echo ""
  echo "Default Shell:"
  if [ "$CURRENT_SHELL" = "fish" ]; then
    echo "  Fish is already your default shell."
  else
    echo "  Fish is configured as your primary shell."
    echo "  To set Fish as your default login shell, run:"
    echo "    chsh -s \"$FISH_BIN\""
    echo ""
    echo "  To launch Fish immediately in this session, run:"
    echo "    fish"
  fi
fi
echo "============================================="
