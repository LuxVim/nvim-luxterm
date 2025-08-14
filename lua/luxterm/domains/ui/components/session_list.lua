local floating_window = require("luxterm.domains.ui.components.floating_window")
local cache_coordinator = require("luxterm.infrastructure.cache.cache_coordinator")
local event_bus = require("luxterm.infrastructure.events.event_bus")
local event_types = require("luxterm.infrastructure.events.event_types")

local M = {
  window_id = nil,
  buffer_id = nil,
  sessions_data = {},
  active_session_id = nil,
  render_config = {
    show_status = true,
    show_shortcuts = true,
    max_name_length = 20
  }
}

function M.setup(opts)
  opts = opts or {}
  M.render_config = vim.tbl_deep_extend("force", M.render_config, opts.render_config or {})
  
  cache_coordinator.register_cache_layer("session_list", require("luxterm.infrastructure.cache.render_cache"))
  cache_coordinator.register_invalidation_rule(event_types.SESSION_CREATED, {"session_list"})
  cache_coordinator.register_invalidation_rule(event_types.SESSION_DELETED, {"session_list"})
  cache_coordinator.register_invalidation_rule(event_types.SESSION_RENAMED, {"session_list"})
  cache_coordinator.register_invalidation_rule(event_types.SESSION_SWITCHED, {"session_list"})
end

function M.create(config)
  if M.window_id and vim.api.nvim_win_is_valid(M.window_id) then
    M.destroy()
  end
  
  local window_config = vim.tbl_deep_extend("force", {
    title = " Sessions ",
    title_pos = "center",
    enter = true,
    buffer_options = {
      filetype = "luxterm-sessions"
    },
    on_create = function(winid, bufnr)
      M.window_id = winid
      M.buffer_id = bufnr
      M._setup_keymaps()
    end,
    on_close = function()
      M.window_id = nil
      M.buffer_id = nil
    end
  }, config or {})
  
  return floating_window.create_window(window_config)
end

function M.destroy()
  if M.window_id then
    floating_window.close_window(M.window_id)
    M.window_id = nil
    M.buffer_id = nil
  end
end

function M.update_sessions(sessions, active_session_id)
  M.sessions_data = sessions or {}
  M.active_session_id = active_session_id
  
  
  M.render()
end

function M.render()
  if not M.window_id or not vim.api.nvim_win_is_valid(M.window_id) then
    return false
  end
  
  local cache_key = M._generate_cache_key()
  local lines = cache_coordinator.get_from_cache("session_list", cache_key, function()
    return M._generate_content()
  end)
  
  
  floating_window.update_window_content(M.window_id, lines)
  return true
end

function M._generate_cache_key()
  local session_ids = {}
  for _, session in ipairs(M.sessions_data) do
    table.insert(session_ids, session.id .. ":" .. session.name)
  end
  return "session_list_" .. table.concat(session_ids, "|") .. "_" .. (M.active_session_id or "none")
end

function M._generate_content()
  local lines = {}
  
  if #M.sessions_data == 0 then
    M._add_empty_state_content(lines)
  else
    M._add_session_list_content(lines)
  end
  
  if M.render_config.show_shortcuts then
    M._add_shortcuts_content(lines)
  end
  
  return lines
end

function M._add_empty_state_content(lines)
  table.insert(lines, "")
  table.insert(lines, "  No sessions")
  table.insert(lines, "")
  table.insert(lines, "  Create your first session")
  table.insert(lines, "  to get started")
  table.insert(lines, "")
end

function M._add_session_list_content(lines)
  table.insert(lines, "")
  
  for i, session in ipairs(M.sessions_data) do
    local formatted_content = M._format_session_line(session, i)
    
    if type(formatted_content) == "table" then
      -- Multi-line bordered display
      for _, line in ipairs(formatted_content) do
        table.insert(lines, line)
      end
      table.insert(lines, "") -- Add spacing between sessions
    else
      -- Single line fallback
      table.insert(lines, formatted_content)
    end
  end
  
  table.insert(lines, "")
end

function M._format_session_line(session, index)
  local prefix = session.id == M.active_session_id and "► " or "  "
  local status_icon = M._get_status_icon(session)
  local name = M._truncate_name(session.name, M.render_config.max_name_length)
  local shortcut = string.format("[%d]", index)
  
  if M.render_config.show_status then
    -- Get actual status text
    local status_text = "unknown"
    if session.get_status then
      status_text = session:get_status()
    end
    
    -- Create bordered display with consistent width
    local status_display = status_icon .. " " .. status_text
    local hotkey_display = "Press " .. shortcut .. " to open"
    
    -- Use vim.fn.strdisplaywidth for proper terminal display width (handles emoji correctly)
    local name_width = vim.fn.strdisplaywidth(name)
    local status_width = vim.fn.strdisplaywidth(status_display)
    local hotkey_width = vim.fn.strdisplaywidth(hotkey_display)
    
    -- Calculate consistent inner content width (the space inside borders)
    local inner_width = math.max(name_width, status_width, hotkey_width)
    
    -- Build lines with consistent inner padding
    local top_border = "╭ " .. name .. string.rep(" ", inner_width - name_width) .. " ╮"
    local status_line = "│ " .. status_display .. string.rep(" ", inner_width - status_width) .. " │"
    local hotkey_line = "│ " .. hotkey_display .. string.rep(" ", inner_width - hotkey_width) .. " │"
    local bottom_border = "╰" .. string.rep("─", inner_width + 2) .. "╯"
    
    return {
      prefix .. top_border,
      prefix .. status_line,
      prefix .. hotkey_line, 
      prefix .. bottom_border
    }
  else
    return prefix .. name .. " " .. shortcut
  end
end

function M._get_status_icon(session)
  if session.get_status then
    local status = session:get_status()
    if status == "running" then
      return "🟢"
    elseif status == "stopped" then
      return "🔴"
    else
      return "⚫"
    end
  else
    return "🖥️"
  end
end

function M._truncate_name(name, max_length)
  if #name <= max_length then
    return name
  end
  return name:sub(1, max_length - 3) .. "..."
end

function M._add_shortcuts_content(lines)
  if #M.sessions_data > 0 then
    table.insert(lines, "➕ New session              [n]")
    table.insert(lines, "🗑️  Delete session           [d]")
    table.insert(lines, "✏️  Rename session           [r]")
    table.insert(lines, "")
  else
    table.insert(lines, "➕ New session              [n]")
    table.insert(lines, "")
  end
  
  table.insert(lines, "🚪 Close                    [Esc]")
end

function M._setup_keymaps()
  if not M.buffer_id or not vim.api.nvim_buf_is_valid(M.buffer_id) then
    return
  end
  
  local opts = { noremap = true, silent = true, buffer = M.buffer_id }
  
  vim.keymap.set("n", "n", function()
    event_bus.emit(event_types.UI_ACTION_NEW_SESSION)
  end, opts)
  
  vim.keymap.set("n", "d", function()
    event_bus.emit(event_types.UI_ACTION_DELETE_SESSION)
  end, opts)
  
  vim.keymap.set("n", "r", function()
    event_bus.emit(event_types.UI_ACTION_RENAME_SESSION)
  end, opts)
  
  vim.keymap.set("n", "<Esc>", function()
    event_bus.emit(event_types.UI_ACTION_CLOSE_MANAGER)
  end, opts)
  
  for i = 1, 9 do
    vim.keymap.set("n", tostring(i), function()
      event_bus.emit(event_types.UI_ACTION_SELECT_SESSION, { index = i })
    end, opts)
  end
  
  vim.keymap.set("n", "j", function()
    event_bus.emit(event_types.UI_ACTION_NAVIGATE_DOWN)
  end, opts)
  
  vim.keymap.set("n", "k", function()
    event_bus.emit(event_types.UI_ACTION_NAVIGATE_UP)
  end, opts)
  
  vim.keymap.set("n", "<Down>", function()
    event_bus.emit(event_types.UI_ACTION_NAVIGATE_DOWN)
  end, opts)
  
  vim.keymap.set("n", "<Up>", function()
    event_bus.emit(event_types.UI_ACTION_NAVIGATE_UP)
  end, opts)
  
  vim.keymap.set("n", "<CR>", function()
    event_bus.emit(event_types.UI_ACTION_OPEN_SESSION)
  end, opts)
end

function M.navigate_to_session(direction)
  if #M.sessions_data == 0 then
    return false
  end
  
  local current_index = 1
  if M.active_session_id then
    for i, session in ipairs(M.sessions_data) do
      if session.id == M.active_session_id then
        current_index = i
        break
      end
    end
  end
  
  local new_index
  if direction == "down" then
    new_index = (current_index % #M.sessions_data) + 1
  elseif direction == "up" then
    new_index = current_index == 1 and #M.sessions_data or current_index - 1
  else
    return false
  end
  
  local new_session = M.sessions_data[new_index]
  if new_session then
    event_bus.emit(event_types.SESSION_SWITCHED, {
      session_id = new_session.id,
      session = new_session
    })
    return true
  end
  
  return false
end

function M.get_selected_session()
  if M.active_session_id then
    for _, session in ipairs(M.sessions_data) do
      if session.id == M.active_session_id then
        return session
      end
    end
  end
  return nil
end

function M.get_session_at_index(index)
  if index > 0 and index <= #M.sessions_data then
    return M.sessions_data[index]
  end
  return nil
end

function M.focus()
  if M.window_id then
    return floating_window.focus_window(M.window_id)
  end
  return false
end

function M.is_visible()
  return M.window_id and vim.api.nvim_win_is_valid(M.window_id)
end

function M.get_window_info()
  if M.window_id then
    return floating_window.get_window_info(M.window_id)
  end
  return nil
end

return M