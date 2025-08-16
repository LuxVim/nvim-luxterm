local M = {
  rendered_content = {},
  generation_counter = 0,
  max_entries = 30
}

function M.setup(opts)
  opts = opts or {}
  M.max_entries = opts.max_entries or 30
end

function M.get(cache_key)
  local entry = M.rendered_content[cache_key]
  if entry then
    entry.last_accessed = os.time()
    return entry.content
  end
  return nil
end

function M.set(cache_key, content)
  M.generation_counter = M.generation_counter + 1
  
  M.rendered_content[cache_key] = {
    content = content,
    generation = M.generation_counter,
    last_accessed = os.time(),
    created_at = os.time()
  }
  
  M._cleanup_if_needed()
end

function M.invalidate()
  M.rendered_content = {}
  M.generation_counter = 0
end

function M.invalidate_session(session_id)
  local pattern = "session_" .. session_id
  M.invalidate_partial(pattern)
end

function M.invalidate_partial(pattern)
  local keys_to_remove = {}
  for key in pairs(M.rendered_content) do
    if string.match(key, pattern) then
      table.insert(keys_to_remove, key)
    end
  end
  
  for _, key in ipairs(keys_to_remove) do
    M.rendered_content[key] = nil
  end
end

function M.invalidate_by_type(content_type)
  local keys_to_remove = {}
  for key in pairs(M.rendered_content) do
    if string.match(key, "^" .. content_type .. "_") then
      table.insert(keys_to_remove, key)
    end
  end
  
  for _, key in ipairs(keys_to_remove) do
    M.rendered_content[key] = nil
  end
end

function M._cleanup_if_needed()
  local entry_count = 0
  for _ in pairs(M.rendered_content) do
    entry_count = entry_count + 1
  end
  
  if entry_count <= M.max_entries then
    return
  end
  
  local entries_with_priority = {}
  for key, entry in pairs(M.rendered_content) do
    local priority = entry.last_accessed + (entry.generation / 1000)
    table.insert(entries_with_priority, {
      key = key,
      priority = priority
    })
  end
  
  table.sort(entries_with_priority, function(a, b)
    return a.priority < b.priority
  end)
  
  local to_remove = entry_count - M.max_entries
  for i = 1, to_remove do
    local key = entries_with_priority[i].key
    M.rendered_content[key] = nil
  end
end

function M.cleanup()
  local current_time = os.time()
  local max_age = 300
  
  local expired_keys = {}
  for key, entry in pairs(M.rendered_content) do
    if (current_time - entry.created_at) > max_age then
      table.insert(expired_keys, key)
    end
  end
  
  for _, key in ipairs(expired_keys) do
    M.rendered_content[key] = nil
  end
end

function M.preload(cache_key, content_generator)
  if not M.rendered_content[cache_key] then
    vim.schedule(function()
      local content = content_generator()
      if content then
        M.set(cache_key, content)
      end
    end)
  end
end


return M