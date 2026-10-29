# dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/) and [Jujutsu (`jj`)](https://github.com/jj-vcs/jj), configured for **Fish shell** with a unified **Catppuccin Mocha** dark theme across macOS and Linux (including Raspberry Pi OS Lite).

---

## Installation

### Quick Start (One-Liner)

On any fresh system (macOS or Linux / Raspberry Pi OS Lite), bootstrap your environment with a single command:

```sh
curl -fsSL https://raw.githubusercontent.com/arunjit/dotfiles/main/setup.sh | sh
```

The script is self-contained and automatically:
1. Installs minimal prerequisites (`git`, `curl`) if not present.
2. Clones this repository (default: `~/Developer/dotfiles`, configurable via `--dir`).
3. Installs package dependencies (Homebrew on macOS; `apt` and standalone release binaries on Linux).
4. Initializes [Jujutsu (`jj`)](https://github.com/jj-vcs/jj) on the repository (`--no-colocate`).
5. Stows configurations safely into `~/.config` with interactive prompts for any conflicts.
6. Builds the syntax highlighting cache (`bat`) and applies themes.
7. Registers Fish in `/etc/shells` and prints the command to set it as default.

You can also pass flags directly through the pipe:
```sh
# Clone to a custom directory (e.g. ~/.dotfiles):
curl -fsSL https://raw.githubusercontent.com/arunjit/dotfiles/main/setup.sh | sh -s -- --dir ~/.dotfiles

# Preview actions without installing packages or touching files:
curl -fsSL https://raw.githubusercontent.com/arunjit/dotfiles/main/setup.sh | sh -s -- --dry-run

# Link only headless core tools on a server / Raspberry Pi:
curl -fsSL https://raw.githubusercontent.com/arunjit/dotfiles/main/setup.sh | sh -s -- --core-only
```

---

### Setting Fish as Default Shell

Fish is configured as your primary shell. To set it as your default login shell, run:

```sh
chsh -s "$(which fish)"
```

Or to enter Fish immediately in the current terminal:

```sh
fish
```

---

### Manual Installation (Clone First)

If you prefer to clone and inspect the repository before running the installer:

#### 1. Prerequisites

* **Raspberry Pi OS Lite (or minimal Debian / Ubuntu):**
  ```sh
  sudo apt update && sudo apt install -y git curl
  ```
* **macOS:**
  ```sh
  xcode-select --install
  ```

#### 2. Clone the Repository

```sh
git clone https://github.com/arunjit/dotfiles.git ~/Developer/dotfiles
cd ~/Developer/dotfiles
```

*(Note: If Jujutsu is already present on the system, you can clone directly with `jj git clone --no-colocate https://github.com/arunjit/dotfiles.git ~/Developer/dotfiles`)*

#### 3. Run Setup

```sh
./setup.sh
```

#### 4. Jujutsu Initialization

`setup.sh` automatically converts the cloned repository into a non-colocated Jujutsu repository as soon as `jj` is installed.

If you ever need to manually convert an existing Git clone to a non-colocated Jujutsu repository:

```sh
jj git init --colocate
mv .git .jj/repo/store/git
printf "git" > .jj/repo/store/git_target
```

---

### Resuming After Interruption or Failure

The setup script is **fully idempotent and self-healing**:

* **Safe to Re-Run:** If a network drop, package lock, or manual cancellation (`Ctrl+C`) interrupts setup, simply run `./setup.sh` again (or re-run the `curl` command). It will skip already completed tasks and resume where it left off.
* **Corrupted Clone Recovery:** If an initial clone was interrupted midway, the script automatically repairs or re-clones the directory.
* **Package Manager Recovery:** On Debian / Raspberry Pi OS, interrupted package states are automatically repaired via `dpkg --configure -a`.
* **API Rate-Limit Fallbacks:** If the GitHub API is unavailable or rate-limited when downloading binary releases (`jj`, `starship`, `zoxide`, `delta`, `eza`), the script falls back to pinned release versions.

---

### Safety & Setup Options

The setup script guarantees **zero accidental overwriting** of existing unmanaged configurations in `~/.config`.

| Option | Description |
| :--- | :--- |
| `-n`, `--dry-run` | Preview actions, conflict checks, and Stow links without modifying any files or installing packages. |
| `-i`, `--interactive` | Prompt for each conflicting config (`[y]es`, `[b]ackup & replace`, `[n]o skip`, or `[a]ll force`). *(Default in interactive terminals)* |
| `-f`, `--force` | Force update/overwrite. Any conflicting physical directory or file is automatically backed up to a timestamped `.bak` file before replacement. |
| `--core-only` | Link only headless CLI packages, skipping GUI apps (`ghostty`, `wezterm`). |
| `--stow-only` | Skip package installations and only link configurations. |
| `--packages-only` | Install dependencies without modifying symlinks. |

#### Dry Run Example

```sh
./setup.sh --dry-run
```

#### Selective / Manual Stowing

You can also stow individual packages or run the stow step independently:

```sh
# Stow all configurations without package installation
./setup.sh --stow-only

# Or use GNU Stow directly for a single package
stow --target="$HOME" --dotfiles fish
```

---

## Overview

### Included Packages & Stack

All packages follow a modular Stow layout (`<tool>/dot-config/<tool>/...`), mapping cleanly to `~/.config/`:

| Package | Purpose & Configuration |
| :--- | :--- |
| **`fish`** | Primary shell configured with Catppuccin Mocha, guarded completions, dynamic `PATH` management via `fish_add_path`, and Mac muscle-memory compatibility on Linux. |
| **`git`** | Git config with side-by-side `delta` diffs and a vendored Catppuccin Mocha theme. |
| **`jj`** | [Jujutsu](https://github.com/jj-vcs/jj) configuration with custom log graph styling, side-by-side delta pager, and auto-formatting fixers (`ruff`, `clang-format`, `rustfmt`, `mdformat`). |
| **`starship`** | Fast prompt configured for Fish via `~/.config/starship.toml` (integrations are pre-configured in `config.fish`). |
| **`helix`** | Minimalist modal editor with Catppuccin Mocha theme and cursor shape preferences. |
| **`nvim`** | Neovim setup bootstrapped with `lazy.nvim` and Catppuccin color scheme. |
| **`herdr`** | Terminal workspace & agent orchestrator with custom keybindings and Catppuccin styling. |
| **`bat`** | Catppuccin Mocha syntax highlighting theme with prebuilt cache. |
| **`eza`** | Modern `ls` replacement with custom color styling (`theme.yml`). |
| **`yazi`** | Terminal file manager with custom theme and config. |
| **`ruff`** | Python linter/formatter configuration. |
| **`ghostty`** *(GUI)* | Ghostty terminal configuration with FiraCode Nerd Font. |
| **`wezterm`** *(GUI)* | WezTerm terminal configuration with native macOS fullscreen support. |

---

### Portability & Linux Compatibility

When running on Linux (such as Raspberry Pi OS Lite), dotfiles provide automatic compatibility layer enhancements so standard macOS muscle memory works out of the box:

* **Debian Package Name Fallbacks:** Aliases `bat` to `batcat` and `fd` to `fdfind` (with binary shims in `~/.local/bin` for external tools like `fzf` previews).
* **Clipboard:** Aliases `pbcopy` and `pbpaste` to `wl-copy`/`wl-paste` (Wayland), `xclip`, or `xsel`.
* **URL/File Opener:** Aliases `open` to `xdg-open`.
* **SD Card Protection:** Environment variables use global exports (`set -gx`) instead of universal variables (`set -U`) to prevent constant writes to Raspberry Pi flash memory.
* **Local Machine Overrides:** Machine-specific settings or credentials can be placed in untracked `~/.config/fish/conf.d/local.fish`.
