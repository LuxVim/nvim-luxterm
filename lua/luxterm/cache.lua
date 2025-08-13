local M = {
  session_list_cache = nil,
  session_list_hash = nil,
  preview_cache = {},
  last_active_session = nil,
  render_cache = {
    session_list_lines = {},
    preview_lines = {}
  }
}

--- Invalidate all caches
function M.invalidate()
  M.session_list_cache = nil
  M.session_list_hash = nil
  M.preview_cache = {}
  M.last_active_session = nil
  M.render_cache = {
    session_list_lines = {},
    preview_lines = {}
  }
end

--- Invalidate only session list cache
function M.invalidate_session_list()
  M.session_list_cache = nil
  M.session_list_hash = nil
  M.render_cache.session_list_lines = {}
end

--- Invalidate preview cache
function M.invalidate_preview()
  M.preview_cache = {}
  M.render_cache.preview_lines = {}
end

--- Get cached session list or fetch new one
function M.get_session_list(fetch_func)
  if not M.session_list_cache then
    M.session_list_cache = fetch_func()
    M.session_list_hash = M.hash_session_list(M.session_list_cache)
  end
  return M.session_list_cache
end

--- Check if session list needs refresh
function M.session_list_changed(current_sessions)
  local current_hash = M.hash_session_list(current_sessions)
  if M.session_list_hash ~= current_hash then
    M.invalidate_session_list()
    return true
  end
  return false
end

--- Generate hash for session list to detect changes
function M.hash_session_list(sessions)
  local hash_parts = {}
  for _, session in ipairs(sessions) do
    local id = session.id or 0
    local name = session.name or "unnamed"
    local bufnr = session.bufnr or 0
    table.insert(hash_parts, string.format("%d:%s:%d", id, name, bufnr))
  end
  return table.concat(hash_parts, "|")
end

--- Get cached preview for a session
function M.get_preview(session_id, fetch_func)
  local cache_key = tostring(session_id)
  if not M.preview_cache[cache_key] then
    M.preview_cache[cache_key] = {
      lines = fetch_func(),
      timestamp = os.time()
    }
  end
  return M.preview_cache[cache_key].lines
end

--- Check if preview needs refresh (based on time or session change)
function M.preview_needs_refresh(session_id, max_age)
  max_age = max_age or 2 -- 2 seconds default
  local cache_key = tostring(session_id)
  local cached = M.preview_cache[cache_key]
  
  if not cached then
    return true
  end
  
  return (os.time() - cached.timestamp) > max_age
end

--- Get cached rendered session list lines
function M.get_rendered_session_list(sessions, active_session_id, render_func)
  local cache_key = M.hash_session_list(sessions) .. ":" .. (active_session_id or "none")
  
  if not M.render_cache.session_list_lines[cache_key] then
    M.render_cache.session_list_lines[cache_key] = render_func()
  end
  
  return M.render_cache.session_list_lines[cache_key]
end

--- Generate hash for terminal buffer content to detect changes
function M.hash_terminal_content(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= 'terminal' then
    return "invalid"
  end
  
  -- Get last few lines and line count to create a simple hash
  local lines = vim.api.nvim_buf_get_lines(bufnr, -10, -1, false)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local last_lines = table.concat(lines, "|")
  
  -- Create hash based on line count and last few lines
  return string.format("%d:%s", line_count, last_lines:sub(1, 100))
end

--- Get cached rendered preview lines
function M.get_rendered_preview(session_id, bufnr, render_func)
  local content_hash = M.hash_terminal_content(bufnr)
  local cache_key = tostring(session_id) .. ":" .. content_hash
  
  if not M.render_cache.preview_lines[cache_key] then
    M.render_cache.preview_lines[cache_key] = render_func()
  end
  
  return M.render_cache.preview_lines[cache_key]
end

--- Track active session changes
function M.active_session_changed(current_active)
  if M.last_active_session ~= current_active then
    M.last_active_session = current_active
    return true
  end
  return false
end

--- Clean up old cache entries
function M.cleanup_old_entries()
  local current_time = os.time()
  local max_age = 60 -- 1 minute
  
  for cache_key, cache_entry in pairs(M.preview_cache) do
    if (current_time - cache_entry.timestamp) > max_age then
      M.preview_cache[cache_key] = nil
    end
  end
  
  local session_cache_count = 0
  for _ in pairs(M.render_cache.session_list_lines) do
    session_cache_count = session_cache_count + 1
  end
  if session_cache_count > 10 then
    M.render_cache.session_list_lines = {}
  end
  
  local preview_cache_count = 0
  for _ in pairs(M.render_cache.preview_lines) do
    preview_cache_count = preview_cache_count + 1
  end
  if preview_cache_count > 20 then
    M.render_cache.preview_lines = {}
  end
end

return M
