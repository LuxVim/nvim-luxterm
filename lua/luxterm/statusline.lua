local M = {}

local config = require('luxterm.config')

function M.init()
  if config.get('statusline_integration') then
    M.setup_integrations()
  end
end

function M.get_info()
  local session = require('luxterm.session')
  local terminals = session.get_terminals()
  local current_session = session.get_current()
  local last_terminal = session.get_last_terminal()
  
  local active_count = 0
  local terminal_names = {}
  
  for name, info in pairs(terminals) do
    if info.bufnr and vim.api.nvim_buf_is_valid(info.bufnr) then
      active_count = active_count + 1
      table.insert(terminal_names, name)
    end
  end
  
  return {
    session = current_session,
    active_count = active_count,
    terminal_names = terminal_names,
    last_terminal = last_terminal,
    total_count = vim.tbl_count(terminals)
  }
end

function M.get_status_string()
  local info = M.get_info()
  
  if info.active_count == 0 then
    return ''
  end
  
  return string.format('[T:%s(%d)]', info.session, info.active_count)
end

function M.get_compact_string()
  local info = M.get_info()
  
  if info.active_count == 0 then
    return ''
  end
  
  if info.active_count == 1 then
    return string.format('T:%s', info.last_terminal)
  else
    return string.format('T:%d', info.active_count)
  end
end

function M.get_detailed_string()
  local info = M.get_info()
  
  if info.active_count == 0 then
    return 'No terminals'
  end
  
  local names = table.concat(info.terminal_names, ', ')
  return string.format('Session: %s | Terminals: %s', info.session, names)
end

function M.setup_integrations()
  if vim.fn.exists('*airline#parts#define_function') == 1 then
    M.airline_integration()
  end
  
  if vim.g.lightline then
    M.lightline_integration()
  end
end

function M.airline_integration()
  vim.cmd([[
    if exists('*airline#parts#define_function')
      call airline#parts#define_function('luxterm', 'v:lua.require("luxterm.statusline").get_compact_string')
      let g:airline_section_x = get(g:, 'airline_section_x', '') . airline#section#create_right(['luxterm'])
    endif
  ]])
end

function M.lightline_integration()
  if not vim.g.lightline then
    vim.g.lightline = {}
  end
  
  if not vim.g.lightline.component_function then
    vim.g.lightline.component_function = {}
  end
  
  vim.g.lightline.component_function.luxterm = 'v:lua.require("luxterm.statusline").get_compact_string'
  
  if not vim.g.lightline.active then
    vim.g.lightline.active = {}
  end
  
  if not vim.g.lightline.active.right then
    vim.g.lightline.active.right = {}
  end
  
  table.insert(vim.g.lightline.active.right, { 'luxterm' })
end

function M.get_terminal_status(terminal_name)
  local session = require('luxterm.session')
  local terminals = session.get_terminals()
  local terminal = require('luxterm.terminal')
  
  if not terminals[terminal_name] then
    return 'inactive'
  end
  
  local info = terminals[terminal_name]
  if not info.bufnr or not vim.api.nvim_buf_is_valid(info.bufnr) then
    return 'invalid'
  end
  
  if terminal.is_active(terminal_name) then
    return 'active'
  else
    return 'hidden'
  end
end

function M.get_terminal_info(terminal_name)
  local session = require('luxterm.session')
  local terminals = session.get_terminals()
  
  if not terminals[terminal_name] then
    return nil
  end
  
  local info = terminals[terminal_name]
  return {
    name = terminal_name,
    bufnr = info.bufnr,
    position = info.position,
    size = info.size,
    status = M.get_terminal_status(terminal_name)
  }
end

function M.get_all_terminals_info()
  local session = require('luxterm.session')
  local terminals = session.get_terminals()
  local result = {}
  
  for name, _ in pairs(terminals) do
    local info = M.get_terminal_info(name)
    if info then
      table.insert(result, info)
    end
  end
  
  return result
end

return M