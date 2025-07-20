local validation = require('luxterm.utils.validation')

local M = {}

function M.get_default_terminal_name(terminal_name)
  return validation.get_default_terminal_name(terminal_name or 'git')
end

function M.send_git_command(command, terminal_name)
  terminal_name = M.get_default_terminal_name(terminal_name)
  vim.notify('LuxTerm: Sending command "' .. command .. '" to terminal "' .. terminal_name .. '"', vim.log.levels.INFO)
  local terminal_manager = require('luxterm.core.terminal_manager')
  local result = terminal_manager.send_command(terminal_name, command, { show_terminal = true })
  if not result then
    vim.notify('LuxTerm: Failed to send command', vim.log.levels.WARN)
  end
end

function M.validate_args(args, required_args)
  if not args then
    args = {}
  end
  
  for _, arg in ipairs(required_args or {}) do
    if not args[arg] or args[arg] == '' then
      return false, 'Missing required argument: ' .. arg
    end
  end
  
  return true, nil
end

function M.build_command(base_cmd, options)
  local cmd = base_cmd
  
  if options then
    for key, value in pairs(options) do
      if value and value ~= '' then
        if type(value) == 'boolean' and value then
          cmd = cmd .. ' --' .. key
        elseif type(value) == 'string' then
          cmd = cmd .. ' --' .. key .. ' ' .. value
        end
      end
    end
  end
  
  return cmd
end

function M.notify_error(message)
  vim.notify('LuxTerm Git: ' .. message, vim.log.levels.WARN)
end

function M.notify_info(message)
  vim.notify('LuxTerm Git: ' .. message, vim.log.levels.INFO)
end

return M