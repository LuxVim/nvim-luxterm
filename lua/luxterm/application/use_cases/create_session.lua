local session_manager = require("luxterm.domains.terminal.services.session_manager")
local session_repository = require("luxterm.domains.terminal.repositories.session_repository")
local layout_manager = require("luxterm.domains.ui.services.layout_manager")
local event_bus = require("luxterm.infrastructure.events.event_bus")
local event_types = require("luxterm.infrastructure.events.event_types")

local M = {}

function M.execute(params)
  params = params or {}
  
  local session, error_msg = session_manager.create_session({
    name = params.name,
    working_directory = params.working_directory,
    shell_command = params.shell_command,
    metadata = params.metadata
  })
  
  if not session then
    return nil, error_msg or "Failed to create session"
  end
  
  session_repository.save_session(session)
  
  if params.open_in_floating_window then
    M._open_session_in_floating_window(session, params)
  elseif params.focus_on_create then
    session:focus()
  end
  
  event_bus.emit(event_types.SESSION_CREATED, {
    session_id = session.id,
    session = session,
    params = params
  })
  
  return session, nil
end

function M.execute_and_open_floating(params)
  params = params or {}
  params.open_in_floating_window = true
  
  local session, error_msg = M.execute(params)
  if not session then
    return nil, error_msg
  end
  
  if layout_manager.is_manager_open() then
    local active_layout = layout_manager.get_active_layout()
    if active_layout then
      layout_manager.close_layout(active_layout.id)
    end
  end
  
  local layout_id = layout_manager.create_session_window_layout(session, params.layout_config)
  
  return session, nil, layout_id
end

function M._open_session_in_floating_window(session, params)
  vim.schedule(function()
    if layout_manager.is_manager_open() then
      local active_layout = layout_manager.get_active_layout()
      if active_layout then
        layout_manager.close_layout(active_layout.id)
      end
    end
    
    layout_manager.create_session_window_layout(session, params.layout_config)
  end)
end

function M.execute_with_prompt(params)
  params = params or {}
  
  local default_name = string.format("Terminal %d", session_manager.get_session_count() + 1)
  
  vim.ui.input({
    prompt = "Session name: ",
    default = params.name or default_name
  }, function(input)
    if input and input ~= "" then
      params.name = input
      local session, error_msg = M.execute(params)
      
      if not session then
        vim.notify("Failed to create session: " .. (error_msg or "Unknown error"), vim.log.levels.ERROR)
      else
        vim.notify("Created session: " .. session.name, vim.log.levels.INFO)
      end
    end
  end)
end

function M.execute_quick(name_suffix)
  local session_count = session_manager.get_session_count()
  local name = "Terminal " .. (session_count + 1)
  if name_suffix then
    name = name .. " " .. name_suffix
  end
  
  return M.execute({
    name = name
  })
end

function M.execute_from_current_directory()
  local cwd = vim.fn.getcwd()
  local dir_name = vim.fn.fnamemodify(cwd, ":t")
  
  return M.execute({
    name = "Terminal (" .. dir_name .. ")",
    working_directory = cwd,
    metadata = {
      created_from_directory = cwd
    }
  })
end

function M.execute_with_shell(shell_command, name)
  if not shell_command or shell_command == "" then
    return nil, "Shell command is required"
  end
  
  local session_name = name or ("Terminal (" .. shell_command .. ")")
  
  return M.execute({
    name = session_name,
    shell_command = shell_command,
    metadata = {
      custom_shell = shell_command
    }
  })
end

function M.validate_params(params)
  params = params or {}
  
  if params.name and type(params.name) ~= "string" then
    return false, "Session name must be a string"
  end
  
  if params.working_directory and type(params.working_directory) ~= "string" then
    return false, "Working directory must be a string"
  end
  
  if params.working_directory and not vim.fn.isdirectory(params.working_directory) then
    return false, "Working directory does not exist: " .. params.working_directory
  end
  
  if params.shell_command then
    if type(params.shell_command) ~= "string" then
      return false, "Shell command must be a string"
    end
    
    local shell_parts = vim.split(params.shell_command, " ")
    if not vim.fn.executable(shell_parts[1]) then
      return false, "Shell command not found: " .. shell_parts[1]
    end
  end
  
  return true, nil
end

return M