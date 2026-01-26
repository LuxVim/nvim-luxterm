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
  pending_buffer_update = false,
  max_cache_entries = 10,
  cache_cleanup_threshold = 20
}


function M.setup(opts)
  highlights.setup_session_highlights()
end

function M.calculate_required_width()
  local min_width = 42

  local max_name_length = 0
  for _, session in ipairs(M.sessions_data) do
    local display_name = M.get_display_name(session)
    max_name_length = math.max(max_name_length, #display_name)
  end

  local content_width = 2 + 2 + math.min(max_name_length, 15) + 2 + 4 + 2 + 3 + 2

  return math.max(min_width, content_width)
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

function M.cleanup_all_caches()
  -- Clear all cached data to free memory
  M.cached_content = nil
  M.cached_highlights = nil
  M.content_cache_key = nil
  M.cached_width = nil
  M.cached_session_count = 0
  M.sessions_data = {}
  M.last_cursor_pos = nil
  
  -- Force garbage collection
  collectgarbage("collect")
end

function M.destroy()
  M.cleanup_keymaps()
  M.cleanup_all_caches()
  
  if utils.is_valid_window(M.window_id) then
    vim.api.nvim_win_close(M.window_id, true)
  end
  M.window_id = nil
  M.buffer_id = nil
  M.namespace_id = nil
  M.pending_buffer_update = false
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

function M.cleanup_cache_if_needed()
  -- If we have too many cached entries, clear cache to prevent memory bloat
  if #M.sessions_data > M.cache_cleanup_threshold then
    M.cached_content = nil
    M.cached_highlights = nil
    M.content_cache_key = nil
    M.cached_width = nil
    
    -- Force garbage collection
    collectgarbage("collect")
  end
end

function M.generate_content()
  local cache_key = generate_cache_key()
  if M.cached_content and M.cached_highlights and M.content_cache_key == cache_key then
    return M.cached_content, M.cached_highlights
  end

  M.cleanup_cache_if_needed()

  local lines = {}
  local highlights = {}
  local cfg = require("luxterm.config").get()

  if #M.sessions_data == 0 then
    table.insert(lines, "")
    table.insert(lines, "  No sessions")
    table.insert(lines, "")
    table.insert(highlights, {
      line = 1,
      col_start = 0,
      col_end = -1,
      group = "LuxtermPreviewEmpty"
    })
  else
    table.insert(lines, "")
    for i, session in ipairs(M.sessions_data) do
      M.add_session_content(lines, highlights, session, i, cfg)
    end
  end

  table.insert(lines, "")
  M.add_shortcuts_content(lines, highlights)

  if #M.sessions_data <= M.max_cache_entries then
    M.cached_content = lines
    M.cached_highlights = highlights
    M.content_cache_key = cache_key
  end

  return lines, highlights
end

function M.add_session_content(lines, highlights, session, index, config)
  local is_selected = index == M.selected_session_index
  local line_num = #lines

  local icon, icon_hl = M.get_status_icon_and_highlight(session, config)
  local display_name = M.get_display_name(session)
  local time_since = session:get_time_since_active()
  local hotkey = string.format("[%d]", index)

  if #display_name > 15 then
    display_name = display_name:sub(1, 12) .. "..."
  end

  local line = string.format("  %s %-15s %4s  %s", icon, display_name, time_since, hotkey)
  table.insert(lines, line)

  local icon_start = 2
  local icon_end = icon_start + #icon
  table.insert(highlights, {
    line = line_num,
    col_start = icon_start,
    col_end = icon_end,
    group = icon_hl
  })

  local name_col = 5
  local name_hl = is_selected and "LuxtermSelected" or "LuxtermSessionName"
  local fade_timeout = config.ui and config.ui.fade_timeout or 1800
  local diff_seconds = (vim.loop.now() - session.last_accessed) / 1000
  if diff_seconds > fade_timeout then
    name_hl = "LuxtermDimmed"
  end

  table.insert(highlights, {
    line = line_num,
    col_start = name_col,
    col_end = name_col + #display_name,
    group = name_hl
  })

  local time_col = 22
  table.insert(highlights, {
    line = line_num,
    col_start = time_col,
    col_end = time_col + #time_since,
    group = "LuxtermTime"
  })

  local hotkey_col = 28
  table.insert(highlights, {
    line = line_num,
    col_start = hotkey_col,
    col_end = -1,
    group = "LuxtermHotkey"
  })

  if is_selected then
    table.insert(highlights, {
      line = line_num,
      col_start = 0,
      col_end = -1,
      group = "LuxtermSelected",
      priority = 50
    })
  end
end

function M.add_shortcuts_content(lines, highlights)
  local line_num = #lines

  table.insert(lines, string.rep("─", 40))
  table.insert(highlights, {
    line = line_num,
    col_start = 0,
    col_end = -1,
    group = "LuxtermSeparator"
  })

  line_num = #lines

  local shortcuts
  if #M.sessions_data == 0 then
    shortcuts = "[n]ew  [Esc] close"
  else
    shortcuts = "[n]ew  [d]el  [r]ename  [p]review  [1-9] jump  [Esc]"
  end

  local status_line = " " .. shortcuts
  table.insert(lines, status_line)

  local pos = 1
  for key, label in shortcuts:gmatch("%[([^%]]+)%]([^%[]*)") do
    local key_str = "[" .. key .. "]"
    local key_start = status_line:find(key_str, pos, true)
    if key_start then
      table.insert(highlights, {
        line = line_num,
        col_start = key_start - 1,
        col_end = key_start - 1 + #key_str,
        group = "LuxtermKey"
      })

      local label_start = key_start + #key_str
      local label_trimmed = label:match("^%s*(%S*)") or ""
      if #label_trimmed > 0 then
        table.insert(highlights, {
          line = line_num,
          col_start = label_start - 1,
          col_end = label_start - 1 + #label + 1,
          group = "LuxtermKeyLabel"
        })
      end

      pos = key_start + #key_str
    end
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

function M.get_status_icon_and_highlight(session, config)
  local process, process_status = session:get_process()
  local stale_timeout = config.ui and config.ui.stale_timeout or 300
  local fade_timeout = config.ui and config.ui.fade_timeout or 1800

  local diff_seconds = (vim.loop.now() - session.last_accessed) / 1000

  if session:get_status() == "stopped" then
    return "○", "LuxtermStatusStopped"
  elseif process_status == "running" then
    if diff_seconds > stale_timeout then
      return "◐", "LuxtermStatusStale"
    else
      return "●", "LuxtermStatusActive"
    end
  else
    if diff_seconds > fade_timeout then
      return "○", "LuxtermDimmed"
    elseif diff_seconds > stale_timeout then
      return "◐", "LuxtermStatusStale"
    else
      return "●", "LuxtermStatusActive"
    end
  end
end

function M.get_display_name(session)
  local process, _ = session:get_process()
  if process then
    return process
  end

  local cwd = session:get_cwd()
  if cwd then
    local basename = vim.fn.fnamemodify(cwd, ":t")
    if basename and basename ~= "" then
      return basename
    end
  end

  return session.name
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
