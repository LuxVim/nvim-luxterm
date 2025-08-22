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

-- Error handling utilities
function M.safe_call(func, error_msg, ...)
  local success, result = pcall(func, ...)
  if not success then
    if error_msg then
      vim.notify(error_msg .. ": " .. tostring(result), vim.log.levels.WARN)
    end
    return nil
  end
  return result
end

function M.safe_api_call(api_func, default_value, ...)
  local success, result = pcall(api_func, ...)
  return success and result or default_value
end

-- Configuration utilities
function M.merge_config(default_config, user_config)
  return vim.tbl_deep_extend("force", default_config, user_config or {})
end

function M.validate_config(config, schema)
  for key, expected_type in pairs(schema) do
    if config[key] ~= nil and type(config[key]) ~= expected_type then
      return false, string.format("Invalid type for '%s': expected %s, got %s", key, expected_type, type(config[key]))
    end
  end
  return true
end

-- Buffer content utilities
function M.is_terminal_buffer(bufnr)
  if not M.is_valid_buffer(bufnr) then
    return false
  end
  
  local filetype = M.safe_api_call(vim.api.nvim_buf_get_option, "", bufnr, "filetype")
  local buftype = M.safe_api_call(vim.api.nvim_buf_get_option, "", bufnr, "buftype")
  
  return filetype == "terminal" or buftype == "terminal"
end

function M.get_buffer_info(bufnr)
  if not M.is_valid_buffer(bufnr) then
    return nil
  end
  
  return {
    filetype = M.safe_api_call(vim.api.nvim_buf_get_option, "unknown", bufnr, "filetype"),
    buftype = M.safe_api_call(vim.api.nvim_buf_get_option, "unknown", bufnr, "buftype"),
    name = M.safe_api_call(vim.api.nvim_buf_get_name, "", bufnr)
  }
end

-- String utilities
function M.truncate_string(str, max_length, suffix)
  suffix = suffix or "..."
  if #str <= max_length then
    return str
  end
  return string.sub(str, 1, max_length - #suffix) .. suffix
end

function M.pad_string(str, width, align)
  align = align or "left"
  local padding = width - vim.fn.strdisplaywidth(str)
  
  if padding <= 0 then
    return str
  end
  
  if align == "center" then
    local left_pad = math.floor(padding / 2)
    local right_pad = padding - left_pad
    return string.rep(" ", left_pad) .. str .. string.rep(" ", right_pad)
  elseif align == "right" then
    return string.rep(" ", padding) .. str
  else
    return str .. string.rep(" ", padding)
  end
end

return M