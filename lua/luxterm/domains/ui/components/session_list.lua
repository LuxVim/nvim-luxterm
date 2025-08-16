local floating_window = require("luxterm.domains.ui.components.floating_window")
local cache_coordinator = require("luxterm.infrastructure.cache.cache_coordinator")
local event_bus = require("luxterm.infrastructure.events.event_bus")
local event_types = require("luxterm.infrastructure.events.event_types")

local M = {
  window_id = nil,
  buffer_id = nil,
  sessions_data = {},
  active_session_id = nil,
  selected_session_index = 1,
  render_config = {
    show_status = true,
    show_shortcuts = true,
    max_name_length = 20
  }
}

function M.setup(opts)
  opts = opts or {}
  M.render_config = vim.tbl_deep_extend("force", M.render_config, opts.render_config or {})
  
  -- Setup highlight groups for border highlighting
  M._setup_highlight_groups()
  
  cache_coordinator.register_cache_layer("session_list", require("luxterm.infrastructure.cache.render_cache"))
  cache_coordinator.register_invalidation_rule(event_types.SESSION_CREATED, {"session_list"})
  cache_coordinator.register_invalidation_rule(event_types.SESSION_DELETED, {"session_list"})
  cache_coordinator.register_invalidation_rule(event_types.SESSION_RENAMED, {"session_list"})
  cache_coordinator.register_invalidation_rule(event_types.SESSION_SWITCHED, {"session_list"})
end

function M._setup_highlight_groups()
  -- Get the normal background color from the current theme
  local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal" })
  local normal_bg = normal_hl.bg and string.format("#%06x", normal_hl.bg) or "NONE"
  
  -- Match luxdash highlighting scheme
  -- Session icons (orange like recent file icons)
  vim.api.nvim_set_hl(0, "LuxtermSessionIcon", { 
    fg = "#ff7801"  -- Orange like LuxDashRecentIcon
  })
  
  -- Session names (light gray like file names)
  vim.api.nvim_set_hl(0, "LuxtermSessionName", { 
    fg = "#d4d4d4"  -- Light gray like LuxDashRecentFile
  })
  
  -- Session numeric keys (magenta/pink bold like recent file keys)
  vim.api.nvim_set_hl(0, "LuxtermSessionKey", { 
    fg = "#db2dee",  -- Magenta/pink like LuxDashRecentKey
    bold = true 
  })
  
  -- Menu-style icons (teal/cyan for action items)
  vim.api.nvim_set_hl(0, "LuxtermMenuIcon", { 
    fg = "#4ec9b0"  -- Teal/cyan like LuxDashMenuIcon
  })
  
  -- Menu-style text (light gray for action labels)
  vim.api.nvim_set_hl(0, "LuxtermMenuText", { 
    fg = "#d4d4d4"  -- Light gray like LuxDashMenuText
  })
  
  -- Menu-style keys (yellow bold for action keymaps)
  vim.api.nvim_set_hl(0, "LuxtermMenuKey", { 
    fg = "#dcdcaa",  -- Yellow like LuxDashMenuKey
    bold = true
  })
  
  -- Border highlights for selected/non-selected sessions
  vim.api.nvim_set_hl(0, "LuxtermSessionSelected", { 
    fg = "#FFA500", 
    bg = normal_bg,
    bold = true 
  })
  vim.api.nvim_set_hl(0, "LuxtermSessionNormal", { 
    fg = "#6B6B6B",
    bg = "NONE"
  })
end


function M._apply_highlights(highlights)
  if not M.buffer_id or not vim.api.nvim_buf_is_valid(M.buffer_id) then
    return
  end
  
  local ns_id = vim.api.nvim_create_namespace("luxterm_session_list")
  
  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(M.buffer_id, ns_id, 0, -1)
  
  -- Apply new highlights
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(
      M.buffer_id,
      ns_id,
      hl.hl_group,
      hl.line,
      hl.col_start,
      hl.col_end
    )
  end
  
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
      filetype = "luxterm_main"
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
  
  -- Set initial selected session to match active session if possible
  if #M.sessions_data > 0 then
    if M.active_session_id then
      -- Try to find the active session and select it
      for i, session in ipairs(M.sessions_data) do
        if session.id == M.active_session_id then
          M.selected_session_index = i
          break
        end
      end
    end
    
    -- Ensure selected session index is valid
    M.selected_session_index = math.min(M.selected_session_index, #M.sessions_data)
    M.selected_session_index = math.max(M.selected_session_index, 1)
  else
    M.selected_session_index = 1
  end
  
  M.render()
end

function M.render()
  if not M.window_id or not vim.api.nvim_win_is_valid(M.window_id) then
    return false
  end
  
  local cache_key = M._generate_cache_key()
  local content_data = cache_coordinator.get_from_cache("session_list", cache_key, function()
    return M._generate_content_with_highlights()
  end)
  
  floating_window.update_window_content(M.window_id, content_data.lines)
  
  -- Force flush the api_adapter batch operations immediately
  local api_adapter = require("luxterm.infrastructure.nvim.api_adapter")
  api_adapter.flush_now()
  
  -- Now apply highlights after content is updated
  M._apply_highlights(content_data.highlights)
  
  return true
end

function M._generate_cache_key()
  local session_ids = {}
  for _, session in ipairs(M.sessions_data) do
    table.insert(session_ids, session.id .. ":" .. session.name)
  end
  return "session_list_" .. table.concat(session_ids, "|") .. "_" .. (M.active_session_id or "none") .. "_sel" .. M.selected_session_index
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

function M._generate_content_with_highlights()
  local lines = {}
  local highlights = {}
  
  if #M.sessions_data == 0 then
    M._add_empty_state_content(lines)
  else
    M._add_session_list_content_with_highlights(lines, highlights)
  end
  
  if M.render_config.show_shortcuts then
    M._add_shortcuts_content_with_highlights(lines, highlights)
  end
  
  return {
    lines = lines,
    highlights = highlights
  }
end

function M._add_empty_state_content(lines)
  table.insert(lines, "  No sessions")
  table.insert(lines, "")
end

function M._add_session_list_content(lines)
  -- table.insert(lines, "")
  
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

function M._add_session_list_content_with_highlights(lines, highlights)
  for i, session in ipairs(M.sessions_data) do
    local formatted_content = M._format_session_line_with_highlights(session, i, lines, highlights)
    
    if type(formatted_content) == "table" then
      -- Multi-line bordered display - lines and highlights already added by _format_session_line_with_highlights
      table.insert(lines, "") -- Add spacing between sessions
    else
      -- Single line fallback - handled by _format_session_line_with_highlights
    end
  end
  
  table.insert(lines, "")
end

function M._format_session_line(session, index)
  local status_icon = M._get_status_icon(session)
  local name = M._truncate_name(session.name, M.render_config.max_name_length)
  local shortcut = string.format("[%d]", index)
  
  -- Determine if this session is selected (for highlighting)
  local is_selected = index == M.selected_session_index
  local is_active = session.id == M.active_session_id
  
  if M.render_config.show_status then
    -- Get actual status text
    local status_text = "unknown"
    if session.get_status then
      status_text = session:get_status()
    end
    
    -- Create bordered display with consistent width
    local status_display = status_icon .. " " .. status_text
    local hotkey_display = "Press " .. shortcut .. " to open"
    
    -- Add active indicator in status if active
    if is_active then
      status_display = status_display .. " (active)"
    end
    
    -- Use vim.fn.strdisplaywidth for proper terminal display width (handles emoji correctly)
    local name_width = vim.fn.strdisplaywidth(name)
    local status_width = vim.fn.strdisplaywidth(status_display)
    local hotkey_width = vim.fn.strdisplaywidth(hotkey_display)
    
    -- Calculate consistent inner content width (the space inside borders)
    local inner_width = math.max(name_width, status_width, hotkey_width)
    
    -- Choose border characters based on selection state
    local border_chars = M._get_border_chars(is_selected)
    
    -- Build lines with consistent inner padding and contextual borders
    local top_border = "  " .. border_chars.top_left .. " " .. name .. " " .. string.rep(border_chars.horizontal, inner_width - name_width -1) .. border_chars.horizontal .. border_chars.top_right
    local status_line = "  " .. border_chars.vertical .. " " .. status_display .. string.rep(" ", inner_width - status_width) .. " " .. border_chars.vertical
    local hotkey_line = "  " .. border_chars.vertical .. " " .. hotkey_display .. string.rep(" ", inner_width - hotkey_width) .. " " .. border_chars.vertical
    local bottom_border = "  " .. border_chars.bottom_left .. string.rep(border_chars.horizontal, inner_width + 2) .. border_chars.bottom_right
    
    return {
      top_border,
      status_line,
      hotkey_line, 
      bottom_border
    }
  else
    local selection_marker = is_selected and "► " or "  "
    return "  " .. selection_marker .. name .. " " .. shortcut
  end
end

function M._format_session_line_with_highlights(session, index, lines, highlights)
  local status_icon = M._get_status_icon(session)
  local name = M._truncate_name(session.name, M.render_config.max_name_length)
  local shortcut = string.format("[%d]", index)
  
  -- Determine if this session is selected (for highlighting)
  local is_selected = index == M.selected_session_index
  local is_active = session.id == M.active_session_id
  local highlight_group = is_selected and "LuxtermSessionSelected" or "LuxtermSessionNormal"
  
  if M.render_config.show_status then
    -- Get actual status text
    local status_text = "unknown"
    if session.get_status then
      status_text = session:get_status()
    end
    
    -- Create bordered display with consistent width
    local status_display = status_icon .. " " .. status_text
    local hotkey_display = "Press " .. shortcut .. " to open"
    
    -- Add active indicator in status if active
    if is_active then
      status_display = status_display .. " (active)"
    end
    
    -- Use vim.fn.strdisplaywidth for proper terminal display width (handles emoji correctly)
    local name_width = vim.fn.strdisplaywidth(name)
    local status_width = vim.fn.strdisplaywidth(status_display)
    local hotkey_width = vim.fn.strdisplaywidth(hotkey_display)
    
    -- Calculate consistent inner content width (the space inside borders)
    local inner_width = math.max(name_width, status_width, hotkey_width)
    
    -- Choose border characters based on selection state
    local border_chars = M._get_border_chars(is_selected)
    
    -- Build lines with consistent inner padding and contextual borders
    local top_border = "  " .. border_chars.top_left .. " " .. name .. " " .. string.rep(border_chars.horizontal, inner_width - name_width -1) .. border_chars.horizontal .. border_chars.top_right
    local status_line = "  " .. border_chars.vertical .. " " .. status_display .. string.rep(" ", inner_width - status_width) .. " " .. border_chars.vertical
    local hotkey_line = "  " .. border_chars.vertical .. " " .. hotkey_display .. string.rep(" ", inner_width - hotkey_width) .. " " .. border_chars.vertical
    local bottom_border = "  " .. border_chars.bottom_left .. string.rep(border_chars.horizontal, inner_width + 2) .. border_chars.bottom_right
    
    -- Add lines and their highlights
    local session_lines = {top_border, status_line, hotkey_line, bottom_border}
    
    for _, line in ipairs(session_lines) do
      local line_num = #lines
      table.insert(lines, line)
      
      -- Highlight entire border line for selection
      table.insert(highlights, {
        line = line_num,
        col_start = 0,
        col_end = -1,
        hl_group = highlight_group
      })
      
      -- Add luxdash-style highlights for icons and keys within bordered content
      if line == top_border then
        -- Highlight session name (luxdash style)
        local name_start = vim.fn.strdisplaywidth("  " .. border_chars.top_left .. " ")
        local name_end = name_start + name_width
        table.insert(highlights, {
          line = line_num,
          col_start = name_start,
          col_end = name_end,
          hl_group = "LuxtermSessionName"
        })
      elseif line == status_line then
        -- Highlight status icon (luxdash style - orange like recent file icons)
        local icon_start = vim.fn.strdisplaywidth("  " .. border_chars.vertical .. " ")
        local icon_end = icon_start + vim.fn.strdisplaywidth(status_icon)
        table.insert(highlights, {
          line = line_num,
          col_start = icon_start,
          col_end = icon_end,
          hl_group = "LuxtermSessionIcon"
        })
      elseif line == hotkey_line then
        -- Highlight numeric key (luxdash style - magenta/pink bold like recent file keys)
        local key_pattern = "%[%d+%]"
        local key_start, key_end = string.find(line, key_pattern)
        if key_start then
          table.insert(highlights, {
            line = line_num,
            col_start = key_start - 1, -- Convert to 0-based indexing
            col_end = key_end,
            hl_group = "LuxtermSessionKey"
          })
        end
      end
    end
    
    return session_lines
  else
    local selection_marker = is_selected and "► " or "  "
    local line_content = "  " .. selection_marker .. name .. " " .. shortcut
    local line_num = #lines
    table.insert(lines, line_content)
    
    if is_selected then
      -- Highlight selection marker
      table.insert(highlights, {
        line = line_num,
        col_start = 0,
        col_end = 4, -- Highlight "  ► "
        hl_group = highlight_group
      })
    end
    
    -- Highlight session name (luxdash style)
    local name_start = vim.fn.strdisplaywidth("  " .. selection_marker)
    local name_end = name_start + vim.fn.strdisplaywidth(name)
    table.insert(highlights, {
      line = line_num,
      col_start = name_start,
      col_end = name_end,
      hl_group = "LuxtermSessionName"
    })
    
    -- Highlight numeric key (luxdash style)
    local key_start = name_end + 1
    local key_end = key_start + vim.fn.strdisplaywidth(shortcut)
    table.insert(highlights, {
      line = line_num,
      col_start = key_start,
      col_end = key_end,
      hl_group = "LuxtermSessionKey"
    })
    
    return line_content
  end
end

function M._get_border_chars(is_selected)
  if is_selected then
    -- Orange borders for selected session
    return {
      top_left = "╭",
      top_right = "╮", 
      bottom_left = "╰",
      bottom_right = "╯",
      horizontal = "─",
      vertical = "│"
    }
  else
    -- Grey borders for non-selected sessions  
    return {
      top_left = "╭",
      top_right = "╮",
      bottom_left = "╰", 
      bottom_right = "╯",
      horizontal = "─",
      vertical = "│"
    }
  end
end

function M._get_status_icon(session)
  if session.get_status then
    local status = session:get_status()
    if status == "running" then
      return "󰸞"
    elseif status == "stopped" then
      return "󰼭"
    else
      return "󰏢"
    end
  else
    return "󰆍"
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
    table.insert(lines, "  󰷈  New session              [n]")
    table.insert(lines, "  󰆴  Delete session           [d]")
    table.insert(lines, "  󰑕  Rename session           [r]")
    table.insert(lines, "")
  else
    table.insert(lines, "  󰷈  New session              [n]")
    table.insert(lines, "")
  end
  
  table.insert(lines, "  󰅖  Close                    [Esc]")
end

function M._add_shortcuts_content_with_highlights(lines, highlights)
  local shortcuts_data = {}
  
  if #M.sessions_data > 0 then
    shortcuts_data = {
      { icon = "󰷈", label = "New session", key = "[n]" },
      { icon = "󰆴", label = "Delete session", key = "[d]" },
      { icon = "󰑕", label = "Rename session", key = "[r]" }
    }
  else
    shortcuts_data = {
      { icon = "󰷈", label = "New session", key = "[n]" }
    }
  end
  
  -- Add menu items with luxdash-style highlighting
  for _, item in ipairs(shortcuts_data) do
    local line_num = #lines
    local line_content = "  " .. item.icon .. "  " .. item.label
    
    -- Calculate padding to align keys to the right
    local target_width = 40 -- Consistent with luxdash layout
    local content_width = vim.fn.strdisplaywidth(line_content)
    local key_width = vim.fn.strdisplaywidth(item.key)
    local padding_needed = target_width - content_width - key_width
    local padding = string.rep(" ", math.max(1, padding_needed))
    
    local full_line = line_content .. padding .. item.key
    table.insert(lines, full_line)
    
    -- Add highlights for icon, text, and key separately (luxdash style)
    local icon_end = 2 + vim.fn.strdisplaywidth(item.icon)
    local text_start = icon_end + 2
    local text_end = text_start + vim.fn.strdisplaywidth(item.label)
    local key_start = text_end + padding_needed
    local key_end = key_start + key_width
    
    -- Icon highlight (teal/cyan like luxdash menu icons)
    table.insert(highlights, {
      line = line_num,
      col_start = 2,
      col_end = icon_end,
      hl_group = "LuxtermMenuIcon"
    })
    
    -- Text highlight (light gray like luxdash menu text)
    table.insert(highlights, {
      line = line_num,
      col_start = text_start,
      col_end = text_end,
      hl_group = "LuxtermMenuText"
    })
    
    -- Key highlight (yellow bold like luxdash menu keys)
    table.insert(highlights, {
      line = line_num,
      col_start = key_start,
      col_end = key_end,
      hl_group = "LuxtermMenuKey"
    })
  end
  
  if #shortcuts_data > 0 then
    table.insert(lines, "")
  end
  
  -- Add close option
  local line_num = #lines
  local close_line = "  󰅖  Close                    [Esc]"
  table.insert(lines, close_line)
  
  -- Highlight close option parts
  local close_icon_end = 2 + vim.fn.strdisplaywidth("󰅖")
  local close_text_start = close_icon_end + 2
  local close_text_end = close_text_start + vim.fn.strdisplaywidth("Close")
  local close_key_start = vim.fn.strdisplaywidth("  󰅖  Close                    ")
  local close_key_end = vim.fn.strdisplaywidth(close_line)
  
  table.insert(highlights, {
    line = line_num,
    col_start = 2,
    col_end = close_icon_end,
    hl_group = "LuxtermMenuIcon"
  })
  
  table.insert(highlights, {
    line = line_num,
    col_start = close_text_start,
    col_end = close_text_end,
    hl_group = "LuxtermMenuText"
  })
  
  table.insert(highlights, {
    line = line_num,
    col_start = close_key_start,
    col_end = close_key_end,
    hl_group = "LuxtermMenuKey"
  })
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
  
  local current_index = M.selected_session_index
  local new_index
  
  if direction == "down" then
    new_index = (current_index % #M.sessions_data) + 1
  elseif direction == "up" then
    new_index = current_index == 1 and #M.sessions_data or current_index - 1
  else
    return false
  end
  
  -- Update selected session index and re-render to show new selection
  M.selected_session_index = new_index
  M.render()
  
  return true
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
