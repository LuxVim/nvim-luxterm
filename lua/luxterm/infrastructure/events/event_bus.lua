local M = {
  subscribers = {},
  async_queue = {},
  processing_async = false
}

function M.subscribe(event_type, handler)
  if not M.subscribers[event_type] then
    M.subscribers[event_type] = {}
  end
  table.insert(M.subscribers[event_type], handler)
  
  return function()
    M.unsubscribe(event_type, handler)
  end
end

function M.unsubscribe(event_type, handler)
  if not M.subscribers[event_type] then
    return
  end
  
  for i, sub_handler in ipairs(M.subscribers[event_type]) do
    if sub_handler == handler then
      table.remove(M.subscribers[event_type], i)
      break
    end
  end
end

function M.emit(event_type, payload)
  if not M.subscribers[event_type] then
    return
  end
  
  for _, handler in ipairs(M.subscribers[event_type]) do
    local success, err = pcall(handler, payload)
    if not success then
      vim.notify("Event handler error for " .. event_type .. ": " .. tostring(err), vim.log.levels.ERROR)
    end
  end
end

function M.emit_async(event_type, payload)
  table.insert(M.async_queue, { event_type = event_type, payload = payload })
  
  if not M.processing_async then
    M.processing_async = true
    vim.schedule(function()
      M._process_async_queue()
    end)
  end
end

function M._process_async_queue()
  local queue = M.async_queue
  M.async_queue = {}
  
  for _, event in ipairs(queue) do
    M.emit(event.event_type, event.payload)
  end
  
  M.processing_async = false
  
  if #M.async_queue > 0 then
    vim.schedule(function()
      M._process_async_queue()
    end)
  end
end

function M.clear_all()
  M.subscribers = {}
  M.async_queue = {}
  M.processing_async = false
end

return M