-- Consolidated session management - combines entity, manager, and repository
local M = {
  sessions = {},
  active_session_id = nil,
  next_id = 1
}

-- Session object constructor
local function create_session(opts)
  opts = opts or {}
  
  local session = {
    id = tostring(M.next_id),
    name = opts.name or ("Session " .. M.next_id),
    bufnr = opts.bufnr,
    created_at = vim.loop.now(),
    last_accessed = vim.loop.now()
  }
  
  M.next_id = M.next_id + 1
  
  -- Session methods
  function session:is_valid()
    return self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr)
  end
  
  function session:get_status()
    if not self:is_valid() then
      return "stopped"
    end
    
    -- Check if terminal is still running
    local job_id = vim.bo[self.bufnr].channel
    if job_id and job_id > 0 then
      return "running"
    end
    return "stopped"
  end
  
  function session:activate()
    M.active_session_id = self.id
    self.last_accessed = vim.loop.now()
  end
  
  function session:get_content_preview()
    if not self:is_valid() then
      return {"[Terminal stopped]"}
    end
    
    local lines = vim.api.nvim_buf_get_lines(self.bufnr, -20, -1, false)
    if #lines == 0 then
      return {"[Empty terminal]"}
    end
    
    -- Trim empty lines and long lines for preview
    local preview = {}
    for _, line in ipairs(lines) do
      if #line > 0 then
        local trimmed = #line > 80 and (line:sub(1, 77) .. "...") or line
        table.insert(preview, trimmed)
      end
    end
    
    return #preview > 0 and preview or {"[Empty terminal]"}
  end
  
  return session
end

-- Session management functions
function M.create_session(opts)
  opts = opts or {}
  
  -- Create terminal buffer if not provided
  local bufnr = opts.bufnr
  if not bufnr then
    -- Create a completely fresh buffer for terminal
    bufnr = vim.api.nvim_create_buf(true, false)
    
    -- Switch to buffer temporarily to run termopen
    local current_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_buf(bufnr)
    vim.fn.termopen(vim.o.shell)
    vim.api.nvim_set_current_buf(current_buf)
  end
  
  local session = create_session({
    name = opts.name,
    bufnr = bufnr
  })
  
  M.sessions[session.id] = session
  
  if opts.activate ~= false then
    session:activate()
  end
  
  return session
end

function M.delete_session(session_id)
  local session = M.sessions[session_id]
  if not session then
    return false
  end
  
  -- Close terminal buffer if valid
  if session:is_valid() then
    vim.api.nvim_buf_delete(session.bufnr, {force = true})
  end
  
  M.sessions[session_id] = nil
  
  -- Update active session if needed
  if M.active_session_id == session_id then
    local remaining = M.get_all_sessions()
    M.active_session_id = #remaining > 0 and remaining[1].id or nil
  end
  
  return true
end

function M.switch_session(session_id)
  local session = M.sessions[session_id]
  if not session then
    return false
  end
  
  session:activate()
  return session
end

function M.get_session(session_id)
  return M.sessions[session_id]
end

function M.get_active_session()
  return M.active_session_id and M.sessions[M.active_session_id] or nil
end

function M.get_all_sessions()
  local sessions_list = {}
  for _, session in pairs(M.sessions) do
    table.insert(sessions_list, session)
  end
  
  -- Sort by last accessed (most recent first)
  table.sort(sessions_list, function(a, b)
    return a.last_accessed > b.last_accessed
  end)
  
  return sessions_list
end

function M.get_session_count()
  return vim.tbl_count(M.sessions)
end

function M.switch_to_next()
  local sessions = M.get_all_sessions()
  if #sessions <= 1 then
    return nil
  end
  
  local current_idx = 1
  if M.active_session_id then
    for i, session in ipairs(sessions) do
      if session.id == M.active_session_id then
        current_idx = i
        break
      end
    end
  end
  
  local next_idx = (current_idx % #sessions) + 1
  local next_session = sessions[next_idx]
  next_session:activate()
  return next_session
end

function M.switch_to_previous()
  local sessions = M.get_all_sessions()
  if #sessions <= 1 then
    return nil
  end
  
  local current_idx = 1
  if M.active_session_id then
    for i, session in ipairs(sessions) do
      if session.id == M.active_session_id then
        current_idx = i
        break
      end
    end
  end
  
  local prev_idx = current_idx == 1 and #sessions or current_idx - 1
  local prev_session = sessions[prev_idx]
  prev_session:activate()
  return prev_session
end

function M.delete_by_pattern(pattern)
  local deleted = {}
  for _, session in pairs(M.sessions) do
    if string.find(session.name, pattern) then
      M.delete_session(session.id)
      table.insert(deleted, session)
    end
  end
  return deleted
end

function M.cleanup_invalid_sessions()
  local to_delete = {}
  for session_id, session in pairs(M.sessions) do
    if not session:is_valid() then
      table.insert(to_delete, session_id)
    end
  end
  
  for _, session_id in ipairs(to_delete) do
    M.delete_session(session_id)
  end
  
  return #to_delete
end

-- Setup autocmds for automatic cleanup
function M.setup_autocmds()
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = vim.api.nvim_create_augroup("LuxtermSessionCleanup", {clear = true}),
    callback = function(args)
      -- Find and remove session with this buffer
      for session_id, session in pairs(M.sessions) do
        if session.bufnr == args.buf then
          M.delete_session(session_id)
          break
        end
      end
    end
  })
end

return M