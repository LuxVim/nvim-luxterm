-- Simple event system - replaces complex event_bus and cache_coordinator
local M = {
  handlers = {}
}

function M.on(event_type, handler)
  if not M.handlers[event_type] then
    M.handlers[event_type] = {}
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
  end
  
  M.handlers = {}
  
  return handler_count
end

function M.get_handler_count()
  local count = 0
  for event_type, handlers in pairs(M.handlers) do
    count = count + #handlers
  end
  return count
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