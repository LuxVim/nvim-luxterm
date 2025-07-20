local M = {}

local config = require('luxterm.config')

local history = {}
local current_index = {}

function M.add_entry(terminal_name, command, directory)
  if not history[terminal_name] then
    history[terminal_name] = {}
  end
  
  local entry = {
    command = command,
    directory = directory,
    timestamp = os.time()
  }
  
  table.insert(history[terminal_name], entry)
  
  local max_size = config.get('history_size')
  if #history[terminal_name] > max_size then
    table.remove(history[terminal_name], 1)
  end
  
  current_index[terminal_name] = #history[terminal_name]
end

function M.get_previous(terminal_name)
  if not history[terminal_name] or #history[terminal_name] == 0 then
    return nil
  end
  
  local index = current_index[terminal_name] or #history[terminal_name]
  if index > 1 then
    current_index[terminal_name] = index - 1
    return history[terminal_name][current_index[terminal_name]].command
  end
  
  return nil
end

function M.get_next(terminal_name)
  if not history[terminal_name] or #history[terminal_name] == 0 then
    return nil
  end
  
  local index = current_index[terminal_name] or #history[terminal_name]
  if index < #history[terminal_name] then
    current_index[terminal_name] = index + 1
    return history[terminal_name][current_index[terminal_name]].command
  end
  
  return nil
end

function M.clear(terminal_name)
  if terminal_name then
    history[terminal_name] = {}
    current_index[terminal_name] = 0
  else
    history = {}
    current_index = {}
  end
end

function M.get_history(terminal_name)
  return history[terminal_name] or {}
end

function M.get_all_history()
  return history
end

function M.get_current_index(terminal_name)
  return current_index[terminal_name]
end

function M.set_history(hist)
  history = hist
end

function M.set_current_index(idx)
  current_index = idx
end

return M