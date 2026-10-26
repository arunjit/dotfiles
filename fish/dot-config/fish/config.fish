# Setup PATH using fish_add_path (safely handles existence and prepends without duplicates)
fish_add_path --prepend --global \
    $HOME/Developer/bin \
    $HOME/.local/bin \
    $HOME/.cargo/bin \
    /opt/homebrew/bin \
    /opt/homebrew/sbin \
    /opt/homebrew/opt/rustup/bin \
    /home/linuxbrew/.linuxbrew/bin \
    /home/linuxbrew/.linuxbrew/sbin

# Preferred Editor
set -gx EDITOR hx
set -gx VISUAL hx

# Go path
set -gx GOPATH $HOME/Developer

# Terminal colors
set -gx CLICOLOR 1

# Eza config directory
set -gx EZA_CONFIG_DIR $HOME/.config/eza

# FZF Catppuccin Mocha theme & options
set -gx FZF_CTRL_T_OPTS "--preview 'bat -n --color=always --line-range=:500 {}'"
set -gx FZF_ALT_C_OPTS "--preview 'eza --tree --color=always {} | head -200'"
set -gx FZF_DEFAULT_OPTS "\
--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 \
--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
--color=selected-bg:#45475A \
--color=border:#6C7086,label:#CDD6F4"

# Embedded Rust for ESP32 (only active if toolchain is present)
# if test -d "$HOME/.rustup/toolchains/esp"
#     set -l esp_clang (find "$HOME/.rustup/toolchains/esp" -name "libclang.dylib" -o -name "libclang.so" 2>/dev/null | head -n 1)
#     if test -n "$esp_clang"
#         set -gx LIBCLANG_PATH (dirname "$esp_clang")
#     end
#     for esp_bin in (find "$HOME/.rustup/toolchains/esp" -type d -name "bin" 2>/dev/null)
#         fish_add_path $esp_bin
#     end
# end

# Dynamic tool integrations (guarded so missing tools do not error)
if status is-interactive
    type -q fzf; and fzf --fish | source
    type -q jj; and jj util completion fish | source
    type -q starship; and starship init fish | source
    type -q zoxide; and zoxide init fish | source
end

# Load local overrides if present (e.g. machine-specific credentials or toolchains)
if test -f $__fish_config_dir/conf.d/local.fish
    source $__fish_config_dir/conf.d/local.fish
end
