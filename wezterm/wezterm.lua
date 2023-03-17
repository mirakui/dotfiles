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
    title = shorten_path(tab.active_pane.current_working_dir)
    return {
      -- { Background = { Color = 'blue' } },
      { Text = ' ' .. title .. ' ' },
    }
  end
)

return {
  font = wezterm.font("Monaco"),
  use_ime = true,
  font_size = 12.0,
  initial_rows = 50,
  initial_cols = 180,
  color_scheme = "OneHalfDark", -- https://wezfurlong.org/wezterm/colorschemes/index.html
  window_background_opacity = 0.8,
  hide_tab_bar_if_only_one_tab = true,
  adjust_window_size_when_changing_font_size = false,

  enable_cwd_in_title = true,

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

  },

  window_update_interval = 1000,
}
