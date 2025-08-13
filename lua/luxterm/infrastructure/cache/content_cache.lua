local M = {
  terminal_content = {},
  content_hashes = {},
  max_age_seconds = 60,
  max_entries = 50
}

function M.setup(opts)
  opts = opts or {}
  M.max_age_seconds = opts.max_age_seconds or 60
  M.max_entries = opts.max_entries or 50
end

function M.get(cache_key)
  local entry = M.terminal_content[cache_key]
  if not entry then
    return nil
  end
  
  if os.time() - entry.timestamp > M.max_age_seconds then
    M.terminal_content[cache_key] = nil
    M.content_hashes[cache_key] = nil
    return nil
  end
  
  return entry.content
end

function M.set(cache_key, content)
  M.terminal_content[cache_key] = {
    content = content,
    timestamp = os.time()
  }
  
  M.content_hashes[cache_key] = M._hash_content(content)
  
  M._cleanup_if_needed()
end

function M.get_hash(cache_key)
  return M.content_hashes[cache_key]
end

function M.has_content_changed(cache_key, new_content)
  local cached_hash = M.content_hashes[cache_key]
  if not cached_hash then
    return true
  end
  
  local new_hash = M._hash_content(new_content)
  return cached_hash ~= new_hash
end

function M._hash_content(content)
  if type(content) == "table" then
    local combined = table.concat(content, "\n")
    return M._simple_hash(combined)
  elseif type(content) == "string" then
    return M._simple_hash(content)
  else
    return tostring(content)
  end
end

function M._simple_hash(str)
  local hash = 0
  for i = 1, #str do
    hash = (hash * 31 + string.byte(str, i)) % 2147483647
  end
  return tostring(hash)
end

function M.invalidate()
  M.terminal_content = {}
  M.content_hashes = {}
end

function M.invalidate_session(session_id)
  local session_key = "session_" .. session_id
  M.terminal_content[session_key] = nil
  M.content_hashes[session_key] = nil
end

function M.invalidate_partial(pattern)
  for key in pairs(M.terminal_content) do
    if string.match(key, pattern) then
      M.terminal_content[key] = nil
      M.content_hashes[key] = nil
    end
  end
end

function M._cleanup_if_needed()
  local entry_count = 0
  for _ in pairs(M.terminal_content) do
    entry_count = entry_count + 1
  end
  
  if entry_count <= M.max_entries then
    return
  end
  
  local entries_with_time = {}
  for key, entry in pairs(M.terminal_content) do
    table.insert(entries_with_time, {
      key = key,
      timestamp = entry.timestamp
    })
  end
  
  table.sort(entries_with_time, function(a, b)
    return a.timestamp < b.timestamp
  end)
  
  local to_remove = entry_count - M.max_entries
  for i = 1, to_remove do
    local key = entries_with_time[i].key
    M.terminal_content[key] = nil
    M.content_hashes[key] = nil
  end
end

function M.cleanup()
  local current_time = os.time()
  local expired_keys = {}
  
  for key, entry in pairs(M.terminal_content) do
    if (current_time - entry.timestamp) > M.max_age_seconds then
      table.insert(expired_keys, key)
    end
  end
  
  for _, key in ipairs(expired_keys) do
    M.terminal_content[key] = nil
    M.content_hashes[key] = nil
  end
end

return M