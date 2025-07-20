local terminal_manager = require('luxterm.core.terminal_manager')
local info_provider = require('luxterm.services.info_provider')

local M = {}

function M.toggle(name)
  return terminal_manager.toggle(name)
end

function M.show(name)
  return terminal_manager.show(name)
end

function M.hide(name)
  return terminal_manager.hide(name)
end

function M.send_command(name, command, options)
  return terminal_manager.send_command(name, command, options)
end

function M.close(name)
  return terminal_manager.close(name)
end

function M.focus(name)
  return terminal_manager.focus(name)
end

function M.resize(name, size)
  return terminal_manager.resize(name, size)
end

function M.change_position(name, position)
  return terminal_manager.change_position(name, position)
end

function M.rename(old_name, new_name)
  return terminal_manager.rename(old_name, new_name)
end

function M.list()
  return terminal_manager.list()
end

function M.next_terminal()
  return terminal_manager.navigate('next')
end

function M.prev_terminal()
  return terminal_manager.navigate('prev')
end

function M.get_status(name)
  return info_provider.get_terminal_status(name)
end

function M.get_statusline_string()
  return info_provider.get_statusline_string()
end

function M.print_status()
  print(info_provider.format_terminal_list())
end

function M.init()
  -- Initialize luxterm
  return terminal_manager.init()
end

function M.setup(opts)
  -- Setup function for nvim-luxterm configuration
  opts = opts or {}
  -- Configuration can be handled here if needed
  return M
end

return M