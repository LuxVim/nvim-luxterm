local M = {}

local session = require('luxterm.session')
local config = require('luxterm.config')

function M.with_terminal_info(terminal_name, callback)
  if not terminal_name or not callback then
    return nil, 'Missing required parameters'
  end
  
  local terminals = session.get_terminals()
  local terminal_info = terminals[terminal_name]
  
  if not terminal_info then
    return nil, 'Terminal not found: ' .. terminal_name
  end
  
  if not terminal_info.bufnr or not vim.api.nvim_buf_is_valid(terminal_info.bufnr) then
    return nil, 'Terminal buffer invalid: ' .. terminal_name
  end
  
  return callback(terminal_info)
end

function M.with_config(keys, callback)
  if not keys or not callback then
    return nil, 'Missing required parameters'
  end
  
  local values = {}
  if type(keys) == 'string' then
    values = config.get(keys)
  else
    for _, key in ipairs(keys) do
      values[key] = config.get(key)
    end
  end
  
  return callback(values)
end

function M.safe_operation(operation, error_context)
  local success, result = pcall(operation)
  if not success then
    M.notify_error(result, error_context)
    return nil, result
  end
  return result
end

function M.notify_error(message, context)
  local prefix = context and ('LuxTerm ' .. context .. ': ') or 'LuxTerm: '
  vim.notify(prefix .. message, vim.log.levels.WARN)
end

function M.notify_info(message, context)
  local prefix = context and ('LuxTerm ' .. context .. ': ') or 'LuxTerm: '
  vim.notify(prefix .. message, vim.log.levels.INFO)
end

function M.get_default_name(name, fallback)
  return name and name ~= '' and name or fallback or 'main'
end

function M.validate_args(args, required)
  if not args then
    return false, 'No arguments provided'
  end
  
  for _, key in ipairs(required or {}) do
    if not args[key] or args[key] == '' then
      return false, 'Missing required argument: ' .. key
    end
  end
  
  return true
end

return M