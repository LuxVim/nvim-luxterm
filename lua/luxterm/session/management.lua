local M = {}

local sessions = {}
local current_session = 'default'
local last_terminal = 'default'

function M.get_current()
  return current_session
end

function M.set_current(session_name)
  current_session = session_name
  if not sessions[session_name] then
    sessions[session_name] = {
      terminals = {},
      last_terminal = 'default'
    }
  end
end

function M.get_terminals()
  if not sessions[current_session] then
    sessions[current_session] = {
      terminals = {},
      last_terminal = 'default'
    }
  end
  return sessions[current_session].terminals
end

function M.add_terminal(name, buffer_info)
  if not sessions[current_session] then
    sessions[current_session] = {
      terminals = {},
      last_terminal = 'default'
    }
  end
  sessions[current_session].terminals[name] = buffer_info
  sessions[current_session].last_terminal = name
  last_terminal = name
end

function M.remove_terminal(name)
  if sessions[current_session] and sessions[current_session].terminals[name] then
    sessions[current_session].terminals[name] = nil
    if sessions[current_session].last_terminal == name then
      local terminals = vim.tbl_keys(sessions[current_session].terminals)
      sessions[current_session].last_terminal = terminals[1] or 'default'
    end
  end
end

function M.get_last_terminal()
  if sessions[current_session] then
    return sessions[current_session].last_terminal
  end
  return 'default'
end

function M.set_last_terminal(name)
  if not sessions[current_session] then
    sessions[current_session] = {
      terminals = {},
      last_terminal = 'default'
    }
  end
  sessions[current_session].last_terminal = name
  last_terminal = name
end

function M.clean()
  if not sessions[current_session] then
    return
  end
  
  local terminals = sessions[current_session].terminals
  for name, info in pairs(terminals) do
    if info.bufnr and not vim.api.nvim_buf_is_valid(info.bufnr) then
      terminals[name] = nil
    end
  end
end

function M.list()
  return vim.tbl_keys(sessions)
end

function M.get_sessions()
  return sessions
end

function M.set_sessions(new_sessions)
  sessions = new_sessions
end

function M.get_current_session_name()
  return current_session
end

function M.set_current_session_name(name)
  current_session = name
end

return M