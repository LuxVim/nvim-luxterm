local M = {}

local config = require('luxterm.config')

local history = {}
local current_index = {}

function M.init()
  M.load()
end

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
  M.save()
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

function M.search(terminal_name, pattern)
  if not history[terminal_name] then
    return {}
  end
  
  local results = {}
  for i, entry in ipairs(history[terminal_name]) do
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

function M.get_stats(terminal_name)
  if not history[terminal_name] then
    return {
      total_commands = 0,
      unique_commands = 0,
      most_recent = nil
    }
  end
  
  local commands = {}
  local most_recent = nil
  
  for _, entry in ipairs(history[terminal_name]) do
    commands[entry.command] = (commands[entry.command] or 0) + 1
    if not most_recent or entry.timestamp > most_recent.timestamp then
      most_recent = entry
    end
  end
  
  return {
    total_commands = #history[terminal_name],
    unique_commands = vim.tbl_count(commands),
    most_recent = most_recent
  }
end

function M.get_most_used_commands(terminal_name, limit)
  if not history[terminal_name] then
    return {}
  end
  
  limit = limit or 10
  local commands = {}
  
  for _, entry in ipairs(history[terminal_name]) do
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

function M.export_history(terminal_name, filename)
  if not history[terminal_name] then
    return false
  end
  
  local data = vim.fn.json_encode(history[terminal_name])
  vim.uv.fs_open(filename, 'w', 438, function(err, fd)
    if err or not fd then
      vim.notify('LuxTerm: Failed to open history file: ' .. (err or 'unknown'), vim.log.levels.WARN)
      return
    end
    
    vim.uv.fs_write(fd, data, -1, function(err)
      vim.uv.fs_close(fd, function() end)
      if err then
        vim.notify('LuxTerm: Failed to export history: ' .. err, vim.log.levels.WARN)
      end
    end)
  end)
  return true
end

function M.import_history(terminal_name, filename)
  vim.uv.fs_stat(filename, function(err, stat)
    if err or not stat then
      return
    end
    
    vim.uv.fs_open(filename, 'r', 438, function(err, fd)
      if err or not fd then
        return
      end
      
      vim.uv.fs_read(fd, stat.size, 0, function(err, data)
        vim.uv.fs_close(fd, function() end)
        
        if err or not data or data == '' then
          return
        end
        
        local ok, parsed_data = pcall(vim.fn.json_decode, data)
        if ok and parsed_data then
          history[terminal_name] = parsed_data
          current_index[terminal_name] = #parsed_data
          M.save()
        end
      end)
    end)
  end)
end

function M.save()
  local history_file = vim.fn.expand('~/.local/share/nvim/luxterm_history.json')
  local history_dir = vim.fn.fnamemodify(history_file, ':h')
  
  if vim.fn.isdirectory(history_dir) == 0 then
    vim.fn.mkdir(history_dir, 'p')
  end
  
  local data = vim.fn.json_encode({
    history = history,
    current_index = current_index
  })
  
  vim.uv.fs_open(history_file, 'w', 438, function(err, fd)
    if err or not fd then
      vim.notify('LuxTerm: Failed to open history file: ' .. (err or 'unknown'), vim.log.levels.WARN)
      return
    end
    
    vim.uv.fs_write(fd, data, -1, function(err)
      vim.uv.fs_close(fd, function() end)
      if err then
        vim.notify('LuxTerm: Failed to save history: ' .. err, vim.log.levels.WARN)
      end
    end)
  end)
end

function M.load()
  local history_file = vim.fn.expand('~/.local/share/nvim/luxterm_history.json')
  
  vim.uv.fs_stat(history_file, function(err, stat)
    if err or not stat then
      return
    end
    
    vim.uv.fs_open(history_file, 'r', 438, function(err, fd)
      if err or not fd then
        return
      end
      
      vim.uv.fs_read(fd, stat.size, 0, function(err, data)
        vim.uv.fs_close(fd, function() end)
        
        if err or not data then
          return
        end
        
        local ok, parsed_data = pcall(vim.fn.json_decode, data)
        if ok and parsed_data then
          history = parsed_data.history or {}
          current_index = parsed_data.current_index or {}
        end
      end)
    end)
  end)
end

function M.clear(terminal_name)
  if terminal_name then
    history[terminal_name] = {}
    current_index[terminal_name] = 0
  else
    history = {}
    current_index = {}
  end
  M.save()
end

function M.get_history(terminal_name)
  return history[terminal_name] or {}
end

return M