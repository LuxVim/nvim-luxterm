-- Shared utility functions for nvim-luxterm
local M = {}

-- Validation helper functions
function M.is_valid_window(winid)
  return winid and vim.api.nvim_win_is_valid(winid)
end

function M.is_valid_buffer(bufnr)
  return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

-- Window positioning utilities
function M.calculate_centered_position(width, height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  return row, col
end

function M.calculate_size_from_ratio(ratio_width, ratio_height)
  local width = math.floor(vim.o.columns * ratio_width)
  local height = math.floor(vim.o.lines * ratio_height)
  return width, height
end

-- Common buffer option sets
M.buffer_presets = {
  luxterm_main = {
    filetype = "luxterm_main",
    bufhidden = "wipe",
    swapfile = false,
    buftype = "nofile",
    modifiable = false
  },
  luxterm_preview = {
    filetype = "luxterm_preview",
    bufhidden = "wipe",
    swapfile = false,
    buftype = "nofile",
    modifiable = false
  },
  terminal = {
    swapfile = false
  }
}

function M.apply_buffer_options(bufnr, preset_or_options)
  if not M.is_valid_buffer(bufnr) then
    return false
  end
  
  local options = M.buffer_presets[preset_or_options] or preset_or_options
  if type(options) == "table" then
    for opt, value in pairs(options) do
      vim.api.nvim_buf_set_option(bufnr, opt, value)
    end
    return true
  end
  return false
end

return M