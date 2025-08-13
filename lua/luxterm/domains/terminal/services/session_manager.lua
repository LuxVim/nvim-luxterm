local Session = require("luxterm.domains.terminal.entities.session")
local event_bus = require("luxterm.infrastructure.events.event_bus")
local event_types = require("luxterm.infrastructure.events.event_types")

local M = {
  sessions = {},
  active_session_id = nil,
  session_counter = 0
}

function M.setup()
  M._setup_event_listeners()
end

function M._setup_event_listeners()
  event_bus.subscribe(event_types.TERMINAL_CLOSED, function(payload)
    if payload.bufnr then
      M._cleanup_session_by_bufnr(payload.bufnr)
    end
  end)
end

function M.create_session(opts)
  opts = opts or {}
  
  M.session_counter = M.session_counter + 1
  local session_id = M.session_counter
  
  local bufnr = vim.api.nvim_create_buf(false, true)
  if not bufnr then
    return nil, "Failed to create buffer"
  end
  
  local session = Session.new({
    id = session_id,
    bufnr = bufnr,
    name = opts.name,
    working_directory = opts.working_directory or vim.fn.getcwd(),
    shell_command = opts.shell_command,
    metadata = opts.metadata or {}
  })
  
  M.sessions[session_id] = session
  
  local current_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_set_current_buf(bufnr)
  
  local shell = opts.shell_command or vim.o.shell
  local term_opts = {
    cwd = session.working_directory,
    on_exit = function(job_id, exit_code, event_type)
      M._handle_terminal_exit(session_id, job_id, exit_code, event_type)
    end
  }
  
  local job_id = vim.fn.termopen(shell, term_opts)
  session.job_id = job_id
  
  vim.api.nvim_set_current_buf(current_buf)
  
  if not M.active_session_id then
    M.set_active_session(session_id)
  end
  
  event_bus.emit(event_types.SESSION_CREATED, {
    session_id = session_id,
    session = session
  })
  
  return session, nil
end

function M._handle_terminal_exit(session_id, job_id, exit_code, event_type)
  local session = M.sessions[session_id]
  if session then
    session.job_id = nil
    
    if exit_code == 0 then
      vim.schedule(function()
        M.remove_session(session_id)
      end)
    end
  end
end

function M.remove_session(session_id)
  local session = M.sessions[session_id]
  if not session then
    return false
  end
  
  session:close()
  M.sessions[session_id] = nil
  
  if M.active_session_id == session_id then
    local remaining_sessions = M.get_all_sessions()
    if #remaining_sessions > 0 then
      M.set_active_session(remaining_sessions[1].id)
    else
      M.active_session_id = nil
    end
  end
  
  return true
end

function M._cleanup_session_by_bufnr(bufnr)
  for session_id, session in pairs(M.sessions) do
    if session.bufnr == bufnr then
      M.remove_session(session_id)
      break
    end
  end
end

function M.get_session(session_id)
  return M.sessions[session_id]
end

function M.get_all_sessions()
  local session_list = {}
  for _, session in pairs(M.sessions) do
    if session:is_valid() then
      table.insert(session_list, session)
    end
  end
  
  table.sort(session_list, function(a, b)
    return a.id < b.id
  end)
  
  return session_list
end

function M.get_active_session()
  if M.active_session_id then
    return M.sessions[M.active_session_id]
  end
  return nil
end

function M.set_active_session(session_id)
  local old_session = M.get_active_session()
  if old_session then
    old_session:deactivate()
  end
  
  M.active_session_id = session_id
  local new_session = M.get_session(session_id)
  
  if new_session then
    new_session:activate()
    return true
  end
  
  return false
end

function M.switch_to_session(session_id)
  local session = M.get_session(session_id)
  if session and session:is_valid() then
    session:focus()
    M.set_active_session(session_id)
    return true
  end
  return false
end

function M.get_next_session_id()
  local sessions = M.get_all_sessions()
  if #sessions <= 1 then
    return nil
  end
  
  local current_index = 1
  if M.active_session_id then
    for i, session in ipairs(sessions) do
      if session.id == M.active_session_id then
        current_index = i
        break
      end
    end
  end
  
  local next_index = (current_index % #sessions) + 1
  return sessions[next_index].id
end

function M.get_previous_session_id()
  local sessions = M.get_all_sessions()
  if #sessions <= 1 then
    return nil
  end
  
  local current_index = 1
  if M.active_session_id then
    for i, session in ipairs(sessions) do
      if session.id == M.active_session_id then
        current_index = i
        break
      end
    end
  end
  
  local prev_index = current_index == 1 and #sessions or current_index - 1
  return sessions[prev_index].id
end

function M.cleanup_invalid_sessions()
  local invalid_sessions = {}
  
  for session_id, session in pairs(M.sessions) do
    if not session:is_valid() then
      table.insert(invalid_sessions, session_id)
    end
  end
  
  for _, session_id in ipairs(invalid_sessions) do
    M.remove_session(session_id)
  end
  
  return #invalid_sessions
end

function M.rename_session(session_id, new_name)
  local session = M.get_session(session_id)
  if session then
    return session:rename(new_name)
  end
  return false
end

function M.get_session_count()
  return vim.tbl_count(M.sessions)
end

function M.clear_all_sessions()
  for session_id in pairs(M.sessions) do
    M.remove_session(session_id)
  end
  M.active_session_id = nil
  M.session_counter = 0
end

return M