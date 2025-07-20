local common = require('luxterm.core.common')

local M = {}

function M.get_terminal_status(name)
  name = common.get_default_name(name)
  
  return common.with_terminal_info(name, function(terminal_info)
    local terminal_manager = require('luxterm.core.terminal_manager')
    
    return {
      name = name,
      visible = terminal_manager.is_visible(name),
      bufnr = terminal_info.bufnr,
      chanid = terminal_info.chanid,
      position = terminal_info.position,
      size = terminal_info.size,
      directory = terminal_info.directory,
      created_at = terminal_info.created_at
    }
  end)
end

function M.get_compact_status_string(name)
  local status = M.get_terminal_status(name)
  if not status then
    return ''
  end
  
  local icon = status.visible and '●' or '○'
  return string.format('%s %s', icon, status.name)
end

function M.get_all_terminals_status()
  local terminal_manager = require('luxterm.core.terminal_manager')
  return terminal_manager.list()
end

function M.get_session_info()
  local session = require('luxterm.session')
  local terminals = M.get_all_terminals_status()
  
  local visible_count = 0
  local total_count = #terminals
  
  for _, terminal in ipairs(terminals) do
    if terminal.visible then
      visible_count = visible_count + 1
    end
  end
  
  return {
    total_terminals = total_count,
    visible_terminals = visible_count,
    project_root = session.get_project_root(),
    current_session = session.get_current_session(),
    terminals = terminals
  }
end

function M.get_statusline_string()
  local terminals = M.get_all_terminals_status()
  if #terminals == 0 then
    return ''
  end
  
  local visible_terminals = {}
  for _, terminal in ipairs(terminals) do
    if terminal.visible then
      table.insert(visible_terminals, terminal.name)
    end
  end
  
  if #visible_terminals == 0 then
    return string.format('LuxTerm(%d)', #terminals)
  elseif #visible_terminals == 1 then
    return string.format('LuxTerm:%s', visible_terminals[1])
  else
    return string.format('LuxTerm:%s+%d', visible_terminals[1], #visible_terminals - 1)
  end
end

function M.format_terminal_list()
  local terminals = M.get_all_terminals_status()
  if #terminals == 0 then
    return 'No terminals'
  end
  
  local lines = {}
  table.insert(lines, string.format('LuxTerm Terminals (%d):', #terminals))
  table.insert(lines, string.rep('-', 40))
  
  for _, terminal in ipairs(terminals) do
    local status_icon = terminal.visible and '●' or '○'
    local pos_info = terminal.position or 'default'
    local dir_info = vim.fn.fnamemodify(terminal.directory or '', ':t')
    
    table.insert(lines, string.format(
      '%s %-12s [%s] %s', 
      status_icon, 
      terminal.name, 
      pos_info, 
      dir_info
    ))
  end
  
  return table.concat(lines, '\n')
end

return M