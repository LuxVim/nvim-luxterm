local M = {}

function M.get_default_terminal_name(fallback)
  return fallback or 'default'
end

function M.validate_terminal_exists(terminal_name, session_module)
  if not session_module then
    session_module = require('luxterm.session')
  end
  
  local terminals = session_module.get_terminals()
  return terminals[terminal_name] ~= nil
end

function M.get_terminal_buffer_info(terminal_name, session_module)
  if not session_module then
    session_module = require('luxterm.session')
  end
  
  local terminals = session_module.get_terminals()
  return terminals[terminal_name]
end

function M.is_terminal_valid(terminal_name, session_module)
  if not session_module then
    session_module = require('luxterm.session')
  end
  
  local buffer_info = M.get_terminal_buffer_info(terminal_name, session_module)
  if not buffer_info then
    return false
  end
  
  return buffer_info.bufnr and vim.api.nvim_buf_is_valid(buffer_info.bufnr)
end

function M.ensure_terminal_exists_and_valid(terminal_name, session_module)
  if not session_module then
    session_module = require('luxterm.session')
  end
  
  terminal_name = M.get_default_terminal_name(terminal_name)
  
  if not M.validate_terminal_exists(terminal_name, session_module) then
    return nil, 'Terminal does not exist: ' .. terminal_name
  end
  
  if not M.is_terminal_valid(terminal_name, session_module) then
    return nil, 'Terminal buffer is not valid: ' .. terminal_name
  end
  
  return terminal_name, nil
end

return M