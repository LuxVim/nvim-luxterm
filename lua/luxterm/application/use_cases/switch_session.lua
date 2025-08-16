local session_manager = require("luxterm.domains.terminal.services.session_manager")
local session_repository = require("luxterm.domains.terminal.repositories.session_repository")
local layout_manager = require("luxterm.domains.ui.services.layout_manager")
local event_bus = require("luxterm.infrastructure.events.event_bus")
local event_types = require("luxterm.infrastructure.events.event_types")

local M = {}

function M.execute(session_id, params)
  params = params or {}
  
  if not session_id then
    return false, "Session ID is required"
  end
  
  local session = session_manager.get_session(session_id)
  if not session then
    return false, "Session not found: " .. session_id
  end
  
  if not session:is_valid() then
    return false, "Session is not valid: " .. session_id
  end
  
  local previous_session = session_manager.get_active_session()
  
  local success = session_manager.set_active_session(session_id)
  if not success then
    return false, "Failed to set active session"
  end
  
  if params.focus_session then
    session:focus()
  end
  
  session_repository.update_session(session)
  
  event_bus.emit(event_types.SESSION_SWITCHED, {
    session_id = session_id,
    session = session,
    previous_session = previous_session,
    params = params
  })
  
  return true, session
end

function M.execute_and_open_floating(session_id, params)
  params = params or {}
  
  local success, session_or_error = M.execute(session_id, params)
  if not success then
    return false, session_or_error
  end
  
  local session = session_or_error
  
  -- Close any active layout (manager or session)
  local active_layout = layout_manager.get_active_layout()
  if active_layout then
    layout_manager.close_layout(active_layout.id)
  end
  
  local layout_id = layout_manager.create_session_window_layout(session, params.layout_config)
  
  return true, session, layout_id
end

function M.execute_next_session(params)
  local next_session_id = session_manager.get_next_session_id()
  if not next_session_id then
    return false, "No next session available"
  end
  
  return M.execute(next_session_id, params)
end

function M.execute_previous_session(params)
  local prev_session_id = session_manager.get_previous_session_id()
  if not prev_session_id then
    return false, "No previous session available"
  end
  
  return M.execute(prev_session_id, params)
end

function M.execute_by_index(index, params)
  if not index or index < 1 then
    return false, "Invalid session index"
  end
  
  local sessions = session_manager.get_all_sessions()
  if index > #sessions then
    return false, "Session index out of range: " .. index
  end
  
  local session = sessions[index]
  return M.execute(session.id, params)
end

function M.execute_by_name(name, params)
  if not name or name == "" then
    return false, "Session name is required"
  end
  
  local sessions = session_repository.find_sessions_by_name("^" .. vim.pesc(name) .. "$")
  if #sessions == 0 then
    return false, "Session not found: " .. name
  end
  
  if #sessions > 1 then
    return false, "Multiple sessions with name: " .. name
  end
  
  return M.execute(sessions[1].id, params)
end

function M.execute_with_prompt(params)
  local sessions = session_manager.get_all_sessions()
  if #sessions == 0 then
    vim.notify("No sessions available", vim.log.levels.INFO)
    return false, "No sessions available"
  end
  
  local session_options = {}
  for i, session in ipairs(sessions) do
    local status = session:get_status()
    local status_icon = status == "running" and "🟢" or "🔴"
    table.insert(session_options, string.format("%s %d. %s", status_icon, i, session.name))
  end
  
  vim.ui.select(session_options, {
    prompt = "Select session to switch to:",
  }, function(choice, index)
    if choice and index then
      local session = sessions[index]
      local success, error_msg = M.execute(session.id, params)
      
      if success then
        vim.notify("Switched to session: " .. session.name, vim.log.levels.INFO)
      else
        vim.notify("Failed to switch to session: " .. (error_msg or "Unknown error"), vim.log.levels.ERROR)
      end
    end
  end)
end

function M.execute_recent_session(params)
  local sessions = session_manager.get_all_sessions()
  if #sessions == 0 then
    return false, "No sessions available"
  end
  
  table.sort(sessions, function(a, b)
    return a.last_accessed > b.last_accessed
  end)
  
  local recent_session = sessions[1]
  local active_session = session_manager.get_active_session()
  
  if active_session and recent_session.id == active_session.id and #sessions > 1 then
    recent_session = sessions[2]
  end
  
  return M.execute(recent_session.id, params)
end

function M.cycle_sessions(direction, params)
  direction = direction or "forward"
  
  if direction == "forward" then
    return M.execute_next_session(params)
  elseif direction == "backward" then
    return M.execute_previous_session(params)
  else
    return false, "Invalid direction: " .. direction
  end
end

function M.execute_and_close_manager(session_id, params)
  params = params or {}
  
  local success, session_or_error = M.execute(session_id, params)
  if not success then
    return false, session_or_error
  end
  
  if layout_manager.is_manager_open() then
    local active_layout = layout_manager.get_active_layout()
    if active_layout then
      layout_manager.close_layout(active_layout.id)
    end
  end
  
  return true, session_or_error
end

function M.validate_session_id(session_id)
  if not session_id then
    return false, "Session ID is required"
  end
  
  if type(session_id) ~= "number" then
    return false, "Session ID must be a number"
  end
  
  local session = session_manager.get_session(session_id)
  if not session then
    return false, "Session not found: " .. session_id
  end
  
  if not session:is_valid() then
    return false, "Session is not valid: " .. session_id
  end
  
  return true, nil
end

function M.get_switch_options()
  local sessions = session_manager.get_all_sessions()
  local active_session = session_manager.get_active_session()
  
  local options = {
    can_switch_next = session_manager.get_next_session_id() ~= nil,
    can_switch_previous = session_manager.get_previous_session_id() ~= nil,
    total_sessions = #sessions,
    active_session_id = active_session and active_session.id or nil
  }
  
  return options
end

return M