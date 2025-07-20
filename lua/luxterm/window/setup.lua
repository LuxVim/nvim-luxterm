local M = {}

local config = require('luxterm.config')

function M.setup_window(win_id, terminal_name, buffer_info)
  vim.wo[win_id].number = false
  vim.wo[win_id].relativenumber = false
  vim.wo[win_id].signcolumn = 'no'
  vim.wo[win_id].wrap = false
  
  vim.w[win_id].luxterm_terminal_name = terminal_name
  
  if config.get('focus_on_toggle') then
    vim.cmd('startinsert')
  end
  
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win_id),
    callback = function()
      require('luxterm.terminal.display').on_window_closed(terminal_name, win_id)
    end,
    once = true
  })
end

return M