local config = require("luxterm.config")
local state = require("luxterm.state")
local sessions = require("luxterm.sessions")
local keymaps = require("luxterm.keymaps")
local cache = require("luxterm.cache")

local M = {}

--- Open the manager floating window with split layout
function M.open_manager()
  if state.is_manager_open() then
    return
  end
  
  -- Close any luxdash windows/buffers before opening manager
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == 'luxdash' then
        -- Try to close the luxdash window/buffer
        if vim.api.nvim_win_get_config(win).relative == "" then -- main window
          -- Create a new empty buffer and switch to it
          local empty_buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_buf_set_option(empty_buf, 'buftype', 'nofile')
          vim.api.nvim_win_set_buf(win, empty_buf)
        end
      end
    end
  end

  local total_width = math.floor(vim.o.columns * config.options.manager_width)
  local total_height = math.floor(vim.o.lines * config.options.manager_height)
  local row = math.floor((vim.o.lines - total_height) / 2)
  local col = math.floor((vim.o.columns - total_width) / 2)

  local left_width = math.floor(total_width * 0.3)
  local right_width = total_width - left_width

  local left_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(left_buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(left_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(left_buf, 'swapfile', false)

  local right_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(right_buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(right_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(right_buf, 'swapfile', false)
  
  -- Fill buffers with content immediately to prevent transparency issues
  vim.api.nvim_buf_set_option(left_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(left_buf, 0, -1, false, {"", "  Loading sessions...", ""})
  vim.api.nvim_buf_set_option(left_buf, 'modifiable', false)
  
  vim.api.nvim_buf_set_option(right_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(right_buf, 0, -1, false, {"", "  Loading preview...", ""})
  vim.api.nvim_buf_set_option(right_buf, 'modifiable', false)
  

  local left_win = vim.api.nvim_open_win(left_buf, true, {
    relative = "editor",
    width = left_width,
    height = total_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Sessions ",
    title_pos = "center",
    zindex = 50,
  })

  local right_win = vim.api.nvim_open_win(right_buf, false, {
    relative = "editor",
    width = right_width,
    height = total_height,
    row = row,
    col = col + left_width,
    style = "minimal",
    border = "rounded",
    title = " Preview ",
    title_pos = "center",
    zindex = 50,
  })
  
  -- Set window-local highlights to ensure opaque background
  vim.api.nvim_win_set_option(left_win, 'winhighlight', 'Normal:Normal,FloatBorder:FloatBorder')
  vim.api.nvim_win_set_option(right_win, 'winhighlight', 'Normal:Normal,FloatBorder:FloatBorder')

  state.set_windows(nil, left_win, right_win)
  state.set_manager_open(true)
  
  -- Ensure we focus the left window immediately after creation
  vim.api.nvim_set_current_win(left_win)
  
  local ui_callbacks = {
    create_new_session = M.create_new_session,
    close_manager = M.close_manager,
    delete_active_session = M.delete_active_session,
    select_session = M.select_session,
    navigate_to_session = M.navigate_to_session,
    render_manager = M.render_manager
  }
  
  keymaps.set_manager_keymaps(left_buf, ui_callbacks)
  
  -- Clean up any invalid sessions before displaying
  sessions.remove_closed_terminals()
  
  -- If there are sessions but no active session, set the first one as active
  local session_list = sessions.get_sessions()
  local active_session_id = state.get_active_session()
  if #session_list > 0 and not active_session_id then
    state.set_active_session(session_list[1].id)
  end
  
  -- Render content before setting up focus management
  M.render_manager()
  
  -- Set up focus management after everything is rendered
  vim.schedule(function()
    M.setup_focus_management()
    M.setup_preview_refresh()
  end)
end

--- Close the manager floating window
function M.close_manager()
  local windows = state.get_windows()
  
  if windows.left_pane and vim.api.nvim_win_is_valid(windows.left_pane) then
    vim.api.nvim_win_close(windows.left_pane, true)
  end
  
  if windows.right_pane and vim.api.nvim_win_is_valid(windows.right_pane) then
    vim.api.nvim_win_close(windows.right_pane, true)
  end
  
  state.clear_windows()
  state.set_manager_open(false)
  
  -- Emit event for cleanup
  vim.api.nvim_exec_autocmds("User", { pattern = "LuxtermManagerClosed" })
end

--- Render the manager UI with caching and lazy updates
function M.render_manager()
  if not state.is_manager_open() then
    return
  end

  -- Always render both panes for now to ensure they display correctly
  M.render_session_list()
  M.render_preview()
  
  cache.cleanup_old_entries()
end

--- Render the session list in the left pane with caching
function M.render_session_list()
  local windows = state.get_windows()
  if not windows.left_pane or not vim.api.nvim_win_is_valid(windows.left_pane) then
    return
  end

  local left_buf = vim.api.nvim_win_get_buf(windows.left_pane)
  vim.api.nvim_buf_set_option(left_buf, 'modifiable', true)
  
  local session_list = sessions.get_sessions()
  local active_session_id = state.get_active_session()
  
  local lines = cache.get_rendered_session_list(session_list, active_session_id, function()
    local render_lines = {}
    
    if #session_list == 0 then
      table.insert(render_lines, "")
      table.insert(render_lines, "  No sessions")
      table.insert(render_lines, "")
      table.insert(render_lines, "➕ New session              [n]")
      table.insert(render_lines, "")
      table.insert(render_lines, "🚪 Close                    [Esc]")
    else
      table.insert(render_lines, "")
      for i, session in ipairs(session_list) do
        local prefix = session.id == active_session_id and "► " or "  "
        local line = string.format("%s🖥️ %-20s [%d]", prefix, session.name, i)
        table.insert(render_lines, line)
      end
      table.insert(render_lines, "")
      table.insert(render_lines, "➕ New session              [n]")
      table.insert(render_lines, "🗑️ Delete session           [d]")
      table.insert(render_lines, "✏️ Rename session           [r]")
      table.insert(render_lines, "")
      table.insert(render_lines, "🚪 Close                    [Esc]")
    end
    
    return render_lines
  end)

  vim.api.nvim_buf_set_lines(left_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(left_buf, 'modifiable', false)
end

--- Extract content from terminal buffer for preview
-- @param bufnr number Terminal buffer number
-- @param max_lines number Maximum lines to extract
-- @return table Lines from terminal buffer
local function get_terminal_content(bufnr, max_lines)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= 'terminal' then
    return {"[Invalid terminal buffer]"}
  end
  
  max_lines = max_lines or 50
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  
  -- Filter out empty lines at the end and keep only last N lines
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end
  
  if #lines > max_lines then
    lines = vim.list_slice(lines, #lines - max_lines + 1, #lines)
  end
  
  -- Clean up lines: remove terminal escape sequences and control characters
  local cleaned_lines = {}
  for _, line in ipairs(lines) do
    -- Remove ANSI escape sequences (basic cleanup)
    local cleaned = line:gsub("\27%[[%d;]*[mK]", "")
    -- Remove other control characters except tab
    cleaned = cleaned:gsub("[\1-\8\11\12\14-\31\127]", "")
    table.insert(cleaned_lines, cleaned)
  end
  
  return cleaned_lines
end

--- Render the preview in the right pane with caching and lazy updates
function M.render_preview()
  local windows = state.get_windows()
  if not windows.right_pane or not vim.api.nvim_win_is_valid(windows.right_pane) then
    return
  end

  if not config.options.preview_enabled then
    return
  end

  local right_buf = vim.api.nvim_win_get_buf(windows.right_pane)
  vim.api.nvim_buf_set_option(right_buf, 'modifiable', true)
  
  local active_session = sessions.get_active_session()
  
  if not active_session or not vim.api.nvim_buf_is_valid(active_session.bufnr) then
    local lines = {
      "",
      "  No active session",
      "",
      "  Select a session to see preview"
    }
    vim.api.nvim_buf_set_lines(right_buf, 0, -1, false, lines)
  else
    local preview_lines = cache.get_rendered_preview(active_session.id, active_session.bufnr, function()
      local lines = {}
      
      -- Show session header
      table.insert(lines, "")
      table.insert(lines, "  ╭─ " .. active_session.name .. " ─╮")
      table.insert(lines, "  │")
      
      -- Check if terminal is running
      local terminal_job_id = nil
      local status_ok, job_id = pcall(vim.api.nvim_buf_get_var, active_session.bufnr, 'terminal_job_id')
      if status_ok then
        terminal_job_id = job_id
      end
      
      if terminal_job_id and terminal_job_id > 0 then
        table.insert(lines, "  │  Status: Running")
      else
        table.insert(lines, "  │  Status: Not running")
      end
      
      table.insert(lines, "  │")
      table.insert(lines, "  ╰─" .. string.rep("─", #active_session.name) .. "─╯")
      table.insert(lines, "")
      
      -- Get terminal content
      local win_height = vim.api.nvim_win_get_height(windows.right_pane)
      local available_lines = win_height - #lines - 3 -- Leave space for header and footer
      local terminal_lines = get_terminal_content(active_session.bufnr, available_lines)
      
      if #terminal_lines == 0 or (#terminal_lines == 1 and terminal_lines[1] == "") then
        table.insert(lines, "  [Empty terminal]")
      else
        -- Add terminal content with proper indentation
        for _, line in ipairs(terminal_lines) do
          -- Ensure the line doesn't exceed window width
          local max_width = vim.api.nvim_win_get_width(windows.right_pane) - 4
          if #line > max_width then
            line = line:sub(1, max_width - 3) .. "..."
          end
          table.insert(lines, "  " .. line)
        end
      end
      
      table.insert(lines, "")
      table.insert(lines, "  Press <Enter> to open • 'd' to delete")
      
      return lines
    end)
    
    vim.api.nvim_buf_set_lines(right_buf, 0, -1, false, preview_lines)
  end
  
  vim.api.nvim_buf_set_option(right_buf, 'modifiable', false)
end

--- Select a session by index (1-based) and open it in floating window
function M.select_session(index)
  local session_list = sessions.get_sessions()
  if index <= #session_list then
    local session = session_list[index]
    state.set_active_session(session.id)
    
    -- Close manager and open session in floating window
    M.close_manager()
    M.open_session_window(session)
  end
end

--- Navigate to a session by index (1-based) but keep manager open
function M.navigate_to_session(index)
  local session_list = sessions.get_sessions()
  if index > 0 and index <= #session_list then
    local session = session_list[index]
    state.set_active_session(session.id)
    
    -- Force cache invalidation to ensure preview updates with fresh content
    cache.invalidate()
    
    -- Only update the preview, don't close manager
    M.render_manager()
  end
end

--- Create a new session from the manager
function M.create_new_session()
  -- Create session with floating window behavior (close manager, open in floating window)
  sessions.create_session(nil, true)
  cache.invalidate_session_list()
end

--- Delete the active session
function M.delete_active_session()
  local active_session = sessions.get_active_session()
  if active_session then
    sessions.remove_session(active_session.id)
    cache.invalidate()
    M.render_manager()
  end
end

--- Setup preview refresh to update terminal content regularly
function M.setup_preview_refresh()
  if not state.is_manager_open() then
    return
  end
  
  local last_content_hash = nil
  
  -- Create a timer to refresh preview every 1 second
  local refresh_timer = vim.loop.new_timer()
  if not refresh_timer then
    return
  end
  
  refresh_timer:start(1000, 1000, vim.schedule_wrap(function()
    if not state.is_manager_open() then
      refresh_timer:stop()
      refresh_timer:close()
      return
    end
    
    local active_session = sessions.get_active_session()
    if active_session and vim.api.nvim_buf_is_valid(active_session.bufnr) then
      -- Only refresh if content has actually changed
      local current_hash = cache.hash_terminal_content(active_session.bufnr)
      if current_hash ~= last_content_hash then
        last_content_hash = current_hash
        M.render_preview()
      end
    end
  end))
  
  -- Clean up timer when manager closes
  vim.api.nvim_create_autocmd("User", {
    pattern = "LuxtermManagerClosed",
    callback = function()
      if refresh_timer then
        refresh_timer:stop()
        refresh_timer:close()
      end
    end,
    once = true
  })
end

--- Setup focus management to keep focus within manager
function M.setup_focus_management()
  if not state.is_manager_open() then
    return
  end

  local windows = state.get_windows()
  if not windows.left_pane or not vim.api.nvim_win_is_valid(windows.left_pane) then
    return
  end
  
  local manager_buffers = {}
  
  if windows.left_pane then
    manager_buffers[vim.api.nvim_win_get_buf(windows.left_pane)] = windows.left_pane
  end
  
  if windows.right_pane then
    manager_buffers[vim.api.nvim_win_get_buf(windows.right_pane)] = windows.right_pane
  end

  -- Ensure initial focus is on the left pane
  vim.api.nvim_set_current_win(windows.left_pane)

  local focus_autocmd = vim.api.nvim_create_autocmd({"WinEnter", "BufEnter"}, {
    callback = function()
      if not state.is_manager_open() then
        if focus_autocmd then
          vim.api.nvim_del_autocmd(focus_autocmd)
        end
        return
      end
      
      local current_buf = vim.api.nvim_get_current_buf()
      local current_win = vim.api.nvim_get_current_win()
      
      -- Only redirect focus if we're not already in a manager window
      if not manager_buffers[current_buf] and current_win ~= windows.left_pane and current_win ~= windows.right_pane then
        if windows.left_pane and vim.api.nvim_win_is_valid(windows.left_pane) then
          vim.api.nvim_set_current_win(windows.left_pane)
        end
      end
    end
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(windows.left_pane),
    callback = function()
      M.close_manager()
      if focus_autocmd then
        vim.api.nvim_del_autocmd(focus_autocmd)
      end
    end,
    once = true
  })
end

--- Open a terminal session in its own floating window
function M.open_session_window(session)
  if not session or not vim.api.nvim_buf_is_valid(session.bufnr) then
    return nil
  end

  -- Use same dimensions as manager window
  local total_width = math.floor(vim.o.columns * config.options.manager_width)
  local total_height = math.floor(vim.o.lines * config.options.manager_height)
  local row = math.floor((vim.o.lines - total_height) / 2)
  local col = math.floor((vim.o.columns - total_width) / 2)

  local session_win = vim.api.nvim_open_win(session.bufnr, true, {
    relative = "editor",
    width = total_width,
    height = total_height,
    row = row,
    col = col,
    style = "minimal",
    border = config.options.border,
    title = " " .. session.name .. " ",
    title_pos = "center",
    zindex = 100,  -- Always display floating terminal on top
  })

  -- Store the session window in state
  state.set_windows(session_win, nil, nil)
  
  -- Set up keymaps for the session window
  keymaps.set_session_window_keymaps(session.bufnr)
  
  -- Enter terminal mode automatically
  vim.cmd("startinsert")
  
  return session_win
end

--- Close session floating window
function M.close_session_window()
  local windows = state.get_windows()
  
  if windows.manager and vim.api.nvim_win_is_valid(windows.manager) then
    vim.api.nvim_win_close(windows.manager, true)
  end
  
  state.clear_windows()
end

return M
