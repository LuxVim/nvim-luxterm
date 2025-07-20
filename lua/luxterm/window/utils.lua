local M = {}

function M.store_previous_window()
  local current_win = vim.api.nvim_get_current_win()
  local buffer_detect = require('luxterm.utils.buffer_detect')
  
  if buffer_detect.is_suitable_previous_window(current_win) then
    vim.w.luxterm_previous_win = current_win
  else
    local suitable_win = buffer_detect.find_suitable_previous_window(current_win)
    vim.w.luxterm_previous_win = suitable_win
  end
end

function M.restore_previous_window()
  if vim.w.luxterm_previous_win then
    if vim.fn.win_gotoid(vim.w.luxterm_previous_win) == 0 then
      vim.cmd('wincmd p')
    end
  else
    vim.cmd('wincmd p')
  end
end

return M