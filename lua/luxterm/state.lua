local M = {
  manager_open = false,
  active_session = nil,
  sessions = {},
  windows = {
    manager = nil,
    left_pane = nil,
    right_pane = nil,
  },
  session_counter = 0,
}

function M.set_manager_open(open)
  M.manager_open = open
end

function M.is_manager_open()
  return M.manager_open
end

function M.set_active_session(session_id)
  M.active_session = session_id
end

function M.get_active_session()
  return M.active_session
end

function M.add_session(session)
  table.insert(M.sessions, session)
end

function M.remove_session(session_id)
  for i, session in ipairs(M.sessions) do
    if session.id == session_id then
      table.remove(M.sessions, i)
      break
    end
  end
end

function M.get_sessions()
  return M.sessions
end

function M.get_session_by_id(session_id)
  for _, session in ipairs(M.sessions) do
    if session.id == session_id then
      return session
    end
  end
  return nil
end

function M.set_windows(manager, left_pane, right_pane)
  M.windows.manager = manager
  M.windows.left_pane = left_pane
  M.windows.right_pane = right_pane
end

function M.get_windows()
  return M.windows
end

function M.clear_windows()
  M.windows.manager = nil
  M.windows.left_pane = nil
  M.windows.right_pane = nil
end

function M.get_next_session_id()
  M.session_counter = M.session_counter + 1
  return M.session_counter
end

return M
