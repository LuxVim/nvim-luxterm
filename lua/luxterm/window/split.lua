local M = {}

local config = require('luxterm.config')

function M.open_split(terminal_name, buffer_info)
  local position = buffer_info.position or config.get('position')
  local size = buffer_info.size or config.get('size')
  
  require('luxterm.window.utils').store_previous_window()
  
  local position_map = config.get_position_map()
  local pos_info = position_map[position] or position_map['bottom']
  
  local cmd
  if pos_info.direction == 'horizontal' then
    cmd = string.format('%s %dsplit', pos_info.split, size)
  else
    cmd = string.format('%s %dvsplit', pos_info.split, size)
  end
  
  vim.cmd(cmd)
  local win_id = vim.api.nvim_get_current_win()
  
  vim.api.nvim_win_set_buf(win_id, buffer_info.bufnr)
  
  require('luxterm.window.setup').setup_window(win_id, terminal_name, buffer_info)
  
  return win_id
end

return M