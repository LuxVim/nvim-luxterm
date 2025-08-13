local state = require("luxterm.state")
local config = require("luxterm.config")

local M = {}

--- Create a new terminal session
-- @param name string|nil
-- @param open_in_floating_window boolean|nil
function M.create_session(name, open_in_floating_window)
  local session_id = state.get_next_session_id()
  local session_name = name or config.get_session_name(session_id)
  
  local bufnr = vim.api.nvim_create_buf(false, true)
  
  -- Create session object first to avoid duplicate tracking by TermOpen autocommand
  local session = {
    id = session_id,
    bufnr = bufnr,
    name = session_name,
    created_at = os.time()
  }
  
  -- Add to state before opening terminal to prevent autocommand duplication
  state.add_session(session)
  
  -- Switch to the buffer and open terminal
  local current_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_set_current_buf(bufnr)
  
  vim.fn.termopen(config.get_shell(), {
    on_exit = function()
      -- Only remove if session still exists (prevent double removal)
      if state.get_session_by_id(session_id) then
        M.remove_session(session_id)
        -- Close session window if it was opened in floating mode
        if open_in_floating_window then
          local ui = require("luxterm.ui")
          ui.close_session_window()
        end
      end
    end
  })
  
  -- Switch back to original buffer
  vim.api.nvim_set_current_buf(current_buf)
  state.set_active_session(session_id)
  
  -- If requested to open in floating window, close manager and open session window
  if open_in_floating_window then
    local ui = require("luxterm.ui")
    -- Close the manager if it's open
    if state.is_manager_open() then
      ui.close_manager()
    end
    -- Open the session in its own floating window
    ui.open_session_window(session)
  elseif config.options.focus_on_create then
    -- Original behavior: focus the terminal if configured to do so
    vim.api.nvim_set_current_buf(bufnr)
  end
  
  return session
end

--- Add currently active terminal to session list
function M.add_current_terminal()
  local current_buf = vim.api.nvim_get_current_buf()
  
  -- Only track luxterm floating terminal buffers, filter out all other buffers
  if vim.bo[current_buf].buftype == 'terminal' then
    -- Check if this is a luxterm managed terminal by checking if it was created through luxterm
    -- We can identify luxterm terminals by checking if they exist in our session state
    local already_in_sessions = false
    for _, session in ipairs(state.get_sessions()) do
      if session.bufnr == current_buf then
        already_in_sessions = true
        break
      end
    end
    
    -- If not already in sessions and not created by luxterm, filter it out
    -- Only allow terminals that are explicitly managed by luxterm
    if not already_in_sessions then
      -- Check if this terminal was created outside of luxterm - if so, ignore it
      local buf_name = vim.api.nvim_buf_get_name(current_buf)
      -- Filter out ALL external terminals - only track luxterm-created floating terminals
      return
    end
  end
end

--- Remove closed terminals from session list
function M.remove_closed_terminals()
  local sessions = state.get_sessions()
  local valid_sessions = {}
  
  for _, session in ipairs(sessions) do
    if vim.api.nvim_buf_is_valid(session.bufnr) then
      -- Only keep luxterm-managed terminal buffers
      -- Remove any buffer that's not a terminal or has been modified externally
      if vim.bo[session.bufnr].buftype == 'terminal' then
        table.insert(valid_sessions, session)
      elseif state.get_active_session() == session.id then
        state.set_active_session(nil)
      end
    elseif state.get_active_session() == session.id then
      state.set_active_session(nil)
    end
  end
  
  state.sessions = valid_sessions
end

--- Remove a specific session
-- @param session_id number
function M.remove_session(session_id)
  local session = state.get_session_by_id(session_id)
  if not session then
    return -- Session already removed
  end
  
  -- Remove from state first to prevent duplicate removal
  state.remove_session(session_id)
  
  -- Delete buffer if it's still valid, with error handling
  if vim.api.nvim_buf_is_valid(session.bufnr) then
    pcall(function()
      vim.api.nvim_buf_delete(session.bufnr, { force = true })
    end)
  end
  
  -- Update active session if needed
  if state.get_active_session() == session_id then
    local remaining = state.get_sessions()
    if #remaining > 0 then
      state.set_active_session(remaining[1].id)
    else
      state.set_active_session(nil)
    end
  end
end

--- Get all sessions (cached)
-- @return table
function M.get_sessions()
  return state.get_sessions()
end

--- Switch to a session by ID
-- @param session_id number
function M.switch_to_session(session_id)
  local session = state.get_session_by_id(session_id)
  if session and vim.api.nvim_buf_is_valid(session.bufnr) then
    vim.api.nvim_set_current_buf(session.bufnr)
    state.set_active_session(session_id)
    return true
  end
  return false
end

--- Get the active session
-- @return table|nil
function M.get_active_session()
  local active_id = state.get_active_session()
  if active_id then
    return state.get_session_by_id(active_id)
  end
  return nil
end

--- Get next session ID for navigation
-- @return number|nil
function M.get_next_session_id()
  local sessions = state.get_sessions()
  local active_id = state.get_active_session()
  
  if #sessions <= 1 then return nil end
  
  for i, session in ipairs(sessions) do
    if session.id == active_id then
      local next_index = (i % #sessions) + 1
      return sessions[next_index].id
    end
  end
  
  return sessions[1].id
end

--- Get previous session ID for navigation
-- @return number|nil
function M.get_previous_session_id()
  local sessions = state.get_sessions()
  local active_id = state.get_active_session()
  
  if #sessions <= 1 then return nil end
  
  for i, session in ipairs(sessions) do
    if session.id == active_id then
      local prev_index = i == 1 and #sessions or i - 1
      return sessions[prev_index].id
    end
  end
  
  return sessions[#sessions].id
end

return M
