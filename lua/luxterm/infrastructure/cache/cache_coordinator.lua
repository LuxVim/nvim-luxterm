local event_bus = require("luxterm.infrastructure.events.event_bus")
local event_types = require("luxterm.infrastructure.events.event_types")

local M = {
  cache_layers = {},
  invalidation_rules = {},
  stats = {
    hits = 0,
    misses = 0,
    invalidations = 0
  }
}

function M.setup()
  M._setup_event_listeners()
end

function M.register_cache_layer(layer_name, cache_impl)
  M.cache_layers[layer_name] = cache_impl
end

function M.register_invalidation_rule(event_type, affected_caches)
  if not M.invalidation_rules[event_type] then
    M.invalidation_rules[event_type] = {}
  end
  
  for _, cache_name in ipairs(affected_caches) do
    table.insert(M.invalidation_rules[event_type], cache_name)
  end
end

function M._setup_event_listeners()
  event_bus.subscribe(event_types.SESSION_CREATED, function(payload)
    M._invalidate_by_event(event_types.SESSION_CREATED, payload)
  end)
  
  event_bus.subscribe(event_types.SESSION_DELETED, function(payload)
    M._invalidate_by_event(event_types.SESSION_DELETED, payload)
  end)
  
  event_bus.subscribe(event_types.SESSION_SWITCHED, function(payload)
    M._invalidate_by_event(event_types.SESSION_SWITCHED, payload)
  end)
  
  event_bus.subscribe(event_types.SESSION_RENAMED, function(payload)
    M._invalidate_by_event(event_types.SESSION_RENAMED, payload)
  end)
  
  event_bus.subscribe(event_types.SESSION_CONTENT_CHANGED, function(payload)
    M._invalidate_by_event(event_types.SESSION_CONTENT_CHANGED, payload)
  end)
  
  event_bus.subscribe(event_types.CACHE_INVALIDATE_REQUESTED, function(payload)
    if payload and payload.cache_names then
      for _, cache_name in ipairs(payload.cache_names) do
        M._invalidate_cache(cache_name, payload.scope)
      end
    else
      M._invalidate_all()
    end
  end)
end

function M._invalidate_by_event(event_type, payload)
  local affected_caches = M.invalidation_rules[event_type]
  if not affected_caches then
    return
  end
  
  for _, cache_name in ipairs(affected_caches) do
    M._invalidate_cache(cache_name, payload)
  end
  
  M.stats.invalidations = M.stats.invalidations + #affected_caches
end

function M._invalidate_cache(cache_name, scope)
  local cache = M.cache_layers[cache_name]
  if not cache then
    return
  end
  
  if scope and scope.session_id and cache.invalidate_session then
    cache.invalidate_session(scope.session_id)
  elseif scope and scope.partial and cache.invalidate_partial then
    cache.invalidate_partial(scope.partial)
  elseif cache.invalidate then
    cache.invalidate()
  end
end

function M._invalidate_all()
  for cache_name, cache in pairs(M.cache_layers) do
    if cache.invalidate then
      cache.invalidate()
    end
  end
  
  M.stats.invalidations = M.stats.invalidations + vim.tbl_count(M.cache_layers)
end

function M.get_from_cache(cache_name, key, fetch_func)
  local cache = M.cache_layers[cache_name]
  if not cache then
    M.stats.misses = M.stats.misses + 1
    return fetch_func and fetch_func() or nil
  end
  
  local value = cache.get and cache.get(key)
  if value ~= nil then
    M.stats.hits = M.stats.hits + 1
    return value
  end
  
  M.stats.misses = M.stats.misses + 1
  if fetch_func then
    local fetched_value = fetch_func()
    if cache.set and fetched_value ~= nil then
      cache.set(key, fetched_value)
    end
    return fetched_value
  end
  
  return nil
end

function M.set_in_cache(cache_name, key, value)
  local cache = M.cache_layers[cache_name]
  if cache and cache.set then
    cache.set(key, value)
    return true
  end
  return false
end

function M.warm_cache(cache_name, key, fetch_func)
  if fetch_func then
    vim.schedule(function()
      M.get_from_cache(cache_name, key, fetch_func)
    end)
  end
end

function M.batch_warm_cache(cache_name, key_fetch_pairs)
  vim.schedule(function()
    for _, pair in ipairs(key_fetch_pairs) do
      local key, fetch_func = pair[1], pair[2]
      M.get_from_cache(cache_name, key, fetch_func)
    end
  end)
end

function M.cleanup_old_entries()
  for _, cache in pairs(M.cache_layers) do
    if cache.cleanup then
      cache.cleanup()
    end
  end
end

function M.get_stats()
  local total_requests = M.stats.hits + M.stats.misses
  local hit_rate = total_requests > 0 and (M.stats.hits / total_requests) * 100 or 0
  
  return {
    hits = M.stats.hits,
    misses = M.stats.misses,
    hit_rate = hit_rate,
    invalidations = M.stats.invalidations,
    cache_count = vim.tbl_count(M.cache_layers)
  }
end

function M.reset_stats()
  M.stats = {
    hits = 0,
    misses = 0,
    invalidations = 0
  }
end

return M