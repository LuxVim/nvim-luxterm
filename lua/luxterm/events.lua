-- Simple event system - replaces complex event_bus and cache_coordinator
local M = {
  handlers = {},
  max_handlers_per_event = 50,
  total_handler_limit = 200
}

function M.on(event_type, handler)
  if not M.handlers[event_type] then
    M.handlers[event_type] = {}
  end
  
  -- Prevent memory leaks from too many handlers
  local current_count = #M.handlers[event_type]
  if current_count >= M.max_handlers_per_event then
    vim.notify("Warning: Too many handlers for event " .. event_type, vim.log.levels.WARN)
    return function() end -- Return no-op unsubscribe
  end
  
  -- Check total handler limit
  local total_handlers = M.get_handler_count()
  if total_handlers >= M.total_handler_limit then
    vim.notify("Warning: Total handler limit reached", vim.log.levels.WARN)
    return function() end -- Return no-op unsubscribe
  end
  
  table.insert(M.handlers[event_type], handler)
  
  -- Return unsubscribe function
  return function()
    M.off(event_type, handler)
  end
end

function M.off(event_type, handler)
  if not M.handlers[event_type] then
    return
  end
  
  for i, h in ipairs(M.handlers[event_type]) do
    if h == handler then
      table.remove(M.handlers[event_type], i)
      break
    end
  end
end

function M.emit(event_type, payload)
  if not M.handlers[event_type] then
    return
  end
  
  for _, handler in ipairs(M.handlers[event_type]) do
    local success, err = pcall(handler, payload)
    if not success then
      vim.notify("Event handler error: " .. tostring(err), vim.log.levels.WARN)
    end
  end
end

function M.clear_all()
  M.handlers = {}
end

function M.cleanup_event_handlers()
  local handler_count = 0
  for event_type, handlers in pairs(M.handlers) do
    handler_count = handler_count + #handlers
    -- Clear individual handler references
    for i = 1, #handlers do
      handlers[i] = nil
    end
  end
  
  M.handlers = {}
  
  -- Force garbage collection after cleanup
  collectgarbage("collect")
  
  return handler_count
end

function M.get_handler_count()
  local count = 0
  for event_type, handlers in pairs(M.handlers) do
    count = count + #handlers
  end
  return count
end

function M.cleanup_event_type(event_type)
  if M.handlers[event_type] then
    local count = #M.handlers[event_type]
    -- Clear individual handler references
    for i = 1, count do
      M.handlers[event_type][i] = nil
    end
    M.handlers[event_type] = nil
    return count
  end
  return 0
end

function M.get_memory_stats()
  local stats = {
    total_handlers = M.get_handler_count(),
    event_types = vim.tbl_count(M.handlers),
    memory_usage = collectgarbage("count") * 1024 -- Convert to bytes
  }
  
  return stats
end

-- Event type constants
M.SESSION_CREATED = "session_created"
M.SESSION_DELETED = "session_deleted"
M.SESSION_SWITCHED = "session_switched"
M.SESSION_RENAMED = "session_renamed"
M.MANAGER_OPENED = "manager_opened"
M.MANAGER_CLOSED = "manager_closed"
M.TERMINAL_OPENED = "terminal_opened"
M.TERMINAL_CLOSED = "terminal_closed"

return M