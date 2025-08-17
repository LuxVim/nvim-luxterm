-- Optimized session list component with borders and highlighting
local M = {
  window_id = nil,
  buffer_id = nil,
  sessions_data = {},
  active_session_id = nil,
  selected_session_index = 1
}

-- Highlight groups setup
function M.setup_highlights()
  vim.api.nvim_set_hl(0, "LuxtermSessionIcon", {fg = "#ff7801"})
  vim.api.nvim_set_hl(0, "LuxtermSessionName", {fg = "#d4d4d4"})
  vim.api.nvim_set_hl(0, "LuxtermSessionKey", {fg = "#db2dee", bold = true})
  vim.api.nvim_set_hl(0, "LuxtermMenuIcon", {fg = "#4ec9b0"})
  vim.api.nvim_set_hl(0, "LuxtermMenuText", {fg = "#d4d4d4"})
  vim.api.nvim_set_hl(0, "LuxtermMenuKey", {fg = "#db2dee", bold = true})
  vim.api.nvim_set_hl(0, "LuxtermSessionSelected", {fg = "#FFA500", bold = true})
  vim.api.nvim_set_hl(0, "LuxtermSessionNormal", {fg = "#6B6B6B"})
end

function M.setup(opts)
  M.setup_highlights()
end

function M.setup_buffer_protection()
  if not M.buffer_id then return end
  
  -- Create autocmds to prevent any modification attempts
  local augroup = vim.api.nvim_create_augroup("LuxtermMainBufferProtection", {clear = true})
  
  -- Prevent insertion mode and any text modification
  vim.api.nvim_create_autocmd({"InsertEnter", "TextChanged", "TextChangedI", "TextChangedP"}, {
    group = augroup,
    buffer = M.buffer_id,
    callback = function()
      -- Silently force back to normal mode if in insert mode
      if vim.api.nvim_get_mode().mode:match("[iR]") then
        vim.cmd("stopinsert")
      end
      return true -- prevent the event
    end
  })
  
  -- Override common editing commands
  local opts = {noremap = true, silent = true, buffer = M.buffer_id}
  local protected_keys = {"i", "I", "a", "A", "o", "O", "c", "C", "s", "S", "x", "X", "d", "D", "p", "P"}
  
  for _, key in ipairs(protected_keys) do
    vim.keymap.set("n", key, function()
      -- Silently ignore editing attempts
    end, opts)
  end
  
  -- Protect against paste operations
  vim.keymap.set({"n", "v"}, "<C-v>", function()
    -- Silently ignore paste attempts
  end, opts)
end

function M.create_window(config)
  config = config or {}
  
  if M.window_id and vim.api.nvim_win_is_valid(M.window_id) then
    M.destroy()
  end
  
  -- Create buffer
  M.buffer_id = vim.api.nvim_create_buf(false, true)
  -- Set buffer options to make it non-editable
  vim.api.nvim_buf_set_option(M.buffer_id, "filetype", "luxterm_main")
  vim.api.nvim_buf_set_option(M.buffer_id, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(M.buffer_id, "swapfile", false)
  vim.api.nvim_buf_set_option(M.buffer_id, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M.buffer_id, "modifiable", false)
  
  -- Additional protection: prevent any modification attempts
  M.setup_buffer_protection()
  
  -- Calculate window size
  local width = math.floor(vim.o.columns * 0.4)
  local height = math.floor(vim.o.lines * 0.6)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Create window
  M.window_id = vim.api.nvim_open_win(M.buffer_id, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded",
    title = " Sessions ",
    title_pos = "center",
    style = "minimal"
  })
  
  -- Hide cursor in the window
  vim.api.nvim_win_set_option(M.window_id, "cursorline", false)
  vim.api.nvim_win_set_option(M.window_id, "cursorcolumn", false)
  -- Set cursor to invisible when in this window
  vim.api.nvim_create_autocmd("WinEnter", {
    buffer = M.buffer_id,
    callback = function()
      vim.opt.guicursor:append("a:hor1-Cursor/lCursor")
    end
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = M.buffer_id,
    callback = function()
      vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"
    end
  })
  
  M.setup_keymaps()
  M.setup_autocmds()
  
  return M.window_id, M.buffer_id
end

function M.destroy()
  if M.window_id and vim.api.nvim_win_is_valid(M.window_id) then
    vim.api.nvim_win_close(M.window_id, true)
  end
  M.window_id = nil
  M.buffer_id = nil
end

function M.update_sessions(sessions, active_session_id, preserve_selection_position)
  M.sessions_data = sessions or {}
  M.active_session_id = active_session_id
  
  -- Ensure valid selection
  if #M.sessions_data > 0 then
    -- Only jump to active session if we're not preserving selection position
    if M.active_session_id and not preserve_selection_position then
      for i, session in ipairs(M.sessions_data) do
        if session.id == M.active_session_id then
          M.selected_session_index = i
          break
        end
      end
    end
    M.selected_session_index = math.max(1, math.min(M.selected_session_index, #M.sessions_data))
  else
    M.selected_session_index = 1
  end
  
  M.render()
end

function M.render()
  if not M.window_id or not vim.api.nvim_win_is_valid(M.window_id) then
    return
  end
  
  local lines, highlights = M.generate_content()
  
  -- Temporarily enable modifiable to update content
  vim.api.nvim_buf_set_option(M.buffer_id, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.buffer_id, 0, -1, false, lines)
  -- Ensure buffer is locked again after content update
  vim.api.nvim_buf_set_option(M.buffer_id, "modifiable", false)
  
  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace("luxterm_session_list")
  vim.api.nvim_buf_clear_namespace(M.buffer_id, ns_id, 0, -1)
  
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(M.buffer_id, ns_id, hl.group, hl.line, hl.col_start, hl.col_end)
  end
end

function M.generate_content()
  local lines = {}
  local highlights = {}
  
  if #M.sessions_data == 0 then
    table.insert(lines, "  No sessions")
    table.insert(lines, "")
  else
    for i, session in ipairs(M.sessions_data) do
      M.add_session_content(lines, highlights, session, i)
    end
  end
  
  M.add_shortcuts_content(lines, highlights)
  
  return lines, highlights
end

function M.add_session_content(lines, highlights, session, index)
  local is_selected = index == M.selected_session_index
  local is_active = session.id == M.active_session_id
  
  -- Get session info
  local status_icon = M.get_status_icon(session)
  local name = M.truncate_name(session.name, 12)  -- Names are already limited to 12 chars
  local status_text = session:get_status()
  
  -- Use list position for hotkey (consistent with keymap behavior)
  local hotkey = string.format("[%d]", index)
  
  -- Add active indicator
  if is_active then
    status_text = status_text .. " (active)"
  end
  
  -- Create bordered box
  local status_display = status_icon .. " " .. status_text
  local hotkey_display = "Press " .. hotkey .. " to open"
  
  local max_width = math.max(
    vim.fn.strdisplaywidth(name),
    vim.fn.strdisplaywidth(status_display),
    vim.fn.strdisplaywidth(hotkey_display)
  )
  
  -- Choose border style based on selection
  local border_hl = is_selected and "LuxtermSessionSelected" or "LuxtermSessionNormal"
  
  -- Build bordered content
  local line_num = #lines
  local top_border = "  ╭ " .. name .. " " .. string.rep("─", max_width - vim.fn.strdisplaywidth(name)) .. "╮"
  local status_line = "  │ " .. status_display .. string.rep(" ", max_width - vim.fn.strdisplaywidth(status_display)) .. " │"
  local hotkey_line = "  │ " .. hotkey_display .. string.rep(" ", max_width - vim.fn.strdisplaywidth(hotkey_display)) .. " │"
  local bottom_border = "  ╰" .. string.rep("─", max_width + 2) .. "╯"
  
  -- Add lines
  table.insert(lines, top_border)
  table.insert(lines, status_line)
  table.insert(lines, hotkey_line)
  table.insert(lines, bottom_border)
  table.insert(lines, "")
  
  -- Add highlights
  for i = 0, 3 do
    table.insert(highlights, {
      line = line_num + i,
      col_start = 0,
      col_end = -1,
      group = border_hl
    })
  end
  
  -- Highlight session name
  table.insert(highlights, {
    line = line_num,
    col_start = 4,
    col_end = 4 + vim.fn.strdisplaywidth(name),
    group = "LuxtermSessionName"
  })
  
  -- Highlight status icon
  table.insert(highlights, {
    line = line_num + 1,
    col_start = 4,
    col_end = 4 + vim.fn.strdisplaywidth(status_icon),
    group = "LuxtermSessionIcon"
  })
  
  -- Highlight hotkey
  local key_pattern = "%[%d+%]"
  local _, key_end = string.find(hotkey_line, key_pattern)
  if key_end then
    local key_start = string.find(hotkey_line, key_pattern)
    table.insert(highlights, {
      line = line_num + 2,
      col_start = key_start - 1,
      col_end = key_end,
      group = "LuxtermSessionKey"
    })
  end
end

function M.add_shortcuts_content(lines, highlights)
  local shortcuts = {
    {icon = "󰷈", label = "New session", key = "[n]"},
    {icon = "󰆴", label = "Delete session", key = "[d]"},
    {icon = "󰑕", label = "Rename session", key = "[r]"},
    {icon = "󰅖", label = "Close", key = "[Esc]"}
  }
  
  if #M.sessions_data == 0 then
    shortcuts = {
      {icon = "󰷈", label = "New session", key = "[n]"},
      {icon = "󰅖", label = "Close", key = "[Esc]"}
    }
  end
  
  for _, item in ipairs(shortcuts) do
    local line_num = #lines
    local content = "  " .. item.icon .. "  " .. item.label
    local padding = string.rep(" ", 25 - vim.fn.strdisplaywidth(content))
    local full_line = content .. padding .. item.key
    
    table.insert(lines, full_line)
    
    -- Icon highlight
    table.insert(highlights, {
      line = line_num,
      col_start = 2,
      col_end = 2 + vim.fn.strdisplaywidth(item.icon),
      group = "LuxtermMenuIcon"
    })
    
    -- Text highlight
    table.insert(highlights, {
      line = line_num,
      col_start = 4 + vim.fn.strdisplaywidth(item.icon),
      col_end = 4 + vim.fn.strdisplaywidth(item.icon) + vim.fn.strdisplaywidth(item.label),
      group = "LuxtermMenuText"
    })
    
    -- Key highlight
    local key_start = vim.fn.strdisplaywidth(full_line) - vim.fn.strdisplaywidth(item.key)
    table.insert(highlights, {
      line = line_num,
      col_start = key_start,
      col_end = -1,
      group = "LuxtermMenuKey"
    })
  end
end

function M.get_status_icon(session)
  local status = session:get_status()
  if status == "running" then
    return "󰸞"
  elseif status == "stopped" then
    return "󰼭"
  else
    return "󰏢"
  end
end

function M.truncate_name(name, max_length)
  if vim.fn.strdisplaywidth(name) <= max_length then
    return name
  end
  return vim.fn.strchars(name, max_length - 3) .. "..."
end

function M.setup_keymaps()
  if not M.buffer_id then return end
  
  local opts = {noremap = true, silent = true, buffer = M.buffer_id}
  
  -- Session actions
  vim.keymap.set("n", "n", function() M.emit_action("new_session") end, opts)
  vim.keymap.set("n", "d", function() M.emit_action("delete_session") end, opts)
  vim.keymap.set("n", "r", function() M.emit_action("rename_session") end, opts)
  vim.keymap.set("n", "<Esc>", function() M.emit_action("close_manager") end, opts)
  vim.keymap.set("n", "<CR>", function() M.emit_action("open_session") end, opts)
  
  -- Navigation
  vim.keymap.set("n", "j", function() M.navigate("down") end, opts)
  vim.keymap.set("n", "k", function() M.navigate("up") end, opts)
  vim.keymap.set("n", "<Down>", function() M.navigate("down") end, opts)
  vim.keymap.set("n", "<Up>", function() M.navigate("up") end, opts)
  
  -- Number keys for direct selection by session number
  for i = 1, 9 do
    vim.keymap.set("n", tostring(i), function() 
      local session, index = M.get_session_by_number(i)
      if session then
        M.emit_action("select_session", {index = index}) 
      end
    end, opts)
  end
end

function M.setup_autocmds()
  if not M.window_id then return end
  
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(M.window_id),
    callback = function()
      M.destroy()
    end,
    once = true
  })
end

function M.navigate(direction)
  if #M.sessions_data == 0 then return end
  
  if direction == "down" then
    M.selected_session_index = (M.selected_session_index % #M.sessions_data) + 1
  elseif direction == "up" then
    M.selected_session_index = M.selected_session_index == 1 and #M.sessions_data or M.selected_session_index - 1
  end
  
  M.render()
  
  -- Emit selection change event to update preview
  M.emit_action("selection_changed", {
    session = M.get_selected_session(),
    index = M.selected_session_index
  })
end

function M.get_selected_session()
  if M.selected_session_index > 0 and M.selected_session_index <= #M.sessions_data then
    return M.sessions_data[M.selected_session_index]
  end
  return nil
end

function M.get_session_at_index(index)
  if index > 0 and index <= #M.sessions_data then
    return M.sessions_data[index]
  end
  return nil
end

function M.get_session_by_number(session_num)
  if session_num > 0 and session_num <= #M.sessions_data then
    return M.sessions_data[session_num], session_num
  end
  return nil, nil
end

function M.is_visible()
  return M.window_id and vim.api.nvim_win_is_valid(M.window_id)
end

-- Event emission for loose coupling
M.action_handlers = {}

function M.on_action(action_type, handler)
  M.action_handlers[action_type] = handler
end

function M.emit_action(action_type, payload)
  local handler = M.action_handlers[action_type]
  if handler then
    handler(payload)
  end
end

return M