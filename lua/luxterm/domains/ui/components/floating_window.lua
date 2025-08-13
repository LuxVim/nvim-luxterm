local api_adapter = require("luxterm.infrastructure.nvim.api_adapter")
local event_bus = require("luxterm.infrastructure.events.event_bus")
local event_types = require("luxterm.infrastructure.events.event_types")

local M = {
  windows = {},
  default_config = {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    zindex = 50
  }
}

function M.setup(opts)
  opts = opts or {}
  M.default_config = vim.tbl_deep_extend("force", M.default_config, opts.window_config or {})
end

function M.create_window(config)
  config = vim.tbl_deep_extend("force", M.default_config, config or {})
  
  local bufnr = config.bufnr
  if not bufnr then
    bufnr = vim.api.nvim_create_buf(false, true)
    M._setup_buffer(bufnr, config.buffer_options or {})
  end
  
  local win_config = {
    relative = config.relative,
    width = config.width,
    height = config.height,
    row = config.row,
    col = config.col,
    style = config.style,
    border = config.border,
    zindex = config.zindex
  }
  
  if config.title then
    win_config.title = config.title
    win_config.title_pos = config.title_pos or "center"
  end
  
  local winid = vim.api.nvim_open_win(bufnr, config.enter or false, win_config)
  
  local window_data = {
    winid = winid,
    bufnr = bufnr,
    config = config,
    created_at = vim.loop.now()
  }
  
  M.windows[winid] = window_data
  
  M._setup_window_options(winid, config.window_options or {})
  
  if config.on_create then
    config.on_create(winid, bufnr)
  end
  
  return winid, bufnr
end

function M._setup_buffer(bufnr, options)
  local default_options = {
    modifiable = false,
    buftype = "nofile",
    swapfile = false,
    bufhidden = "wipe"
  }
  
  local final_options = vim.tbl_deep_extend("force", default_options, options)
  
  for option, value in pairs(final_options) do
    api_adapter.batch_buf_set_option(bufnr, option, value)
  end
end

function M._setup_window_options(winid, options)
  local default_options = {
    winhighlight = "Normal:Normal,FloatBorder:FloatBorder"
  }
  
  local final_options = vim.tbl_deep_extend("force", default_options, options)
  
  for option, value in pairs(final_options) do
    api_adapter.batch_win_set_option(winid, option, value)
  end
end

function M.close_window(winid)
  local window_data = M.windows[winid]
  if not window_data then
    return false
  end
  
  if vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
  end
  
  if window_data.config.on_close then
    window_data.config.on_close(winid, window_data.bufnr)
  end
  
  M.windows[winid] = nil
  return true
end

function M.update_window_content(winid, lines, opts)
  local window_data = M.windows[winid]
  if not window_data or not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  
  opts = opts or {}
  local bufnr = window_data.bufnr
  
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  
  api_adapter.batch_buf_set_option(bufnr, "modifiable", true)
  
  if opts.append then
    local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for _, line in ipairs(lines) do
      table.insert(current_lines, line)
    end
    api_adapter.batch_buf_set_lines(bufnr, 0, -1, false, current_lines)
  else
    api_adapter.batch_buf_set_lines(bufnr, 0, -1, false, lines)
  end
  
  api_adapter.batch_buf_set_option(bufnr, "modifiable", false)
  
  return true
end

function M.resize_window(winid, new_width, new_height)
  if not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  
  local config = vim.api.nvim_win_get_config(winid)
  config.width = new_width
  config.height = new_height
  
  vim.api.nvim_win_set_config(winid, config)
  
  local window_data = M.windows[winid]
  if window_data then
    window_data.config.width = new_width
    window_data.config.height = new_height
  end
  
  return true
end

function M.move_window(winid, new_row, new_col)
  if not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  
  local config = vim.api.nvim_win_get_config(winid)
  config.row = new_row
  config.col = new_col
  
  vim.api.nvim_win_set_config(winid, config)
  
  local window_data = M.windows[winid]
  if window_data then
    window_data.config.row = new_row
    window_data.config.col = new_col
  end
  
  return true
end

function M.focus_window(winid)
  if vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_set_current_win(winid)
    return true
  end
  return false
end

function M.get_window_info(winid)
  local window_data = M.windows[winid]
  if not window_data then
    return nil
  end
  
  return {
    winid = winid,
    bufnr = window_data.bufnr,
    config = window_data.config,
    created_at = window_data.created_at,
    is_valid = vim.api.nvim_win_is_valid(winid)
  }
end

function M.get_all_windows()
  local valid_windows = {}
  for winid, window_data in pairs(M.windows) do
    if vim.api.nvim_win_is_valid(winid) then
      table.insert(valid_windows, M.get_window_info(winid))
    else
      M.windows[winid] = nil
    end
  end
  return valid_windows
end

function M.close_all_windows()
  for winid in pairs(M.windows) do
    M.close_window(winid)
  end
end

function M.create_split_layout(base_config, left_config, right_config)
  local left_width = math.floor(base_config.width * (left_config.width_ratio or 0.3))
  local right_width = base_config.width - left_width
  
  local left_win_config = vim.tbl_deep_extend("force", left_config, {
    width = left_width,
    height = base_config.height,
    row = base_config.row,
    col = base_config.col
  })
  
  local right_win_config = vim.tbl_deep_extend("force", right_config, {
    width = right_width,
    height = base_config.height,
    row = base_config.row,
    col = base_config.col + left_width
  })
  
  local left_winid, left_bufnr = M.create_window(left_win_config)
  local right_winid, right_bufnr = M.create_window(right_win_config)
  
  if left_config.enter then
    M.focus_window(left_winid)
  end
  
  return {
    left = { winid = left_winid, bufnr = left_bufnr },
    right = { winid = right_winid, bufnr = right_bufnr }
  }
end

function M.setup_window_autocmds(winid, autocmds)
  local window_data = M.windows[winid]
  if not window_data then
    return false
  end
  
  for event, callback in pairs(autocmds) do
    vim.api.nvim_create_autocmd(event, {
      pattern = tostring(winid),
      callback = callback,
      once = event == "WinClosed"
    })
  end
  
  return true
end

function M.calculate_centered_position(width, height)
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines
  
  local row = math.floor((editor_height - height) / 2)
  local col = math.floor((editor_width - width) / 2)
  
  return row, col
end

function M.cleanup()
  M.close_all_windows()
  M.windows = {}
end

return M