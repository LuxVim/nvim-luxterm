local M = {}

local session = require('luxterm.session')

function M.get(terminal_name)
  local terminals = session.get_terminals()
  
  if terminals[terminal_name] then
    local buffer_info = terminals[terminal_name]
    if buffer_info.bufnr and vim.api.nvim_buf_is_valid(buffer_info.bufnr) then
      return buffer_info
    end
  end
  
  return require('luxterm.buffer.creation').create_terminal(terminal_name)
end

function M.on_terminal_exit(terminal_name, job_id, exit_code, event_type)
  local terminals = session.get_terminals()
  if terminals[terminal_name] then
    session.remove_terminal(terminal_name)
  end
end

function M.resize(terminal_name, size)
  local terminals = session.get_terminals()
  if terminals[terminal_name] then
    terminals[terminal_name].size = size
    require('luxterm.window').resize(terminal_name, size)
  end
end

function M.change_position(terminal_name, position)
  local terminals = session.get_terminals()
  if terminals[terminal_name] then
    terminals[terminal_name].position = position
    
    if require('luxterm.window').is_active(terminal_name) then
      require('luxterm.window').close(terminal_name)
      require('luxterm.window').open(terminal_name, terminals[terminal_name])
    end
  end
end

function M.to_previous()
  local win_id = vim.fn.win_getid()
  if vim.w.luxterm_previous_win then
    if vim.fn.win_gotoid(vim.w.luxterm_previous_win) == 0 then
      vim.cmd('wincmd p')
    end
  else
    vim.cmd('wincmd p')
  end
end

return M