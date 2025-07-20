local M = {}

local core = require('luxterm.history.core')

function M.get_stats(terminal_name)
  local history = core.get_history(terminal_name)
  if not history then
    return {
      total_commands = 0,
      unique_commands = 0,
      most_recent = nil
    }
  end
  
  local commands = {}
  local most_recent = nil
  
  for _, entry in ipairs(history) do
    commands[entry.command] = (commands[entry.command] or 0) + 1
    if not most_recent or entry.timestamp > most_recent.timestamp then
      most_recent = entry
    end
  end
  
  return {
    total_commands = #history,
    unique_commands = vim.tbl_count(commands),
    most_recent = most_recent
  }
end

return M