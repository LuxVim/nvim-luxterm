local floating_window = require("luxterm.domains.ui.components.floating_window")
local session_list = require("luxterm.domains.ui.components.session_list")
local preview_pane = require("luxterm.domains.ui.components.preview_pane")
local event_bus = require("luxterm.infrastructure.events.event_bus")
local event_types = require("luxterm.infrastructure.events.event_types")

local M = {
  layouts = {},
  active_layout = nil,
  default_config = {
    manager_width = 0.8,
    manager_height = 0.8,
    left_pane_width = 0.3,
    border = "rounded"
  }
}

function M.setup(opts)
  opts = opts or {}
  M.default_config = vim.tbl_deep_extend("force", M.default_config, opts.layout_config or {})
  
  M._setup_event_listeners()
end

function M._setup_event_listeners()
  event_bus.subscribe(event_types.MANAGER_CLOSED, function()
    M.close_layout(M.active_layout)
  end)
end

function M.create_manager_layout(config)
  config = vim.tbl_deep_extend("force", M.default_config, config or {})
  
  local total_width = math.floor(vim.o.columns * config.manager_width)
  local total_height = math.floor(vim.o.lines * config.manager_height)
  local row, col = floating_window.calculate_centered_position(total_width, total_height)
  
  local base_config = {
    width = total_width,
    height = total_height,
    row = row,
    col = col,
    border = config.border
  }
  
  local left_config = {
    title = " Sessions ",
    width_ratio = config.left_pane_width,
    enter = true,
    buffer_options = {
      filetype = "luxterm_main"
    }
  }
  
  local right_config = {
    title = " Preview ",
    buffer_options = {
      filetype = "luxterm_preview"
    }
  }
  
  local windows = floating_window.create_split_layout(base_config, left_config, right_config)
  
  local layout = {
    id = "manager_" .. vim.loop.now(),
    type = "manager",
    windows = windows,
    config = config,
    created_at = vim.loop.now()
  }
  
  M.layouts[layout.id] = layout
  M.active_layout = layout.id
  
  M._setup_layout_components(layout)
  M._setup_layout_focus_management(layout)
  
  event_bus.emit(event_types.MANAGER_OPENED, {
    layout_id = layout.id,
    layout = layout
  })
  
  return layout.id
end

function M._setup_layout_components(layout)
  local session_list_config = {
    winid = layout.windows.left.winid,
    bufnr = layout.windows.left.bufnr
  }
  
  local preview_pane_config = {
    winid = layout.windows.right.winid,
    bufnr = layout.windows.right.bufnr
  }
  
  layout.components = {
    session_list = session_list,
    preview_pane = preview_pane
  }
  
  session_list.window_id = layout.windows.left.winid
  session_list.buffer_id = layout.windows.left.bufnr
  session_list._setup_keymaps()
  
  preview_pane.window_id = layout.windows.right.winid
  preview_pane.buffer_id = layout.windows.right.bufnr
  
  -- Hide cursor in manager windows
  vim.api.nvim_win_call(layout.windows.left.winid, function()
    vim.opt_local.guicursor = "a:block-NONE"
  end)
  
  vim.api.nvim_win_call(layout.windows.right.winid, function()
    vim.opt_local.guicursor = "a:block-NONE"
  end)
end

function M._setup_layout_focus_management(layout)
  local left_winid = layout.windows.left.winid
  local right_winid = layout.windows.right.winid
  
  local manager_windows = {left_winid, right_winid}
  
  floating_window.focus_window(left_winid)
  
  local focus_autocmd = vim.api.nvim_create_autocmd({"WinEnter", "BufEnter"}, {
    callback = function()
      local current_win = vim.api.nvim_get_current_win()
      
      local is_manager_window = false
      for _, winid in ipairs(manager_windows) do
        if current_win == winid then
          is_manager_window = true
          break
        end
      end
      
      if not is_manager_window then
        if vim.api.nvim_win_is_valid(left_winid) then
          floating_window.focus_window(left_winid)
        end
      end
    end
  })
  
  layout.focus_autocmd = focus_autocmd
  
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(left_winid),
    callback = function()
      M.close_layout(layout.id)
      if focus_autocmd then
        pcall(vim.api.nvim_del_autocmd, focus_autocmd)
      end
    end,
    once = true
  })
end

function M.create_session_window_layout(session, config)
  config = vim.tbl_deep_extend("force", M.default_config, config or {})
  
  -- Ensure we have a valid terminal buffer
  local terminal_bufnr = session.bufnr
  if not session:is_valid() then
    -- Create a new terminal buffer if the session doesn't have a valid one
    terminal_bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[terminal_bufnr].buftype = 'terminal'
    vim.fn.termopen(vim.o.shell, { buffer = terminal_bufnr })
    session.bufnr = terminal_bufnr
  end
  
  local total_width = math.floor(vim.o.columns * config.manager_width)
  local total_height = math.floor(vim.o.lines * config.manager_height)
  local row, col = floating_window.calculate_centered_position(total_width, total_height)
  
  local window_config = {
    width = total_width,
    height = total_height,
    row = row,
    col = col,
    border = config.border,
    title = " " .. (session.name or "Terminal") .. " ",
    title_pos = "center",
    enter = true,
    bufnr = terminal_bufnr,
    zindex = 100,
    on_create = function(winid, bufnr)
      -- Ensure we're really in terminal mode
      vim.api.nvim_set_current_win(winid)
      vim.api.nvim_set_current_buf(bufnr)
      M._setup_session_window_keymaps(winid, bufnr)
      vim.cmd("startinsert")
    end
  }
  
  local winid, bufnr = floating_window.create_window(window_config)
  
  local layout = {
    id = "session_" .. session.id .. "_" .. vim.loop.now(),
    type = "session",
    session = session,
    window_id = winid,
    buffer_id = bufnr,
    config = config,
    created_at = vim.loop.now()
  }
  
  M.layouts[layout.id] = layout
  M.active_layout = layout.id
  
  return layout.id
end

function M._setup_session_window_keymaps(winid, bufnr)
  local opts = { noremap = true, silent = true, buffer = bufnr }
  
  vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", opts)
  
  vim.keymap.set("t", "<C-Esc>", function()
    M.close_layout(M.active_layout)
  end, opts)
  
  vim.keymap.set("n", "<Esc>", function()
    M.close_layout(M.active_layout)
  end, opts)
end

function M.close_layout(layout_id)
  if not layout_id or not M.layouts[layout_id] then
    return false
  end
  
  local layout = M.layouts[layout_id]
  
  if layout.type == "manager" then
    M._close_manager_layout(layout)
  elseif layout.type == "session" then
    M._close_session_layout(layout)
  end
  
  M.layouts[layout_id] = nil
  
  if M.active_layout == layout_id then
    M.active_layout = nil
  end
  
  return true
end

function M._close_manager_layout(layout)
  if layout.components then
    if layout.components.session_list then
      layout.components.session_list.window_id = nil
      layout.components.session_list.buffer_id = nil
    end
    if layout.components.preview_pane then
      layout.components.preview_pane.destroy()
    end
  end
  
  if layout.windows then
    if layout.windows.left and layout.windows.left.winid then
      floating_window.close_window(layout.windows.left.winid)
    end
    if layout.windows.right and layout.windows.right.winid then
      floating_window.close_window(layout.windows.right.winid)
    end
  end
  
  if layout.focus_autocmd then
    pcall(vim.api.nvim_del_autocmd, layout.focus_autocmd)
  end
  
  -- Clean up event handlers stored in the layout
  if layout.cleanup_handlers then
    for _, cleanup in ipairs(layout.cleanup_handlers) do
      cleanup()
    end
    layout.cleanup_handlers = nil
  end
  
  event_bus.emit(event_types.MANAGER_CLOSED, {
    layout_id = layout.id
  })
  
  -- Trigger User autocmd for legacy cleanup mechanisms
  vim.api.nvim_exec_autocmds("User", {
    pattern = "LuxtermManagerClosed"
  })
end

function M._close_session_layout(layout)
  if layout.window_id then
    floating_window.close_window(layout.window_id)
  end
end

function M.get_layout(layout_id)
  return M.layouts[layout_id]
end

function M.get_active_layout()
  if M.active_layout then
    return M.layouts[M.active_layout]
  end
  return nil
end

function M.is_manager_open()
  local layout = M.get_active_layout()
  return layout and layout.type == "manager"
end

function M.focus_session_list()
  local layout = M.get_active_layout()
  if layout and layout.type == "manager" and layout.windows.left then
    return floating_window.focus_window(layout.windows.left.winid)
  end
  return false
end

function M.focus_preview_pane()
  local layout = M.get_active_layout()
  if layout and layout.type == "manager" and layout.windows.right then
    return floating_window.focus_window(layout.windows.right.winid)
  end
  return false
end

function M.resize_layout(layout_id, new_width, new_height)
  local layout = M.layouts[layout_id]
  if not layout then
    return false
  end
  
  if layout.type == "manager" and layout.windows then
    local left_width = math.floor(new_width * layout.config.left_pane_width)
    local right_width = new_width - left_width
    
    if layout.windows.left and layout.windows.left.winid then
      floating_window.resize_window(layout.windows.left.winid, left_width, new_height)
    end
    
    if layout.windows.right and layout.windows.right.winid then
      floating_window.resize_window(layout.windows.right.winid, right_width, new_height)
      local left_config = vim.api.nvim_win_get_config(layout.windows.left.winid)
      floating_window.move_window(layout.windows.right.winid, left_config.row, left_config.col + left_width)
    end
  elseif layout.type == "session" and layout.window_id then
    floating_window.resize_window(layout.window_id, new_width, new_height)
  end
  
  return true
end

function M.close_all_layouts()
  for layout_id in pairs(M.layouts) do
    M.close_layout(layout_id)
  end
end


return M
