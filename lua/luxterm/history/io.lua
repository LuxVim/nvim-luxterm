local M = {}

local file_io = require('luxterm.utils.file_io')
local core = require('luxterm.history.core')

function M.export_history(terminal_name, filename)
  local history = core.get_history(terminal_name)
  if not history then
    return false
  end
  
  file_io.save_json_async(filename, history, function(success)
    if success then
      vim.notify('LuxTerm: History exported successfully', vim.log.levels.INFO)
    end
  end)
  return true
end

function M.import_history(terminal_name, filename)
  file_io.load_json_async(filename, function(parsed_data)
    if parsed_data then
      local all_history = core.get_all_history()
      all_history[terminal_name] = parsed_data
      core.set_history(all_history)
      
      local all_current_index = core.get_current_index()
      all_current_index[terminal_name] = #parsed_data
      core.set_current_index(all_current_index)
      
      M.save()
      vim.notify('LuxTerm: History imported successfully', vim.log.levels.INFO)
    end
  end)
end

function M.save()
  local history_file = file_io.get_data_file_path('luxterm_history.json')
  local data = {
    history = core.get_all_history(),
    current_index = core.get_current_index()
  }
  
  file_io.save_json_async(history_file, data)
end

function M.load()
  local history_file = file_io.get_data_file_path('luxterm_history.json')
  
  file_io.load_json_async(history_file, function(parsed_data)
    if parsed_data then
      core.set_history(parsed_data.history or {})
      core.set_current_index(parsed_data.current_index or {})
    end
  end)
end

return M