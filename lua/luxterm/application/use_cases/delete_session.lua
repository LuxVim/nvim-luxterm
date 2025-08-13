local session_manager = require("luxterm.domains.terminal.services.session_manager")
local session_repository = require("luxterm.domains.terminal.repositories.session_repository")
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
  
  if params.confirm and not M._confirm_deletion(session) then
    return false, "Deletion cancelled by user"
  end
  
  local session_data = session:to_dict()
  
  local success = session_manager.remove_session(session_id)
  if not success then
    return false, "Failed to remove session from manager"
  end
  
  session_repository.delete_session(session_id)
  
  event_bus.emit(event_types.SESSION_DELETED, {
    session_id = session_id,
    session_data = session_data,
    params = params
  })
  
  return true, nil
end

function M.execute_active_session(params)
  local active_session = session_manager.get_active_session()
  if not active_session then
    return false, "No active session to delete"
  end
  
  return M.execute(active_session.id, params)
end

function M._confirm_deletion(session)
  local choice = vim.fn.confirm(
    "Delete session '" .. session.name .. "'?",
    "&Yes\n&No",
    2
  )
  return choice == 1
end

function M.execute_with_prompt()
  local sessions = session_manager.get_all_sessions()
  if #sessions == 0 then
    vim.notify("No sessions to delete", vim.log.levels.INFO)
    return false, "No sessions available"
  end
  
  local session_names = {}
  for i, session in ipairs(sessions) do
    table.insert(session_names, string.format("%d. %s", i, session.name))
  end
  
  vim.ui.select(session_names, {
    prompt = "Select session to delete:",
  }, function(choice, index)
    if choice and index then
      local session = sessions[index]
      local success, error_msg = M.execute(session.id, { confirm = true })
      
      if success then
        vim.notify("Deleted session: " .. session.name, vim.log.levels.INFO)
      else
        vim.notify("Failed to delete session: " .. (error_msg or "Unknown error"), vim.log.levels.ERROR)
      end
    end
  end)
end

function M.execute_multiple(session_ids, params)
  params = params or {}
  
  if not session_ids or #session_ids == 0 then
    return false, "No session IDs provided"
  end
  
  local results = {}
  local success_count = 0
  local error_count = 0
  
  for _, session_id in ipairs(session_ids) do
    local success, error_msg = M.execute(session_id, params)
    table.insert(results, {
      session_id = session_id,
      success = success,
      error = error_msg
    })
    
    if success then
      success_count = success_count + 1
    else
      error_count = error_count + 1
    end
  end
  
  local summary = string.format("Deleted %d/%d sessions", success_count, #session_ids)
  if error_count > 0 then
    summary = summary .. string.format(" (%d failed)", error_count)
  end
  
  return {
    success_count = success_count,
    error_count = error_count,
    results = results,
    summary = summary
  }
end

function M.execute_all_sessions(params)
  params = params or {}
  
  local sessions = session_manager.get_all_sessions()
  if #sessions == 0 then
    return false, "No sessions to delete"
  end
  
  if params.confirm then
    local choice = vim.fn.confirm(
      string.format("Delete all %d sessions?", #sessions),
      "&Yes\n&No",
      2
    )
    if choice ~= 1 then
      return false, "Deletion cancelled by user"
    end
  end
  
  local session_ids = {}
  for _, session in ipairs(sessions) do
    table.insert(session_ids, session.id)
  end
  
  return M.execute_multiple(session_ids, params)
end

function M.execute_inactive_sessions(params)
  params = params or {}
  
  local sessions = session_manager.get_all_sessions()
  local active_session = session_manager.get_active_session()
  local inactive_session_ids = {}
  
  for _, session in ipairs(sessions) do
    if not active_session or session.id ~= active_session.id then
      table.insert(inactive_session_ids, session.id)
    end
  end
  
  if #inactive_session_ids == 0 then
    return false, "No inactive sessions to delete"
  end
  
  if params.confirm then
    local choice = vim.fn.confirm(
      string.format("Delete %d inactive sessions?", #inactive_session_ids),
      "&Yes\n&No",
      2
    )
    if choice ~= 1 then
      return false, "Deletion cancelled by user"
    end
  end
  
  return M.execute_multiple(inactive_session_ids, params)
end

function M.execute_by_pattern(name_pattern, params)
  params = params or {}
  
  if not name_pattern or name_pattern == "" then
    return false, "Name pattern is required"
  end
  
  local matching_sessions = session_repository.find_sessions_by_name(name_pattern)
  if #matching_sessions == 0 then
    return false, "No sessions match the pattern: " .. name_pattern
  end
  
  local session_ids = {}
  for _, session in ipairs(matching_sessions) do
    table.insert(session_ids, session.id)
  end
  
  if params.confirm then
    local choice = vim.fn.confirm(
      string.format("Delete %d sessions matching '%s'?", #matching_sessions, name_pattern),
      "&Yes\n&No",
      2
    )
    if choice ~= 1 then
      return false, "Deletion cancelled by user"
    end
  end
  
  return M.execute_multiple(session_ids, params)
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
  
  return true, nil
end

return M