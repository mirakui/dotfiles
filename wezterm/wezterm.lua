local wezterm = require 'wezterm';

function shorten_path(path)
  local parts = {}
  for part in string.gmatch(path, "[^/]+") do
    table.insert(parts, part)
  end

  local num_parts = #parts
  if num_parts < 2 then
    return path
  else
    return parts[num_parts - 1] .. "/" .. parts[num_parts]
  end
end

wezterm.on(
  'format-tab-title',
  function(tab, tabs, panes, config, hover, max_width)
    local pane_title = tab.active_pane.title
    if pane_title ~= "zsh" then
      return { { Text = ' ' .. pane_title .. ' ' } }
    end
    local cwd = tab.active_pane.current_working_dir
    local path = ""
    if cwd then
      -- current_working_dir is a URL object; extract file_path
      path = cwd.file_path or tostring(cwd)
    end
    local title = shorten_path(path)
    return {
      -- { Background = { Color = 'blue' } },
      { Text = ' ' .. title .. ' ' },
    }
  end
)

wezterm.on(
  'format-window-title',
  function(tab, pane, tabs, panes, config)
    local cwd = tab.active_pane.current_working_dir
    if cwd then
      local path = cwd.file_path or tostring(cwd)
      return shorten_path(path)
    end
    return ""
  end
)

return {
  -- https://www.nerdfonts.com/
  -- brew install mononoki-nerd-font
  font = wezterm.font_with_fallback {
    { family = 'Mononoki Nerd Font', stretch = 'Expanded', weight = 'Regular' }
  },
  use_ime = true,
  font_size = 13.0,
  initial_rows = 50,
  initial_cols = 180,
  color_scheme = "Operator Mono Dark", -- https://wezfurlong.org/wezterm/colorschemes/index.html

  window_background_opacity = 0.8,
  macos_window_background_blur = 10,
  -- window_decorations = "NONE",
  hide_tab_bar_if_only_one_tab = false,
  adjust_window_size_when_changing_font_size = false,

--  window_frame = {
--    border_left_width = '0.2cell',
--    border_right_width = '0.2cell',
--    border_bottom_height = '0.2cell',
--    border_top_height = '0.2cell',
--    border_left_color = 'gray',
--    border_right_color = 'gray',
--    border_bottom_color = 'gray',
--    border_top_color = 'gray',
--    inactive_titlebar_bg = '#353535',
--    active_titlebar_bg = '#2b2042',
--    inactive_titlebar_fg = '#cccccc',
--    active_titlebar_fg = '#ffffff',
--    inactive_titlebar_border_bottom = '#2b2042',
--    active_titlebar_border_bottom = '#2b2042',
--    button_fg = '#cccccc',
--    button_bg = '#2b2042',
--    button_hover_fg = '#ffffff',
--    button_hover_bg = '#3b3052',
--  },

  keys = {
    {
      key = 'd',
      mods = 'CMD',
      action = wezterm.action.SplitPane {
        direction = 'Right',
      }
    },
    {
      key = 'D',
      mods = 'CMD',
      action = wezterm.action.SplitPane {
        direction = 'Down',
      }
    },
    {
      key = 'c',
      mods = 'ALT|CMD',
      action = wezterm.action.ShowDebugOverlay
    },
    {
      key = 'Enter',
      mods = 'SHIFT',
      action = wezterm.action.SendString("\x1b\r")
    },
    -- TODO: cmd+u で Opacity をいじりたい
  },
  hyperlink_rules = {
    {
      -- リンクにしたいものを明示することで email の自動リンクを除外
      regex = [[\bhttps?://\S+\b]],
      format = "$0",
    },
  },
}
