local floating_window = require("luxterm.domains.ui.components.floating_window")
local content_extractor = require("luxterm.domains.terminal.services.content_extractor")
local cache_coordinator = require("luxterm.infrastructure.cache.cache_coordinator")
local timer_manager = require("luxterm.infrastructure.nvim.timer_manager")
local event_bus = require("luxterm.infrastructure.events.event_bus")
local event_types = require("luxterm.infrastructure.events.event_types")

local M = {
  window_id = nil,
  buffer_id = nil,
  current_session = nil,
  refresh_timer_id = nil,
  content_watcher_id = nil,
  config = {
    max_lines = 50,
    refresh_enabled = true,
    show_header = true,
    show_status = true
  }
}

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts.preview_config or {})
  
  cache_coordinator.register_cache_layer("preview", require("luxterm.infrastructure.cache.render_cache"))
  cache_coordinator.register_invalidation_rule(event_types.SESSION_CONTENT_CHANGED, {"preview"})
  cache_coordinator.register_invalidation_rule(event_types.SESSION_SWITCHED, {"preview"})
  
  M._setup_event_listeners()
end

function M._setup_event_listeners()
  event_bus.subscribe(event_types.SESSION_CONTENT_CHANGED, function(payload)
    if payload.session_id and M.current_session and M.current_session.id == payload.session_id then
      M._refresh_content()
    end
  end)
  
  event_bus.subscribe(event_types.SESSION_SWITCHED, function(payload)
    if payload.session then
      M.set_session(payload.session)
    end
  end)
end

function M.create(config)
  if M.window_id and vim.api.nvim_win_is_valid(M.window_id) then
    M.destroy()
  end
  
  local window_config = vim.tbl_deep_extend("force", {
    title = " Preview ",
    title_pos = "center",
    enter = false,
    buffer_options = {
      filetype = "luxterm-preview"
    },
    on_create = function(winid, bufnr)
      M.window_id = winid
      M.buffer_id = bufnr
    end,
    on_close = function()
      M._cleanup_timers()
      M.window_id = nil
      M.buffer_id = nil
    end
  }, config or {})
  
  return floating_window.create_window(window_config)
end

function M.destroy()
  M._cleanup_timers()
  if M.window_id then
    floating_window.close_window(M.window_id)
    M.window_id = nil
    M.buffer_id = nil
  end
end

function M.set_session(session)
  M.current_session = session
  M._setup_content_watching()
  M.render()
end

function M.render()
  if not M.window_id or not vim.api.nvim_win_is_valid(M.window_id) then
    return false
  end
  
  local lines
  if not M.current_session then
    lines = M._generate_empty_content()
  else
    local cache_key = M._generate_cache_key()
    lines = cache_coordinator.get_from_cache("preview", cache_key, function()
      return M._generate_session_content()
    end)
  end
  
  floating_window.update_window_content(M.window_id, lines)
  return true
end

function M._generate_cache_key()
  if not M.current_session then
    return "preview_empty"
  end
  
  local content_hash = "unknown"
  if M.current_session.bufnr and vim.api.nvim_buf_is_valid(M.current_session.bufnr) then
    local sample_lines = vim.api.nvim_buf_get_lines(M.current_session.bufnr, -5, -1, false)
    content_hash = table.concat(sample_lines, "|"):sub(1, 50)
  end
  
  return "preview_" .. M.current_session.id .. "_" .. content_hash
end

function M._generate_empty_content()
  return {
    "",
    "  No active session",
    "",
    "  Select a session from the list",
    "  to see its content here",
    ""
  }
end

function M._generate_session_content()
  if not M.current_session then
    return M._generate_empty_content()
  end
  
  local lines = {}
  
  if M.config.show_header then
    M._add_header_content(lines)
  end
  
  M._add_terminal_content(lines)
  
  M._add_footer_content(lines)
  
  return lines
end

function M._add_header_content(lines)
  -- Ensure we have a valid session before accessing its properties
  if not M.current_session then
    return
  end
  
  local name = M.current_session.name or "Unknown Session"
  local header_line = "╭─ " .. name .. " ─╮"
  
  table.insert(lines, "")
  table.insert(lines, "  " .. header_line)
  table.insert(lines, "  │")
  
  if M.config.show_status then
    local status = "Unknown"
    local status_icon = "⚫"
    
    if M.current_session.get_status then
      status = M.current_session:get_status()
      if status == "running" then
        status_icon = "🟢"
      elseif status == "stopped" then
        status_icon = "🔴"
      else
        status_icon = "⚫"
      end
    end
    
    table.insert(lines, "  │  " .. status_icon .. " Status: " .. status)
    table.insert(lines, "  │")
  end
  
  local footer_line = "  ╰─" .. string.rep("─", #name) .. "─╯"
  table.insert(lines, footer_line)
  table.insert(lines, "")
end

function M._add_terminal_content(lines)
  local terminal_lines = {}
  
  -- Check if current session exists and is valid before accessing its bufnr
  if M.current_session and M.current_session.bufnr and vim.api.nvim_buf_is_valid(M.current_session.bufnr) then
    -- Additional check to ensure it's actually a terminal buffer
    if vim.bo[M.current_session.bufnr].buftype == 'terminal' then
      terminal_lines = content_extractor.extract_terminal_content(M.current_session.bufnr, {
        max_lines = M.config.max_lines,
        clean_ansi = true
      })
    end
  end
  
  if #terminal_lines == 0 or (#terminal_lines == 1 and terminal_lines[1] == "") then
    table.insert(lines, "  [Empty terminal]")
    table.insert(lines, "")
  else
    local window_width = 80
    if M.window_id and vim.api.nvim_win_is_valid(M.window_id) then
      window_width = vim.api.nvim_win_get_width(M.window_id) - 4
    end
    
    for _, line in ipairs(terminal_lines) do
      local formatted_line = M._format_terminal_line(line, window_width)
      table.insert(lines, "  " .. formatted_line)
    end
    table.insert(lines, "")
  end
end

function M._format_terminal_line(line, max_width)
  if #line > max_width then
    return line:sub(1, max_width - 3) .. "..."
  end
  return line
end

function M._add_footer_content(lines)
  table.insert(lines, "  Press <Enter> to open • 'd' to delete")
end

function M._setup_content_watching()
  M._cleanup_timers()
  
  if not M.config.refresh_enabled or not M.current_session or not M.current_session.bufnr then
    return
  end
  
  M.content_watcher_id = content_extractor.watch_terminal_content(
    M.current_session.bufnr,
    function(bufnr, content)
      M._on_content_changed(bufnr, content)
    end,
    { interval = 1000 }
  )
  
  M.refresh_timer_id = timer_manager.create_event_driven_refresh(
    "preview_refresh",
    event_types.SESSION_CONTENT_CHANGED,
    function(payload)
      if payload.session_id == M.current_session.id then
        M.render()
      end
    end
  )
  
  timer_manager.start_event_timer(M.refresh_timer_id)
end

function M._on_content_changed(bufnr, content)
  if M.current_session and M.current_session.bufnr == bufnr then
    event_bus.emit_async(event_types.SESSION_CONTENT_CHANGED, {
      session_id = M.current_session.id,
      bufnr = bufnr,
      content = content
    })
  end
end

function M._refresh_content()
  timer_manager.debounce("preview_content_refresh", function()
    M.render()
  end, 100)
end

function M._cleanup_timers()
  if M.content_watcher_id then
    content_extractor.stop_watching_content(M.content_watcher_id)
    M.content_watcher_id = nil
  end
  
  if M.refresh_timer_id then
    timer_manager.stop_event_timer(M.refresh_timer_id)
    timer_manager.destroy_timer(M.refresh_timer_id)
    M.refresh_timer_id = nil
  end
end

function M.toggle_refresh(enabled)
  M.config.refresh_enabled = enabled
  if enabled then
    M._setup_content_watching()
  else
    M._cleanup_timers()
  end
end

function M.get_current_session()
  return M.current_session
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

function M.preload_content(session)
  if session and session.bufnr then
    content_extractor.preload_content(session.bufnr, {
      max_lines = M.config.max_lines
    })
  end
end

return M