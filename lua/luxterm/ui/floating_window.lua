-- Unified floating window factory with enhanced configuration support
local buffer_protection = require("luxterm.ui.buffer_protection")
local utils = require("luxterm.utils")

local M = {}

-- Window type configurations
M.window_types = {
  session_list = {
    relative = "editor",
    border = "rounded",
    title = " Sessions ",
    title_pos = "center",
    style = "minimal",
    buffer_options = utils.buffer_presets.luxterm_main,
    protected = true,
    hide_cursor = true
  },
  
  preview = {
    relative = "editor", 
    border = "rounded",
    title = " Preview ",
    title_pos = "center",
    style = "minimal",
    buffer_options = utils.buffer_presets.luxterm_preview,
    hide_cursor = true
  },
  
  session_terminal = {
    relative = "editor",
    border = "rounded",
    title_pos = "center",
    style = "minimal",
    zindex = 100,
    enter = true,
    terminal_keymaps = true
  }
}

function M.create_window(config)
  config = config or {}
  
  -- Create buffer
  local bufnr = config.bufnr
  if not bufnr then
    bufnr = vim.api.nvim_create_buf(false, true)
    if config.buffer_options then
      utils.apply_buffer_options(bufnr, config.buffer_options)
    end
  end
  
  -- Set default dimensions if not provided
  local width, height = config.width, config.height
  if not width or not height then
    local default_width, default_height = utils.calculate_size_from_ratio(0.8, 0.8)
    width = width or default_width
    height = height or default_height
  end
  
  -- Default window config
  local win_config = {
    relative = config.relative or "editor",
    width = width,
    height = height,
    border = config.border or "rounded",
    style = "minimal"
  }
  
  -- Calculate position if not provided
  if not config.row or not config.col then
    win_config.row, win_config.col = utils.calculate_centered_position(win_config.width, win_config.height)
  else
    win_config.row = config.row
    win_config.col = config.col
  end
  
  -- Add optional configs
  if config.title then
    win_config.title = config.title
    win_config.title_pos = config.title_pos or "center"
  end
  if config.zindex then
    win_config.zindex = config.zindex
  end
  
  -- Create window
  local winid = vim.api.nvim_open_win(bufnr, config.enter or false, win_config)
  
  -- Window-specific options
  if config.window_options then
    for opt, value in pairs(config.window_options) do
      vim.wo[winid][opt] = value
    end
  end
  
  -- Apply buffer protection if requested
  if config.protected then
    buffer_protection.setup_protection(bufnr)
  end
  
  -- Hide cursor if requested
  if config.hide_cursor then
    buffer_protection.setup_cursor_hiding(winid, bufnr)
  end
  
  -- Setup auto-hide on cursor leave if requested
  if config.auto_hide then
    M.setup_auto_hide(winid, bufnr, config.auto_hide_callback)
  end
  
  -- Call creation callback
  if config.on_create then
    config.on_create(winid, bufnr)
  end
  
  -- Setup close callback
  if config.on_close then
    vim.api.nvim_create_autocmd("WinClosed", {
      pattern = tostring(winid),
      callback = config.on_close,
      once = true
    })
  end
  
  return winid, bufnr
end

-- Factory method for creating windows by type
function M.create_typed_window(window_type, overrides)
  overrides = overrides or {}
  
  local base_config = M.window_types[window_type]
  if not base_config then
    error("Unknown window type: " .. tostring(window_type))
  end
  
  -- Merge configurations with overrides taking precedence
  local config = vim.tbl_deep_extend("force", base_config, overrides)
  
  return M.create_window(config)
end

function M.create_split_layout(base_config, left_config, right_config)
  -- Calculate split dimensions
  local total_width = base_config.width
  local total_height = base_config.height
  local left_width = math.floor(total_width * (left_config.width_ratio or 0.5))
  local right_width = total_width - left_width - 1 -- Account for border
  
  -- Create left window
  local left_win_config = vim.tbl_extend("force", base_config, left_config, {
    width = left_width,
    height = total_height
  })
  local left_winid, left_bufnr = M.create_window(left_win_config)
  
  -- Create right window (positioned next to left)
  local right_win_config = vim.tbl_extend("force", base_config, right_config, {
    width = right_width,
    height = total_height,
    col = base_config.col + left_width + 1,
    enter = false
  })
  local right_winid, right_bufnr = M.create_window(right_win_config)
  
  return {
    left = {winid = left_winid, bufnr = left_bufnr},
    right = {winid = right_winid, bufnr = right_bufnr}
  }
end

function M.close_window(winid)
  if utils.is_valid_window(winid) then
    vim.api.nvim_win_close(winid, true)
    return true
  end
  return false
end

function M.focus_window(winid)
  if utils.is_valid_window(winid) then
    vim.api.nvim_set_current_win(winid)
    return true
  end
  return false
end

function M.update_window_content(winid, lines)
  if not utils.is_valid_window(winid) then
    return false
  end
  
  local bufnr = vim.api.nvim_win_get_buf(winid)
  if not utils.is_valid_buffer(bufnr) then
    return false
  end
  
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return true
end

function M.resize_window(winid, width, height)
  if not utils.is_valid_window(winid) then
    return false
  end
  
  vim.api.nvim_win_set_config(winid, {
    width = width,
    height = height
  })
  return true
end

function M.move_window(winid, row, col)
  if not utils.is_valid_window(winid) then
    return false
  end
  
  vim.api.nvim_win_set_config(winid, {
    row = row,
    col = col
  })
  return true
end

function M.is_floating_window(winid)
  if not utils.is_valid_window(winid) then
    return false
  end
  
  local config = vim.api.nvim_win_get_config(winid)
  return config.relative and config.relative ~= ""
end


-- Create a session terminal window using the typed window factory
-- Auto-hide functionality for floating windows
function M.setup_auto_hide(winid, bufnr, callback)
  if not utils.is_valid_window(winid) then
    return
  end
  
  local augroup_deleted = false
  
  local function safe_delete_augroup(group_id)
    if not augroup_deleted then
      augroup_deleted = true
      pcall(vim.api.nvim_del_augroup_by_id, group_id)
    end
  end
  
  local function should_hide()
    -- Check if window is still valid
    if not utils.is_valid_window(winid) then
      return false
    end
    
    local current_win = vim.api.nvim_get_current_win()
    
    -- Don't hide if we're currently in this window
    if current_win == winid then
      return false
    end
    
    -- Don't hide if we're in another luxterm floating window
    if M.is_floating_window(current_win) then
      local current_buf = vim.api.nvim_win_get_buf(current_win)
      local current_filetype = vim.api.nvim_buf_get_option(current_buf, "filetype")
      if current_filetype:match("^luxterm") or vim.api.nvim_buf_get_option(current_buf, "buftype") == "terminal" then
        return false
      end
    end
    
    return true
  end
  
  -- Set up autocmd to detect cursor leave
  local augroup = vim.api.nvim_create_augroup("LuxtermAutoHide_" .. winid, {clear = true})
  
  -- Monitor window enter/leave events
  vim.api.nvim_create_autocmd({"WinEnter", "WinLeave", "CursorMoved", "CursorMovedI"}, {
    group = augroup,
    callback = function()
      vim.defer_fn(function()
        if should_hide() then
          if callback then
            callback(winid, bufnr)
          else
            M.close_window(winid)
          end
          -- Clean up the autocmd group safely
          safe_delete_augroup(augroup)
        end
      end, 100) -- Small delay to prevent flickering
    end
  })
  
  -- Also clean up on window close
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(winid),
    callback = function()
      safe_delete_augroup(augroup)
    end,
    once = true
  })
end

function M.create_session_window(session, config)
  config = config or {}
  
  local width, height = config.width, config.height
  if not width or not height then
    local default_width, default_height = utils.calculate_size_from_ratio(0.8, 0.8)
    width = width or default_width
    height = height or default_height
  end
  local row, col = utils.calculate_centered_position(width, height)
  
  -- Get auto_hide setting from config, defaulting to true for backwards compatibility
  local auto_hide = config.auto_hide
  if auto_hide == nil then
    auto_hide = true
  end
  
  local overrides = {
    bufnr = session.bufnr,
    width = width,
    height = height,
    row = row,
    col = col,
    title = " " .. (session.name or "Terminal") .. " ",
    auto_hide = auto_hide,
    auto_hide_callback = function(winid, bufnr)
      -- Custom callback for session windows - just close the window
      M.close_window(winid)
    end,
    on_create = function(winid, bufnr)
      -- Setup terminal-specific keymaps
      local opts = {noremap = true, silent = true, buffer = bufnr}
      -- Don't map ESC at all - let it work normally for nested editors like git commit
      -- Use C-Esc to close terminal window from terminal mode
      vim.keymap.set("t", "<C-Esc>", function()
        M.close_window(winid)
      end, opts)
      
      -- Get toggle keymap from core module to ensure it works in session windows
      local core = require("luxterm.core")
      if core and core.config then
        local toggle_key = core.config.keymaps.toggle_manager
        if toggle_key then
          vim.keymap.set({"n", "t"}, toggle_key, function()
            core.toggle_manager()
          end, vim.tbl_extend("force", opts, {desc = "Toggle Luxterm manager"}))
        end
      end
      
      -- Start in insert mode for terminal
      vim.cmd("startinsert")
    end
  }
  
  return M.create_typed_window("session_terminal", overrides)
end

return M