-- Optimized session list component with borders and highlighting
local highlights = require("luxterm.ui.highlights")
local floating_window = require("luxterm.ui.floating_window")
local buffer_protection = require("luxterm.ui.buffer_protection")
local utils = require("luxterm.utils")

local M = {
  window_id = nil,
  buffer_id = nil,
  sessions_data = {},
  active_session_id = nil,
  selected_session_index = 1,
  cached_width = nil,
  cached_session_count = 0,
  cached_content = nil,
  cached_highlights = nil,
  content_cache_key = nil,
  keymap_handlers = {},
  namespace_id = nil,
  last_cursor_pos = nil,
  pending_buffer_update = false
}


function M.setup(opts)
  highlights.setup_session_highlights()
end

function M.calculate_required_width()
  local session_count = #M.sessions_data
  if M.cached_width and M.cached_session_count == session_count then
    return M.cached_width
  end
  
  -- Calculate width based on shortcuts content with 2 chars padding after "[Esc]"
  local shortcuts = {
    {icon = "󰷈", label = "New session", key = "[n]"},
    {icon = "󰆴", label = "Delete session", key = "[d]"},
    {icon = "󰑕", label = "Rename session", key = "[r]"},
    {icon = "󰅖", label = "Close", key = "[Esc]"}
  }
  
  -- If no sessions, use minimal shortcuts
  if session_count == 0 then
    shortcuts = {
      {icon = "󰷈", label = "New session", key = "[n]"},
      {icon = "󰅖", label = "Close", key = "[Esc]"}
    }
  end
  
  local max_width = 0
  for _, item in ipairs(shortcuts) do
    local content = "  " .. item.icon .. "  " .. item.label
    local content_width = vim.fn.strdisplaywidth(content)
    local key_width = vim.fn.strdisplaywidth(item.key)
    local total_width = content_width + key_width + 2  -- 2 chars padding after key
    max_width = math.max(max_width, total_width)
  end
  
  -- Add some minimum width and ensure it's reasonable
  local calculated_width = math.max(max_width, 30)
  
  M.cached_width = calculated_width
  M.cached_session_count = session_count
  
  return calculated_width
end


function M.create_window(config)
  config = config or {}
  
  if M.window_id and vim.api.nvim_win_is_valid(M.window_id) then
    M.destroy()
  end
  
  -- Calculate dynamic window width based on content
  local content_width = M.calculate_required_width()
  local width = config.width or content_width
  local height = config.height or select(2, utils.calculate_size_from_ratio(0.25, 0.6))
  local row = config.row or utils.calculate_centered_position(width, height)
  local col = config.col or select(2, utils.calculate_centered_position(width, height))
  
  -- Use the unified window factory with auto-hide config passed through
  M.window_id, M.buffer_id = floating_window.create_typed_window("session_list", {
    width = width,
    height = height,
    row = row,
    col = col,
    enter = true,
    auto_hide = config.auto_hide,
    auto_hide_callback = config.auto_hide_callback
  })
  
  M.setup_keymaps()
  M.setup_autocmds()
  
  return M.window_id, M.buffer_id
end

function M.cleanup_keymaps()
  if M.buffer_id then
    for keymap_spec, _ in pairs(M.keymap_handlers) do
      local mode, key = keymap_spec:match("(%w+):(.+)")
      if mode and key then
        pcall(vim.keymap.del, mode, key, {buffer = M.buffer_id})
      end
    end
    M.keymap_handlers = {}
  end
end

function M.destroy()
  M.cleanup_keymaps()
  
  if utils.is_valid_window(M.window_id) then
    vim.api.nvim_win_close(M.window_id, true)
  end
  M.window_id = nil
  M.buffer_id = nil
end

function M.update_sessions(sessions, active_session_id, preserve_selection_position)
  M.sessions_data = sessions or {}
  M.active_session_id = active_session_id
  
  if #M.sessions_data ~= M.cached_session_count then
    M.cached_width = nil
    M.cached_content = nil
    M.cached_highlights = nil 
    M.content_cache_key = nil
  end
  
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

function M.preserve_cursor_position()
  if utils.is_valid_window(M.window_id) then
    M.last_cursor_pos = vim.api.nvim_win_get_cursor(M.window_id)
  end
end

function M.restore_cursor_position()
  if M.last_cursor_pos and utils.is_valid_window(M.window_id) then
    pcall(vim.api.nvim_win_set_cursor, M.window_id, M.last_cursor_pos)
  end
end

function M.apply_highlights_batch(highlights)
  local ns_id = vim.api.nvim_create_namespace("luxterm_session_list")
  vim.api.nvim_buf_clear_namespace(M.buffer_id, ns_id, 0, -1)
  
  -- Use the original highlighting approach that was working
  for _, hl in ipairs(highlights) do
    if hl.priority then
      -- Use extmark for priority control (this was working before)
      vim.api.nvim_buf_set_extmark(M.buffer_id, ns_id, hl.line, hl.col_start, {
        end_col = hl.col_end == -1 and nil or hl.col_end,
        end_line = hl.line,
        hl_group = hl.group,
        priority = hl.priority
      })
    else
      -- Use regular highlight for non-priority items (this was working before)
      vim.api.nvim_buf_add_highlight(M.buffer_id, ns_id, hl.group, hl.line, hl.col_start, hl.col_end)
    end
  end
end

function M.update_buffer_differential(lines)
  if not M.buffer_id or M.pending_buffer_update then
    return
  end
  
  M.pending_buffer_update = true
  
  -- Get current buffer lines
  local current_lines = vim.api.nvim_buf_get_lines(M.buffer_id, 0, -1, false)
  
  -- Only update if content actually changed
  local content_changed = false
  if #current_lines ~= #lines then
    content_changed = true
  else
    for i, line in ipairs(lines) do
      if current_lines[i] ~= line then
        content_changed = true
        break
      end
    end
  end
  
  if content_changed then
    M.preserve_cursor_position()
    buffer_protection.update_protected_buffer_content(M.buffer_id, lines)
    vim.schedule(function()
      M.restore_cursor_position()
      M.pending_buffer_update = false
    end)
  else
    M.pending_buffer_update = false
  end
end

function M.render()
  if not utils.is_valid_window(M.window_id) then
    return
  end
  
  local lines, highlights = M.generate_content()
  
  -- Use differential buffer updates
  M.update_buffer_differential(lines)
  
  -- Apply highlights in batch
  M.apply_highlights_batch(highlights)
end

local function generate_cache_key()
  local session_ids = {}
  for i, session in ipairs(M.sessions_data) do
    table.insert(session_ids, session.id .. ":" .. session.name .. ":" .. session:get_status())
  end
  return table.concat(session_ids, "|") .. "|" .. (M.active_session_id or "") .. "|" .. M.selected_session_index
end

function M.generate_content()
  local cache_key = generate_cache_key()
  if M.cached_content and M.cached_highlights and M.content_cache_key == cache_key then
    return M.cached_content, M.cached_highlights
  end
  
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
  
  table.insert(lines, "")
  table.insert(lines, "")
   M.add_shortcuts_content(lines, highlights)
  
  M.cached_content = lines
  M.cached_highlights = highlights
  M.content_cache_key = cache_key
  
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
  
  
  -- Create bordered box
  local status_display = status_icon .. " " .. status_text
  local hotkey_display = "Press " .. hotkey .. " to open"
  
  local max_width = math.max(
    vim.fn.strdisplaywidth(name),
    vim.fn.strdisplaywidth(status_display),
    vim.fn.strdisplaywidth(hotkey_display)
  )
  
  -- Choose border style based on selection
  local border_hl = is_selected and "LuxtermBorderSelected" or "LuxtermBorderNormal"
  
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
  
  -- Calculate byte positions for highlighting
  -- "  ╭ " = 2 spaces + ╭ (3 bytes) + 1 space = 6 bytes total
  local prefix = "  ╭ "
  local prefix_bytes = string.len(prefix)  -- This gives us the byte count
  local name_bytes = string.len(name)
  
  -- Highlight session name with HIGH priority to ensure it takes precedence
  local name_hl_group = is_selected and "LuxtermSessionNameSelected" or "LuxtermSessionName"
  table.insert(highlights, {
    line = line_num,
    col_start = prefix_bytes,  -- Start after the prefix
    col_end = prefix_bytes + name_bytes,  -- End after the name
    group = name_hl_group,
    priority = 100  -- High priority to override border highlights
  })
  
  -- Add border highlights (only the actual border characters, not the content)
  -- Top border: highlight the box drawing characters and padding
  table.insert(highlights, {
    line = line_num,
    col_start = 0,
    col_end = prefix_bytes,  -- Just the prefix part
    group = border_hl
  })
  -- Highlight the border after the name (space + border chars)
  table.insert(highlights, {
    line = line_num,
    col_start = prefix_bytes + name_bytes + 1,  -- After prefix + name + space
    col_end = -1,  -- Rest of the border
    group = border_hl
  })
  
  -- Middle lines: highlight the border characters only
  local side_prefix = "  │ "  -- 2 spaces + │ (3 bytes) + 1 space = 6 bytes
  local side_prefix_bytes = string.len(side_prefix)
  local side_suffix = " │"  -- 1 space + │ (3 bytes) = 4 bytes
  local side_suffix_bytes = string.len(side_suffix)
  
  for i = 1, 2 do
    local current_line_idx = line_num + i + 1  -- lines array index for the current line being highlighted
    table.insert(highlights, {
      line = line_num + i,
      col_start = 0,
      col_end = side_prefix_bytes,  -- Just the "  │ " part
      group = border_hl
    })
    table.insert(highlights, {
      line = line_num + i,
      col_start = string.len(lines[current_line_idx]) - side_suffix_bytes,  -- Just the ending " │"
      col_end = -1,
      group = border_hl
    })
  end
  
  -- Bottom border: highlight entire line
  table.insert(highlights, {
    line = line_num + 3,
    col_start = 0,
    col_end = -1,
    group = border_hl
  })
  
  -- Highlight status icon (orange when selected, default otherwise)
  local icon_hl_group = is_selected and "LuxtermSessionIconSelected" or "LuxtermSessionIcon"
  local status_icon_bytes = string.len(status_icon)
  table.insert(highlights, {
    line = line_num + 1,
    col_start = side_prefix_bytes,
    col_end = side_prefix_bytes + status_icon_bytes,
    group = icon_hl_group
  })
  
  -- Highlight status text (orange when selected, gray otherwise)
  local status_text_hl = is_selected and "LuxtermSessionSelected" or "LuxtermSessionNormal"
  table.insert(highlights, {
    line = line_num + 1,
    col_start = side_prefix_bytes + status_icon_bytes + 1,  -- After icon + space
    col_end = string.len(lines[line_num + 2]) - side_suffix_bytes,  -- Up to the border
    group = status_text_hl
  })
  
  -- Highlight hotkey line text (orange when selected, gray otherwise)
  local hotkey_text_hl = is_selected and "LuxtermSessionSelected" or "LuxtermSessionNormal"
  local key_pattern = "%[%d+%]"
  local key_start_pos = string.find(hotkey_line, key_pattern)
  if key_start_pos then
    -- Highlight "Press " part (accounting for the prefix)
    table.insert(highlights, {
      line = line_num + 2,
      col_start = side_prefix_bytes,
      col_end = key_start_pos - 1,  -- Up to the key
      group = hotkey_text_hl
    })
    
    -- Highlight the key itself (always purple)
    local _, key_end = string.find(hotkey_line, key_pattern)
    table.insert(highlights, {
      line = line_num + 2,
      col_start = key_start_pos - 1,
      col_end = key_end,
      group = "LuxtermSessionKey"
    })
    
    -- Highlight " to open" part
    table.insert(highlights, {
      line = line_num + 2,
      col_start = key_end,
      col_end = string.len(lines[line_num + 3]) - side_suffix_bytes,  -- Up to the border
      group = hotkey_text_hl
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
  
  -- Calculate dynamic width for consistent spacing
  local required_width = M.calculate_required_width()
  
  for _, item in ipairs(shortcuts) do
    local line_num = #lines
    local content = "  " .. item.icon .. "  " .. item.label
    local content_width = vim.fn.strdisplaywidth(content)
    local key_width = vim.fn.strdisplaywidth(item.key)
    local padding_needed = required_width - content_width - key_width
    local padding = string.rep(" ", padding_needed)
    local full_line = content .. padding .. item.key
    
    table.insert(lines, full_line)
    
    -- Icon highlight (use byte length for col_end)
    local icon_bytes = string.len(item.icon)
    table.insert(highlights, {
      line = line_num,
      col_start = 2,
      col_end = 2 + icon_bytes,
      group = "LuxtermMenuIcon"
    })
    
    -- Text highlight (use byte lengths for accurate positioning)
    local label_bytes = string.len(item.label)
    table.insert(highlights, {
      line = line_num,
      col_start = 4 + icon_bytes,
      col_end = 4 + icon_bytes + label_bytes,
      group = "LuxtermMenuText"
    })
    
    -- Key highlight (calculate byte position properly)
    local key_bytes = string.len(item.key)
    local key_start = string.len(full_line) - key_bytes
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
  
  -- Batch all keymap setups to reduce API calls
  local keymaps = {
    -- Session actions
    {"n", "n", function() M.emit_action("new_session") end},
    {"n", "d", function() M.emit_action("delete_session") end},
    {"n", "r", function() M.emit_action("rename_session") end},
    {"n", "<Esc>", function() M.emit_action("close_manager") end},
    {"n", "<CR>", function() M.emit_action("open_session") end},
    -- Navigation
    {"n", "j", function() M.navigate("down") end},
    {"n", "k", function() M.navigate("up") end},
    {"n", "<Down>", function() M.navigate("down") end},
    {"n", "<Up>", function() M.navigate("up") end}
  }
  
  -- Add number keys for direct selection
  for i = 1, 9 do
    table.insert(keymaps, {"n", tostring(i), function() 
      local session, index = M.get_session_by_number(i)
      if session then
        M.emit_action("select_session", {index = index}) 
      end
    end})
  end
  
  -- Apply all keymaps in batch
  for _, keymap in ipairs(keymaps) do
    vim.keymap.set(keymap[1], keymap[2], keymap[3], opts)
    -- Track keymaps for cleanup
    local keymap_spec = keymap[1] .. ":" .. keymap[2]
    M.keymap_handlers[keymap_spec] = true
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
  return utils.is_valid_window(M.window_id)
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
