-- Unified floating window factory with enhanced configuration support
local buffer_protection = require("luxterm.ui.buffer_protection")

local M = {}

-- Window type configurations
M.window_types = {
  session_list = {
    relative = "editor",
    border = "rounded",
    title = " Sessions ",
    title_pos = "center",
    style = "minimal",
    buffer_options = {
      filetype = "luxterm_main",
      bufhidden = "wipe",
      swapfile = false,
      buftype = "nofile",
      modifiable = false
    },
    protected = true,
    hide_cursor = true
  },
  
  preview = {
    relative = "editor", 
    border = "rounded",
    title = " Preview ",
    title_pos = "center",
    style = "minimal",
    buffer_options = {
      filetype = "luxterm_preview",
      bufhidden = "wipe",
      swapfile = false,
      buftype = "nofile",
      modifiable = false
    },
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
      for opt, value in pairs(config.buffer_options) do
        vim.api.nvim_buf_set_option(bufnr, opt, value)
      end
    end
  end
  
  -- Default window config
  local win_config = {
    relative = config.relative or "editor",
    width = config.width or math.floor(vim.o.columns * 0.8),
    height = config.height or math.floor(vim.o.lines * 0.8),
    border = config.border or "rounded",
    style = "minimal"
  }
  
  -- Calculate position if not provided
  if not config.row or not config.col then
    win_config.row = math.floor((vim.o.lines - win_config.height) / 2)
    win_config.col = math.floor((vim.o.columns - win_config.width) / 2)
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
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
    return true
  end
  return false
end

function M.focus_window(winid)
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_set_current_win(winid)
    return true
  end
  return false
end

function M.update_window_content(winid, lines)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  
  local bufnr = vim.api.nvim_win_get_buf(winid)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return true
end

function M.resize_window(winid, width, height)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  
  vim.api.nvim_win_set_config(winid, {
    width = width,
    height = height
  })
  return true
end

function M.move_window(winid, row, col)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  
  vim.api.nvim_win_set_config(winid, {
    row = row,
    col = col
  })
  return true
end

function M.is_floating_window(winid)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  
  local config = vim.api.nvim_win_get_config(winid)
  return config.relative and config.relative ~= ""
end

-- Utility function to calculate centered position
function M.calculate_centered_position(width, height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  return row, col
end

-- Create a session terminal window using the typed window factory
function M.create_session_window(session, config)
  config = config or {}
  
  local width = config.width or math.floor(vim.o.columns * 0.8)
  local height = config.height or math.floor(vim.o.lines * 0.8)
  local row, col = M.calculate_centered_position(width, height)
  
  local overrides = {
    bufnr = session.bufnr,
    width = width,
    height = height,
    row = row,
    col = col,
    title = " " .. (session.name or "Terminal") .. " ",
    on_create = function(winid, bufnr)
      -- Setup terminal-specific keymaps
      local opts = {noremap = true, silent = true, buffer = bufnr}
      vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", opts)
      vim.keymap.set("t", "<C-Esc>", function()
        M.close_window(winid)
      end, opts)
      vim.keymap.set("n", "<Esc>", function()
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