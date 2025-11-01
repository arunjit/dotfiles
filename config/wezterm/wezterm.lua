local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Theme
config.color_scheme = 'Catppuccin Mocha'

-- Fonts
config.font_size = 14
config.font = wezterm.font 'FiraCode Nerd Font Mono'
config.line_height = 1.2

-- Appearance
config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = true
config.window_padding = {
  top = 0,
  right = 0,
  bottom = 0,
  left = 0,
}

return config
