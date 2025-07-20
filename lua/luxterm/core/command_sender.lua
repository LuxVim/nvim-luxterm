local common = require('luxterm.core.common')

local M = {}

function M.send(terminal_name, command, options)
  options = options or {}
  terminal_name = common.get_default_name(terminal_name)
  
  if not command or command == '' then
    common.notify_error('No command provided', 'Command')
    return false
  end
  
  return common.with_terminal_info(terminal_name, function(terminal_info)
    local chanid = terminal_info.chanid
    if not chanid or chanid <= 0 then
      common.notify_error('Invalid terminal channel: ' .. terminal_name, 'Command')
      return false
    end
    
    local cmd_to_send = command
    if options.add_newline ~= false then
      cmd_to_send = cmd_to_send .. '\n'
    end
    
    vim.api.nvim_chan_send(chanid, cmd_to_send)
    
    if options.track_history ~= false then
      M.track_command_in_history(terminal_name, command)
    end
    
    if options.show_terminal then
      require('luxterm.core.terminal_manager').show(terminal_name)
    end
    
    return true
  end)
end

function M.send_multiple(terminal_name, commands, options)
  options = options or {}
  local delay = options.delay or 100
  
  for i, command in ipairs(commands) do
    M.send(terminal_name, command, options)
    if i < #commands and delay > 0 then
      vim.defer_fn(function() end, delay)
    end
  end
end

function M.track_command_in_history(terminal_name, command)
  common.safe_operation(function()
    local history = require('luxterm.history')
    if history and history.add then
      history.add(terminal_name, command)
    end
  end, 'History')
end

return M