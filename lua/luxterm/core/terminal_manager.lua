local common = require('luxterm.core.common')
local command_sender = require('luxterm.core.command_sender')

local M = {}

function M.init()
  -- Initialize terminal manager
  local config = require('luxterm.config')
  config.init()
  return true
end

function M.create(name, options)
  name = common.get_default_name(name)
  options = options or {}
  
  return common.safe_operation(function()
    local buffer_service = require('luxterm.services.buffer_service')
    local session = require('luxterm.session')
    
    local terminals = session.get_terminals()
    if terminals[name] then
      return terminals[name]
    end
    
    local terminal_info = buffer_service.create_terminal_buffer(name, options)
    if not terminal_info then
      error('Failed to create terminal buffer')
    end
    
    session.add_terminal(name, terminal_info)
    return terminal_info
  end, 'Create')
end

function M.show(name)
  name = common.get_default_name(name)
  
  return common.with_terminal_info(name, function(terminal_info)
    local window_service = require('luxterm.services.window_service')
    return window_service.show_terminal(name, terminal_info)
  end)
end

function M.hide(name)
  name = common.get_default_name(name)
  local window_service = require('luxterm.services.window_service')
  return window_service.hide_terminal(name)
end

function M.toggle(name)
  name = common.get_default_name(name)
  
  if M.is_visible(name) then
    return M.hide(name)
  else
    local terminal_info = M.get_or_create(name)
    if terminal_info then
      return M.show(name)
    end
  end
  return false
end

function M.close(name)
  name = common.get_default_name(name)
  
  M.hide(name)
  
  return common.with_terminal_info(name, function(terminal_info)
    if terminal_info.bufnr and vim.api.nvim_buf_is_valid(terminal_info.bufnr) then
      vim.api.nvim_buf_delete(terminal_info.bufnr, { force = true })
    end
    
    local session = require('luxterm.session')
    session.remove_terminal(name)
    return true
  end)
end

function M.get_or_create(name, options)
  name = common.get_default_name(name)
  local session = require('luxterm.session')
  local terminals = session.get_terminals()
  
  if terminals[name] then
    local terminal_info = terminals[name]
    if terminal_info.bufnr and vim.api.nvim_buf_is_valid(terminal_info.bufnr) then
      return terminal_info
    end
  end
  
  return M.create(name, options)
end

function M.is_visible(name)
  name = common.get_default_name(name)
  local window_service = require('luxterm.services.window_service')
  return window_service.is_terminal_visible(name)
end

function M.send_command(name, command, options)
  name = common.get_default_name(name)
  M.get_or_create(name)
  return command_sender.send(name, command, options)
end

function M.focus(name)
  name = common.get_default_name(name)
  local window_service = require('luxterm.services.window_service')
  return window_service.focus_terminal(name)
end

function M.resize(name, size)
  name = common.get_default_name(name)
  local window_service = require('luxterm.services.window_service')
  return window_service.resize_terminal(name, size)
end

function M.change_position(name, position)
  name = common.get_default_name(name)
  local window_service = require('luxterm.services.window_service')
  return window_service.change_terminal_position(name, position)
end

function M.rename(old_name, new_name)
  old_name = common.get_default_name(old_name)
  new_name = common.get_default_name(new_name)
  
  if old_name == new_name then
    return true
  end
  
  return common.with_terminal_info(old_name, function(terminal_info)
    local session = require('luxterm.session')
    
    session.remove_terminal(old_name)
    terminal_info.terminal_name = new_name
    session.add_terminal(new_name, terminal_info)
    
    local buffer_service = require('luxterm.services.buffer_service')
    buffer_service.update_terminal_name(terminal_info.bufnr, new_name)
    
    return true
  end)
end

function M.list()
  local session = require('luxterm.session')
  local terminals = session.get_terminals()
  
  local result = {}
  for name, info in pairs(terminals) do
    table.insert(result, {
      name = name,
      visible = M.is_visible(name),
      bufnr = info.bufnr,
      position = info.position,
      directory = info.directory,
      created_at = info.created_at
    })
  end
  
  table.sort(result, function(a, b) return a.name < b.name end)
  return result
end

function M.navigate(direction)
  local terminals = M.list()
  if #terminals == 0 then
    return false
  end
  
  local current_idx = nil
  for i, terminal in ipairs(terminals) do
    if terminal.visible then
      current_idx = i
      break
    end
  end
  
  local next_idx
  if direction == 'next' then
    next_idx = current_idx and (current_idx % #terminals) + 1 or 1
  else -- 'prev'
    next_idx = current_idx and (current_idx - 2) % #terminals + 1 or #terminals
  end
  
  return M.toggle(terminals[next_idx].name)
end

return M