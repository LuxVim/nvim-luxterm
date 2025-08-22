-- Consolidated session management - combines entity, manager, and repository
local utils = require("luxterm.utils")

local M = {
  sessions = {},
  active_session_id = nil,
  next_id = 1,
  buffer_session_map = {},
  max_sessions = 50,
  max_preview_lines = 100,
  last_cleanup_time = 0,
  cleanup_interval = 300000 -- 5 minutes in milliseconds
}

-- Smart line truncation for terminal content preview
function M.smart_truncate_line(line, max_length)
  if #line <= max_length then
    return line
  end
  
  -- Pattern to detect shell prompts: user@host:path$ command
  -- This handles common shells like bash, zsh, fish
  local prompt_patterns = {
    "^([^@]+@[^:]+:)(.+)(%$%s*.*)$",  -- user@host:path$ command
    "^([^@]+@[^:]+%s+)(.+)(%s+%$%s*.*)$",  -- user@host path $ command  
    "^(%[[^%]]+%]%s*)(.+)(%s*.*)$",    -- [user@host] path command
    "^([^%s]+%s+)(.+)(%s*.*)$"         -- simple prompt path command
  }
  
  for _, pattern in ipairs(prompt_patterns) do
    local prefix, path, suffix = line:match(pattern)
    if prefix and path and suffix then
      -- Calculate available space for the path (reserve space for prefix, suffix, and "...")
      local available_space = max_length - #prefix - #suffix - 3 -- 3 for "..."
      
      if available_space > 0 then
        local truncated_path = M.truncate_path(path, available_space)
        local result = prefix .. "..." .. truncated_path .. suffix
        
        -- If still too long, be more aggressive
        if #result > max_length then
          -- Try with just the last directory
          local last_dir = path:match("([^/]+)/?$")
          if last_dir then
            local minimal_result = prefix .. "..." .. last_dir .. suffix
            if #minimal_result <= max_length then
              return minimal_result
            end
          end
          -- If even that's too long, fall back to end truncation
          return "..." .. line:sub(-(max_length - 3))
        end
        
        return result
      end
    end
  end
  
  -- Fallback: if no prompt pattern matched, truncate from the start but preserve end
  -- This helps show commands at the end of long lines
  return "..." .. line:sub(-(max_length - 3))
end

-- Truncate path to show last N directories
function M.truncate_path(path, max_length)
  if #path <= max_length then
    return path
  end
  
  -- Split path into components
  local components = {}
  for component in path:gmatch("[^/]+") do
    table.insert(components, component)
  end
  
  if #components == 0 then
    return path:sub(-max_length)
  end
  
  -- For very limited space, just return the last directory
  if max_length < 10 then
    return components[#components]:sub(1, max_length)
  end
  
  -- Start with the last component (usually the current directory)
  local result = components[#components]
  local i = #components - 1
  
  -- Add previous directories until we run out of space (reserve 3 chars for "../")
  while i > 0 and #result + #components[i] + 4 <= max_length do -- 4 = 3 for "../" + 1 for "/"
    result = components[i] .. "/" .. result
    i = i - 1
  end
  
  -- Only add "../" if we actually truncated something and have space
  if i > 0 and #result + 3 <= max_length then
    result = "../" .. result
  elseif i > 0 then
    -- If we can't fit "../", just return last directory
    result = components[#components]
  end
  
  return result
end

-- Find the lowest available session number
local function find_lowest_session_number()
  local used_numbers = {}
  
  -- Extract numbers from existing default session names
  for _, session in pairs(M.sessions) do
    local num = string.match(session.name, "^Session (%d+)$")
    if num then
      used_numbers[tonumber(num)] = true
    end
  end
  
  local lowest = 1
  while used_numbers[lowest] do
    lowest = lowest + 1
  end
  
  return lowest
end

-- Session object constructor
local function create_session(opts)
  opts = opts or {}
  
  local session_number = find_lowest_session_number()
  
  -- Limit session names to 12 characters
  local name = opts.name or ("Session " .. session_number)
  if #name > 12 then
    name = string.sub(name, 1, 12)
  end
  
  local session = {
    id = tostring(M.next_id),
    name = name,
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
    
    -- Get buffer lines with memory-conscious limit
    local max_lines_to_read = math.min(M.max_preview_lines, 1000)
    local all_lines = vim.api.nvim_buf_get_lines(self.bufnr, -max_lines_to_read, -1, false)
    if #all_lines == 0 then
      return {"[Empty terminal]"}
    end
    
    -- Get the last 20 non-empty lines with size limit
    local lines = {}
    local total_chars = 0
    local max_total_chars = 4000 -- Limit total preview content size
    
    for i = #all_lines, 1, -1 do
      local line = all_lines[i]
      if line and #line > 0 then
        -- Check memory limit
        if total_chars + #line > max_total_chars then
          break
        end
        
        table.insert(lines, 1, line) -- Insert at beginning to maintain order
        total_chars = total_chars + #line
        
        if #lines >= 20 then
          break
        end
      end
    end
    
    if #lines == 0 then
      return {"[Empty terminal]"}
    end
    
    -- Trim long lines for preview with intelligent truncation
    local preview = {}
    for _, line in ipairs(lines) do
      local trimmed = M.smart_truncate_line(line, 80)
      table.insert(preview, trimmed)
    end
    
    return preview
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
  
  -- Ensure swap files are disabled for all luxterm terminal buffers
  utils.apply_buffer_options(bufnr, "terminal")
  
  local session = create_session({
    name = opts.name,
    bufnr = bufnr
  })
  
  M.sessions[session.id] = session
  M.buffer_session_map[session.bufnr] = session.id
  
  if opts.activate ~= false then
    session:activate()
  end
  
  return session
end

function M.delete_session(session_id, skip_buffer_delete)
  local session = M.sessions[session_id]
  if not session then
    return false
  end
  
  -- Clean up all references to prevent memory leaks
  local bufnr = session.bufnr
  
  -- Close terminal buffer if valid and not already being deleted
  if not skip_buffer_delete and session:is_valid() then
    vim.api.nvim_buf_delete(bufnr, {force = true})
  end
  
  -- Clean up buffer mapping
  if bufnr then
    M.buffer_session_map[bufnr] = nil
  end
  
  -- Clear session object references
  if session then
    session.bufnr = nil
    session.name = nil
    session.created_at = nil
    session.last_accessed = nil
  end
  
  -- Remove from sessions table
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

function M.get_session_by_buffer(bufnr)
  local session_id = M.buffer_session_map[bufnr]
  return session_id and M.sessions[session_id] or nil
end

function M.get_active_session()
  return M.active_session_id and M.sessions[M.active_session_id] or nil
end

function M.get_all_sessions()
  local sessions_list = {}
  for _, session in pairs(M.sessions) do
    table.insert(sessions_list, session)
  end
  
  -- Sort by session number (extracted from name for default sessions, then by name)
  table.sort(sessions_list, function(a, b)
    local num_a = string.match(a.name, "^Session (%d+)$")
    local num_b = string.match(b.name, "^Session (%d+)$")
    
    -- Both are default sessions (Session X) - sort by number
    if num_a and num_b then
      return tonumber(num_a) < tonumber(num_b)
    end
    
    -- One is default, one is custom - default sessions first
    if num_a and not num_b then
      return true
    elseif num_b and not num_a then
      return false
    end
    
    -- Both are custom named - sort alphabetically
    return a.name < b.name
  end)
  
  return sessions_list
end

function M.get_session_count()
  return vim.tbl_count(M.sessions)
end

-- Helper function to handle session switching edge cases
local function check_switch_conditions()
  local sessions = M.get_all_sessions()
  
  -- No sessions available
  if #sessions == 0 then
    return nil, nil
  end
  
  -- Single session - just activate and return it (prevents window hiding)
  if #sessions == 1 then
    local session = sessions[1]
    session:activate()
    return session, nil
  end
  
  -- Multiple sessions - return sessions and proceed with normal switching logic
  return nil, sessions
end

function M.switch_to_next()
  local early_return, sessions = check_switch_conditions()
  if early_return then
    return early_return
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
  local early_return, sessions = check_switch_conditions()
  if early_return then
    return early_return
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

function M.enforce_session_limits()
  local session_count = vim.tbl_count(M.sessions)
  
  if session_count > M.max_sessions then
    -- Get oldest sessions by creation time
    local sessions_by_age = {}
    for _, session in pairs(M.sessions) do
      table.insert(sessions_by_age, session)
    end
    
    table.sort(sessions_by_age, function(a, b)
      return a.created_at < b.created_at
    end)
    
    -- Delete oldest sessions beyond limit
    local to_delete = session_count - M.max_sessions
    for i = 1, to_delete do
      if sessions_by_age[i] and sessions_by_age[i].id ~= M.active_session_id then
        M.delete_session(sessions_by_age[i].id)
      end
    end
    
    return to_delete
  end
  
  return 0
end

function M.periodic_cleanup()
  local current_time = vim.loop.now()
  
  -- Only run cleanup every 5 minutes
  if current_time - M.last_cleanup_time < M.cleanup_interval then
    return 0, 0
  end
  
  M.last_cleanup_time = current_time
  
  local cleaned_invalid = M.cleanup_invalid_sessions()
  local cleaned_excess = M.enforce_session_limits()
  
  -- Force garbage collection after cleanup
  if cleaned_invalid > 0 or cleaned_excess > 0 then
    collectgarbage("collect")
  end
  
  return cleaned_invalid, cleaned_excess
end

-- Setup autocmds for automatic cleanup
function M.setup_autocmds()
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = vim.api.nvim_create_augroup("LuxtermSessionCleanup", {clear = true}),
    callback = function(args)
      -- Find and remove session with this buffer
      for session_id, session in pairs(M.sessions) do
        if session.bufnr == args.buf then
          -- Skip buffer deletion since it's already being wiped out
          M.delete_session(session_id, true)
          break
        end
      end
    end
  })
end

return M