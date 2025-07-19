local M = {}

local config = require('luxterm.config')
local session = require('luxterm.session')
local history = require('luxterm.history')
local integration = require('luxterm.integration')
local statusline = require('luxterm.statusline')
local terminal = require('luxterm.terminal')

function M.setup(opts)
  return require('luxterm.setup').setup(opts)
end

function M.init()
  config.init()
  session.init()
  history.init()
  integration.init()
  statusline.init()
  
  local augroup = vim.api.nvim_create_augroup('luxterm_auto_session', { clear = true })
  
  vim.api.nvim_create_autocmd('VimEnter', {
    group = augroup,
    callback = function()
      session.switch_to_project()
    end
  })
  
  vim.api.nvim_create_autocmd('VimLeave', {
    group = augroup,
    callback = function()
      session.save()
    end
  })
  
  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    callback = function()
      if vim.bo.buftype == 'terminal' then
        session.clean()
      end
    end
  })
end

function M.toggle(terminal_name)
  terminal_name = terminal_name or 'default'
  
  if terminal.is_active(terminal_name) then
    terminal.hide(terminal_name)
  else
    terminal.show(terminal_name)
  end
end

function M.send_command(terminal_name, command)
  local terminals = session.get_terminals()
  
  if not terminals[terminal_name] then
    M.toggle(terminal_name)
    terminals = session.get_terminals()
  end
  
  local buffer_info = terminals[terminal_name]
  
  if not terminal.is_active(terminal_name) then
    terminal.show(terminal_name)
  end
  
  if buffer_info.bufnr and vim.api.nvim_buf_is_valid(buffer_info.bufnr) then
    vim.api.nvim_chan_send(buffer_info.chanid, command .. '\n')
    history.add_entry(terminal_name, command, vim.fn.getcwd())
  end
end

function M.list()
  local terminals = session.get_terminals()
  local result = {}
  
  for name, info in pairs(terminals) do
    local active = terminal.is_active(name) and '*' or ' '
    local bufnr = info.bufnr or -1
    local position = info.position or 'unknown'
    table.insert(result, string.format('%s %-15s (buf:%d, pos:%s)', active, name, bufnr, position))
  end
  
  return result
end

function M.kill(terminal_name)
  local terminals = session.get_terminals()
  
  if terminals[terminal_name] then
    local buffer_info = terminals[terminal_name]
    
    if terminal.is_active(terminal_name) then
      terminal.hide(terminal_name)
    end
    
    if buffer_info.bufnr and vim.api.nvim_buf_is_valid(buffer_info.bufnr) then
      vim.api.nvim_buf_delete(buffer_info.bufnr, { force = true })
    end
    
    session.remove_terminal(terminal_name)
  end
end

function M.rename(old_name, new_name)
  local terminals = session.get_terminals()
  
  if terminals[old_name] and not terminals[new_name] then
    local buffer_info = terminals[old_name]
    session.remove_terminal(old_name)
    session.add_terminal(new_name, buffer_info)
  end
end

function M.next_terminal()
  local terminals = vim.tbl_keys(session.get_terminals())
  local current = session.get_last_terminal()
  
  if #terminals == 0 then
    return
  end
  
  local index = vim.tbl_contains(terminals, current) and 
    vim.fn.index(terminals, current) + 1 or 1
  local next_index = (index % #terminals) + 1
  local next_terminal = terminals[next_index]
  
  M.toggle(next_terminal)
end

function M.prev_terminal()
  local terminals = vim.tbl_keys(session.get_terminals())
  local current = session.get_last_terminal()
  
  if #terminals == 0 then
    return
  end
  
  local index = vim.tbl_contains(terminals, current) and 
    vim.fn.index(terminals, current) + 1 or 1
  local prev_index = ((index - 2) % #terminals) + 1
  local prev_terminal = terminals[prev_index]
  
  M.toggle(prev_terminal)
end

return M