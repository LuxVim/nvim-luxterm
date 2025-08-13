local cache_coordinator = require("luxterm.infrastructure.cache.cache_coordinator")
local event_bus = require("luxterm.infrastructure.events.event_bus")
local event_types = require("luxterm.infrastructure.events.event_types")

local M = {
  content_watchers = {},
  extraction_queue = {},
  processing_queue = false
}

function M.setup()
  cache_coordinator.register_cache_layer("content", require("luxterm.infrastructure.cache.content_cache"))
  M._setup_event_listeners()
end

function M._setup_event_listeners()
  event_bus.subscribe(event_types.SESSION_CONTENT_CHANGED, function(payload)
    if payload.session_id then
      M._invalidate_session_content(payload.session_id)
    end
  end)
end

function M.extract_terminal_content(bufnr, opts)
  opts = opts or {}
  local max_lines = opts.max_lines or 50
  local clean_ansi = opts.clean_ansi ~= false
  local stream_mode = opts.stream_mode or false
  
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= 'terminal' then
    return {"[Invalid terminal buffer]"}
  end
  
  local cache_key = "terminal_content_" .. bufnr .. "_" .. max_lines
  
  local cached_content = cache_coordinator.get_from_cache("content", cache_key)
  if cached_content and not M._has_content_changed(bufnr, cached_content) then
    return cached_content
  end
  
  local content
  if stream_mode then
    content = M._extract_streaming(bufnr, max_lines, clean_ansi)
  else
    content = M._extract_batch(bufnr, max_lines, clean_ansi)
  end
  
  cache_coordinator.set_in_cache("content", cache_key, content)
  
  return content
end

function M._extract_batch(bufnr, max_lines, clean_ansi)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end
  
  if #lines > max_lines then
    lines = vim.list_slice(lines, #lines - max_lines + 1, #lines)
  end
  
  if clean_ansi then
    return M._clean_ansi_sequences(lines)
  end
  
  return lines
end

function M._extract_streaming(bufnr, max_lines, clean_ansi)
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local start_line = math.max(0, total_lines - max_lines)
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, -1, false)
  
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end
  
  if clean_ansi then
    local cleaned_lines = {}
    for i, line in ipairs(lines) do
      if i % 10 == 0 then
        vim.schedule(function() end)
      end
      table.insert(cleaned_lines, M._clean_single_line(line))
    end
    return cleaned_lines
  end
  
  return lines
end

function M._clean_ansi_sequences(lines)
  local cleaned_lines = {}
  for _, line in ipairs(lines) do
    table.insert(cleaned_lines, M._clean_single_line(line))
  end
  return cleaned_lines
end

function M._clean_single_line(line)
  local cleaned = line:gsub("\27%[[%d;]*[mK]", "")
  cleaned = cleaned:gsub("[\1-\8\11\12\14-\31\127]", "")
  return cleaned
end

function M._has_content_changed(bufnr, cached_content)
  local current_line_count = vim.api.nvim_buf_line_count(bufnr)
  local last_lines = vim.api.nvim_buf_get_lines(bufnr, -5, -1, false)
  local current_hash = M._generate_content_hash(current_line_count, last_lines)
  
  local cached_hash = M._generate_content_hash(#cached_content, vim.list_slice(cached_content, -5, -1))
  
  return current_hash ~= cached_hash
end

function M._generate_content_hash(line_count, sample_lines)
  local combined = tostring(line_count) .. "|" .. table.concat(sample_lines or {}, "|")
  return combined:sub(1, 100)
end

function M.extract_terminal_content_async(bufnr, opts, callback)
  opts = opts or {}
  table.insert(M.extraction_queue, {
    bufnr = bufnr,
    opts = opts,
    callback = callback
  })
  
  M._process_extraction_queue()
end

function M._process_extraction_queue()
  if M.processing_queue or #M.extraction_queue == 0 then
    return
  end
  
  M.processing_queue = true
  
  vim.schedule(function()
    local batch_size = math.min(3, #M.extraction_queue)
    local current_batch = {}
    
    for i = 1, batch_size do
      table.insert(current_batch, table.remove(M.extraction_queue, 1))
    end
    
    for _, item in ipairs(current_batch) do
      local content = M.extract_terminal_content(item.bufnr, item.opts)
      if item.callback then
        pcall(item.callback, content, item.bufnr)
      end
    end
    
    M.processing_queue = false
    
    if #M.extraction_queue > 0 then
      M._process_extraction_queue()
    end
  end)
end

function M.watch_terminal_content(bufnr, callback, opts)
  opts = opts or {}
  local watch_interval = opts.interval or 1000
  local watch_id = "watch_" .. bufnr .. "_" .. vim.loop.now()
  
  local timer = vim.loop.new_timer()
  M.content_watchers[watch_id] = {
    bufnr = bufnr,
    callback = callback,
    last_hash = nil,
    active = true,
    timer = timer
  }
  
  timer:start(watch_interval, watch_interval, vim.schedule_wrap(function()
    local watcher = M.content_watchers[watch_id]
    if not watcher or not watcher.active then
      -- Watcher was stopped externally, just clean up the timer reference
      if watcher then
        watcher.timer = nil
        M.content_watchers[watch_id] = nil
      end
      return
    end
    
    if not vim.api.nvim_buf_is_valid(watcher.bufnr) then
      M.stop_watching_content(watch_id)
      return
    end
    
    local content = M.extract_terminal_content(watcher.bufnr, { max_lines = 10 })
    local current_hash = M._generate_content_hash(#content, content)
    
    if watcher.last_hash ~= current_hash then
      watcher.last_hash = current_hash
      pcall(watcher.callback, watcher.bufnr, content)
    end
  end))
  
  return watch_id
end

function M.stop_watching_content(watch_id)
  local watcher = M.content_watchers[watch_id]
  if watcher then
    watcher.active = false
    
    -- Safely stop and close the timer if it exists
    if watcher.timer then
      pcall(function()
        if not watcher.timer:is_closing() then
          watcher.timer:stop()
          watcher.timer:close()
        end
      end)
      watcher.timer = nil
    end
    
    M.content_watchers[watch_id] = nil
  end
end

function M._invalidate_session_content(session_id)
  cache_coordinator.get_from_cache("content", "session_content_invalidation", function()
    return {}
  end)
end

function M.preload_content(bufnr, opts)
  opts = opts or {}
  cache_coordinator.warm_cache("content", "terminal_content_" .. bufnr .. "_" .. (opts.max_lines or 50), function()
    return M.extract_terminal_content(bufnr, opts)
  end)
end

function M.cleanup()
  for watch_id in pairs(M.content_watchers) do
    M.stop_watching_content(watch_id)
  end
  M.extraction_queue = {}
  M.processing_queue = false
end

return M