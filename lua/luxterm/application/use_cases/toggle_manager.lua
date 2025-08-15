local session_manager = require("luxterm.domains.terminal.services.session_manager")
local session_list = require("luxterm.domains.ui.components.session_list")
local preview_pane = require("luxterm.domains.ui.components.preview_pane")
local layout_manager = require("luxterm.domains.ui.services.layout_manager")
local event_bus = require("luxterm.infrastructure.events.event_bus")
local event_types = require("luxterm.infrastructure.events.event_types")

local M = {}

function M.execute(params)
  params = params or {}
  
  -- Ensure we're not in terminal mode first
  if vim.fn.mode() == 't' then
    vim.cmd('stopinsert')
  end
  
  -- If manager is already open, close it
  if layout_manager.is_manager_open() then
    return M._close_manager(params)
  end
  
  -- Get the current active layout to check if it's a session
  local active_layout = layout_manager.get_active_layout()
  
  -- If we have an active session layout, close it before opening manager
  if active_layout and active_layout.type == "session" then
    layout_manager.close_layout(active_layout.id)
  end
  
  -- Always open the manager
  return M._open_manager(params)
end

function M._open_manager(params)
  session_manager.cleanup_invalid_sessions()
  
  local layout_id = layout_manager.create_manager_layout(params.layout_config)
  if not layout_id then
    return false, "Failed to create manager layout"
  end
  
  local layout = layout_manager.get_layout(layout_id)
  if not layout then
    return false, "Failed to get created layout"
  end
  
  local sessions = session_manager.get_all_sessions()
  local active_session = session_manager.get_active_session()
  
  
  -- If no sessions exist, don't auto-create one - just show empty manager
  if #sessions == 0 then
    active_session = nil
  elseif #sessions > 0 and not active_session then
    session_manager.set_active_session(sessions[1].id)
    active_session = sessions[1]
  end
  
  M._setup_manager_components(layout, sessions, active_session)
  M._setup_manager_event_handlers(layout_id)
  
  -- Ensure the session list gets focus and forces a refresh
  if layout and layout.windows and layout.windows.left and layout.windows.left.winid then
    local left_winid = layout.windows.left.winid
    if vim.api.nvim_win_is_valid(left_winid) then
      vim.api.nvim_set_current_win(left_winid)
      local session_list = require("luxterm.domains.ui.components.session_list")
      session_list.render()
    end
  end
  
  event_bus.emit(event_types.MANAGER_OPENED, {
    layout_id = layout_id,
    layout = layout,
    session_count = #sessions
  })
  
  return true, layout_id
end

function M._close_manager(params)
  local active_layout = layout_manager.get_active_layout()
  if not active_layout then
    return false, "No active manager layout to close"
  end
  
  local layout_id = active_layout.id
  local success = layout_manager.close_layout(layout_id)
  
  if success then
    event_bus.emit(event_types.MANAGER_CLOSED, {
      layout_id = layout_id,
      params = params
    })
  end
  
  return success, layout_id
end

function M._setup_manager_components(layout, sessions, active_session)
  session_list.update_sessions(sessions, active_session and active_session.id or nil)
  session_list.render()
  
  -- Only set up preview pane if we have a valid active session
  if active_session and active_session:is_valid() then
    preview_pane.set_session(active_session)
    preview_pane.preload_content(active_session)
  else
    -- Explicitly clear the preview pane when no valid session exists
    preview_pane.set_session(nil)
  end
  preview_pane.render()
end

function M._setup_manager_event_handlers(layout_id)
  local cleanup_handlers = {}
  
  local ui_action_handler = function(event_type)
    return function(payload)
      M._handle_ui_action(event_type, payload, layout_id)
    end
  end
  
  table.insert(cleanup_handlers, event_bus.subscribe(event_types.UI_ACTION_NEW_SESSION, ui_action_handler(event_types.UI_ACTION_NEW_SESSION)))
  table.insert(cleanup_handlers, event_bus.subscribe(event_types.UI_ACTION_DELETE_SESSION, ui_action_handler(event_types.UI_ACTION_DELETE_SESSION)))
  table.insert(cleanup_handlers, event_bus.subscribe(event_types.UI_ACTION_RENAME_SESSION, ui_action_handler(event_types.UI_ACTION_RENAME_SESSION)))
  table.insert(cleanup_handlers, event_bus.subscribe(event_types.UI_ACTION_SELECT_SESSION, ui_action_handler(event_types.UI_ACTION_SELECT_SESSION)))
  table.insert(cleanup_handlers, event_bus.subscribe(event_types.UI_ACTION_OPEN_SESSION, ui_action_handler(event_types.UI_ACTION_OPEN_SESSION)))
  table.insert(cleanup_handlers, event_bus.subscribe(event_types.UI_ACTION_CLOSE_MANAGER, ui_action_handler(event_types.UI_ACTION_CLOSE_MANAGER)))
  table.insert(cleanup_handlers, event_bus.subscribe(event_types.UI_ACTION_NAVIGATE_UP, ui_action_handler(event_types.UI_ACTION_NAVIGATE_UP)))
  table.insert(cleanup_handlers, event_bus.subscribe(event_types.UI_ACTION_NAVIGATE_DOWN, ui_action_handler(event_types.UI_ACTION_NAVIGATE_DOWN)))
  
  table.insert(cleanup_handlers, event_bus.subscribe(event_types.SESSION_CREATED, function(payload)
    M._refresh_manager_content()
  end))
  
  table.insert(cleanup_handlers, event_bus.subscribe(event_types.SESSION_DELETED, function(payload)
    M._refresh_manager_content()
  end))
  
  table.insert(cleanup_handlers, event_bus.subscribe(event_types.SESSION_SWITCHED, function(payload)
    M._refresh_manager_content()
  end))
  
  table.insert(cleanup_handlers, event_bus.subscribe(event_types.SESSION_RENAMED, function(payload)
    M._refresh_manager_content()
  end))
  
  local layout = layout_manager.get_layout(layout_id)
  if layout then
    layout.cleanup_handlers = cleanup_handlers
  end
  
  vim.api.nvim_create_autocmd("User", {
    pattern = "LuxtermManagerClosed",
    callback = function()
      for _, cleanup in ipairs(cleanup_handlers) do
        cleanup()
      end
    end,
    once = true
  })
end

function M._handle_ui_action(event_type, payload, layout_id)
  local create_session_use_case = require("luxterm.application.use_cases.create_session")
  local delete_session_use_case = require("luxterm.application.use_cases.delete_session")
  local switch_session_use_case = require("luxterm.application.use_cases.switch_session")
  
  if event_type == event_types.UI_ACTION_NEW_SESSION then
    create_session_use_case.execute()
    
  elseif event_type == event_types.UI_ACTION_DELETE_SESSION then
    delete_session_use_case.execute_active_session({ confirm = true })
    
  elseif event_type == event_types.UI_ACTION_RENAME_SESSION then
    M._handle_rename_session()
    
  elseif event_type == event_types.UI_ACTION_SELECT_SESSION then
    local index = payload and payload.index
    if index then
      switch_session_use_case.execute_and_open_floating(session_list.get_session_at_index(index).id)
    end
    
  elseif event_type == event_types.UI_ACTION_OPEN_SESSION then
    local active_session = session_manager.get_active_session()
    if active_session then
      switch_session_use_case.execute_and_open_floating(active_session.id)
    end
    
  elseif event_type == event_types.UI_ACTION_CLOSE_MANAGER then
    M._close_manager()
    
  elseif event_type == event_types.UI_ACTION_NAVIGATE_UP then
    session_list.navigate_to_session("up")
    
  elseif event_type == event_types.UI_ACTION_NAVIGATE_DOWN then
    session_list.navigate_to_session("down")
  end
end

function M._handle_rename_session()
  local active_session = session_manager.get_active_session()
  if not active_session then
    return
  end
  
  vim.ui.input({
    prompt = "New session name: ",
    default = active_session.name
  }, function(input)
    if input and input ~= "" and input ~= active_session.name then
      local success = active_session:rename(input)
      if success then
        M._refresh_manager_content()
        vim.notify("Renamed session to: " .. input, vim.log.levels.INFO)
      else
        vim.notify("Failed to rename session", vim.log.levels.ERROR)
      end
    end
  end)
end

function M._refresh_manager_content()
  if not layout_manager.is_manager_open() then
    return
  end
  
  vim.schedule(function()
    local sessions = session_manager.get_all_sessions()
    local active_session = session_manager.get_active_session()
    
    session_list.update_sessions(sessions, active_session and active_session.id or nil)
    session_list.render()
    
    if active_session then
      preview_pane.set_session(active_session)
    end
    preview_pane.render()
  end)
end

function M.open_manager(params)
  if layout_manager.is_manager_open() then
    return false, "Manager is already open"
  end
  
  return M._open_manager(params)
end

function M.close_manager(params)
  if not layout_manager.is_manager_open() then
    return false, "Manager is not open"
  end
  
  return M._close_manager(params)
end

function M.is_manager_open()
  return layout_manager.is_manager_open()
end

function M.focus_manager()
  if layout_manager.is_manager_open() then
    return layout_manager.focus_session_list()
  end
  return false
end

function M.get_manager_state()
  local is_open = layout_manager.is_manager_open()
  local layout = layout_manager.get_active_layout()
  
  return {
    is_open = is_open,
    layout_id = layout and layout.id or nil,
    session_count = session_manager.get_session_count(),
    active_session_id = session_manager.get_active_session() and session_manager.get_active_session().id or nil
  }
end

return M
