local event_bus = require("luxterm.infrastructure.events.event_bus")
local event_types = require("luxterm.infrastructure.events.event_types")

local M = {
  timers = {},
  debounce_timers = {},
  default_refresh_rate = 60,
  min_debounce_delay = 16
}

function M.setup(opts)
  opts = opts or {}
  M.default_refresh_rate = opts.refresh_rate or 60
  M.min_debounce_delay = opts.min_debounce_delay or 16
end

function M.create_refresh_timer(timer_id, callback, interval_ms)
  interval_ms = interval_ms or math.floor(1000 / M.default_refresh_rate)
  
  if M.timers[timer_id] then
    M.stop_timer(timer_id)
  end
  
  local timer = vim.loop.new_timer()
  if not timer then
    return nil
  end
  
  M.timers[timer_id] = {
    timer = timer,
    callback = callback,
    interval = interval_ms,
    active = false
  }
  
  return timer_id
end

function M.start_timer(timer_id)
  local timer_data = M.timers[timer_id]
  if not timer_data or timer_data.active then
    return false
  end
  
  timer_data.active = true
  timer_data.timer:start(timer_data.interval, timer_data.interval, vim.schedule_wrap(function()
    if timer_data.active then
      local success, err = pcall(timer_data.callback)
      if not success then
        vim.notify("Timer callback error: " .. tostring(err), vim.log.levels.ERROR)
        M.stop_timer(timer_id)
      end
    end
  end))
  
  return true
end

function M.stop_timer(timer_id)
  local timer_data = M.timers[timer_id]
  if not timer_data then
    return false
  end
  
  timer_data.active = false
  
  if timer_data.timer then
    pcall(function()
      timer_data.timer:stop()
    end)
  end
  
  return true
end

function M.destroy_timer(timer_id)
  local timer_data = M.timers[timer_id]
  if not timer_data then
    return false
  end
  
  timer_data.active = false
  
  if timer_data.timer then
    pcall(function()
      if not timer_data.timer:is_closing() then
        timer_data.timer:stop()
        timer_data.timer:close()
      end
    end)
  end
  
  if timer_data.unsubscribe then
    pcall(timer_data.unsubscribe)
  end
  
  M.timers[timer_id] = nil
  
  return true
end

function M.debounce(debounce_id, callback, delay_ms)
  delay_ms = delay_ms or M.min_debounce_delay
  
  if M.debounce_timers[debounce_id] then
    M.debounce_timers[debounce_id]:stop()
    M.debounce_timers[debounce_id]:close()
  end
  
  local timer = vim.loop.new_timer()
  if not timer then
    return false
  end
  
  M.debounce_timers[debounce_id] = timer
  
  timer:start(delay_ms, 0, vim.schedule_wrap(function()
    timer:close()
    M.debounce_timers[debounce_id] = nil
    
    local success, err = pcall(callback)
    if not success then
      vim.notify("Debounced callback error: " .. tostring(err), vim.log.levels.ERROR)
    end
  end))
  
  return true
end

function M.create_event_driven_refresh(timer_id, event_type, callback)
  local timer_data = {
    callback = callback,
    active = false,
    last_refresh = 0,
    min_interval = math.floor(1000 / M.default_refresh_rate)
  }
  
  local unsubscribe = event_bus.subscribe(event_type, function(payload)
    if not timer_data.active then
      return
    end
    
    local now = vim.loop.now()
    local time_since_last = now - timer_data.last_refresh
    
    if time_since_last >= timer_data.min_interval then
      timer_data.last_refresh = now
      local success, err = pcall(timer_data.callback, payload)
      if not success then
        vim.notify("Event-driven refresh error: " .. tostring(err), vim.log.levels.ERROR)
      end
    else
      M.debounce("event_refresh_" .. timer_id, function()
        timer_data.last_refresh = vim.loop.now()
        timer_data.callback(payload)
      end, timer_data.min_interval - time_since_last)
    end
  end)
  
  timer_data.unsubscribe = unsubscribe
  M.timers[timer_id] = timer_data
  
  return timer_id
end

function M.start_event_timer(timer_id)
  local timer_data = M.timers[timer_id]
  if timer_data then
    timer_data.active = true
    return true
  end
  return false
end

function M.stop_event_timer(timer_id)
  local timer_data = M.timers[timer_id]
  if timer_data then
    timer_data.active = false
    return true
  end
  return false
end

function M.cleanup_all()
  for timer_id, timer_data in pairs(M.timers) do
    if timer_data.timer then
      timer_data.timer:stop()
      timer_data.timer:close()
    end
    if timer_data.unsubscribe then
      timer_data.unsubscribe()
    end
  end
  M.timers = {}
  
  for _, timer in pairs(M.debounce_timers) do
    timer:stop()
    timer:close()
  end
  M.debounce_timers = {}
end

return M