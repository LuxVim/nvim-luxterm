local M = {}

local core = require('luxterm.history.core')

function M.search(terminal_name, pattern)
  local history = core.get_history(terminal_name)
  if not history then
    return {}
  end
  
  local results = {}
  for i, entry in ipairs(history) do
    if entry.command:match(pattern) then
      table.insert(results, {
        index = i,
        command = entry.command,
        directory = entry.directory,
        timestamp = entry.timestamp
      })
    end
  end
  
  return results
end

function M.get_most_used_commands(terminal_name, limit)
  local history = core.get_history(terminal_name)
  if not history then
    return {}
  end
  
  limit = limit or 10
  local commands = {}
  
  for _, entry in ipairs(history) do
    commands[entry.command] = (commands[entry.command] or 0) + 1
  end
  
  local sorted = {}
  for cmd, count in pairs(commands) do
    table.insert(sorted, { command = cmd, count = count })
  end
  
  table.sort(sorted, function(a, b) return a.count > b.count end)
  
  local result = {}
  for i = 1, math.min(limit, #sorted) do
    table.insert(result, sorted[i])
  end
  
  return result
end

return M