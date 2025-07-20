local M = {}

local config = require('luxterm.config')

local floating_windows = {}

function M.open_floating(terminal_name, buffer_info)
  local width = math.floor(vim.o.columns * config.get('floating_width'))
  local height = math.floor(vim.o.lines * config.get('floating_height'))
  
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  local border = config.get('floating_border')
  
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = border,
    focusable = true,
    zindex = 1000
  }
  
  if vim.fn.has('nvim-0.9.0') == 1 then
    opts.title = ' Terminal: ' .. terminal_name .. ' '
    opts.title_pos = 'center'
  end
  
  require('luxterm.window.utils').store_previous_window()
  
  local win_id = vim.api.nvim_open_win(buffer_info.bufnr, true, opts)
  
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    vim.notify('LuxTerm: Failed to create floating window', vim.log.levels.ERROR)
    return nil
  end
  
  floating_windows[terminal_name] = {
    win_id = win_id,
    buffer_info = buffer_info
  }
  
  require('luxterm.window.setup').setup_window(win_id, terminal_name, buffer_info)
  
  return win_id
end

function M.get_floating_window(terminal_name)
  return floating_windows[terminal_name]
end

function M.remove_floating_window(terminal_name)
  floating_windows[terminal_name] = nil
end

return M
