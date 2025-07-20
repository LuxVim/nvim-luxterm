local M = {}

function M.configure_terminal_window(win_id)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return
  end
  
  vim.wo[win_id].number = false
  vim.wo[win_id].relativenumber = false
  vim.wo[win_id].signcolumn = 'no'
  vim.wo[win_id].foldcolumn = '0'
  vim.wo[win_id].wrap = false
end


function M.get_window_config(config_type)
  local configs = {
    floating = {
      relative = 'editor',
      width = math.floor(vim.o.columns * 0.8),
      height = math.floor(vim.o.lines * 0.8),
      row = math.floor(vim.o.lines * 0.1),
      col = math.floor(vim.o.columns * 0.1),
      border = 'rounded',
      style = 'minimal'
    },
    split_horizontal = {
      split = 'below',
      height = math.floor(vim.o.lines * 0.3)
    },
    split_vertical = {
      split = 'right',
      width = math.floor(vim.o.columns * 0.4)
    }
  }
  
  return configs[config_type] or configs.floating
end

function M.create_window(bufnr, config_type, terminal_name)
  local config = M.get_window_config(config_type or 'floating')
  
  -- Add title for floating windows if terminal name is provided
  if config_type == 'floating' and terminal_name and vim.fn.has('nvim-0.9.0') == 1 then
    config.title = ' Terminal: ' .. terminal_name .. ' '
    config.title_pos = 'center'
  end
  
  local win_id
  if config.split then
    vim.cmd(config.split .. ' ' .. (config.height or config.width or ''))
    win_id = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win_id, bufnr)
  else
    win_id = vim.api.nvim_open_win(bufnr, true, config)
  end
  
  M.configure_terminal_window(win_id)
  return win_id
end

function M.close_window(win_id)
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_win_close(win_id, false)
    return true
  end
  return false
end

return M