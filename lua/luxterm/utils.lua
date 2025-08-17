-- Shared utility functions for nvim-luxterm
local M = {}

-- Validation helper functions
function M.is_valid_window(winid)
  return winid and vim.api.nvim_win_is_valid(winid)
end

function M.is_valid_buffer(bufnr)
  return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

return M