local event_bus = require("luxterm.infrastructure.events.event_bus")
local event_types = require("luxterm.infrastructure.events.event_types")

local Session = {}
Session.__index = Session

function Session.new(opts)
  opts = opts or {}
  
  local session = setmetatable({
    id = opts.id,
    bufnr = opts.bufnr,
    name = opts.name or "Terminal " .. (opts.id or 1),
    created_at = opts.created_at or os.time(),
    last_accessed = opts.last_accessed or os.time(),
    status = opts.status or "inactive",
    working_directory = opts.working_directory,
    shell_command = opts.shell_command,
    job_id = nil,
    metadata = opts.metadata or {}
  }, Session)
  
  session:_validate()
  return session
end

function Session:_validate()
  assert(self.id, "Session must have an ID")
  assert(self.bufnr, "Session must have a buffer number")
  assert(type(self.name) == "string", "Session name must be a string")
end

function Session:is_valid()
  return vim.api.nvim_buf_is_valid(self.bufnr) and vim.bo[self.bufnr].buftype == 'terminal'
end

function Session:is_running()
  if not self.job_id then
    local success, job_id = pcall(vim.api.nvim_buf_get_var, self.bufnr, 'terminal_job_id')
    if success and job_id > 0 then
      self.job_id = job_id
      return true
    end
    return false
  end
  
  return self.job_id > 0
end

function Session:get_status()
  if not self:is_valid() then
    return "invalid"
  end
  
  if self:is_running() then
    return "running"
  else
    return "stopped"
  end
end

function Session:activate()
  if self:is_valid() then
    self.last_accessed = os.time()
    self.status = "active"
    event_bus.emit(event_types.SESSION_SWITCHED, { 
      session_id = self.id,
      session = self 
    })
    return true
  end
  return false
end

function Session:deactivate()
  self.status = "inactive"
  return true
end

function Session:rename(new_name)
  if type(new_name) ~= "string" or new_name == "" then
    return false
  end
  
  local old_name = self.name
  self.name = new_name
  
  event_bus.emit(event_types.SESSION_RENAMED, {
    session_id = self.id,
    old_name = old_name,
    new_name = new_name,
    session = self
  })
  
  return true
end

function Session:get_content_lines(max_lines)
  if not self:is_valid() then
    return {"[Invalid session]"}
  end
  
  max_lines = max_lines or 50
  
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
  
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end
  
  if #lines > max_lines then
    lines = vim.list_slice(lines, #lines - max_lines + 1, #lines)
  end
  
  local cleaned_lines = {}
  for _, line in ipairs(lines) do
    local cleaned = line:gsub("\27%[[%d;]*[mK]", "")
    cleaned = cleaned:gsub("[\1-\8\11\12\14-\31\127]", "")
    table.insert(cleaned_lines, cleaned)
  end
  
  return cleaned_lines
end

function Session:get_display_info()
  return {
    id = self.id,
    name = self.name,
    status = self:get_status(),
    created_at = self.created_at,
    last_accessed = self.last_accessed,
    is_running = self:is_running(),
    working_directory = self.working_directory
  }
end

function Session:focus()
  if self:is_valid() then
    vim.api.nvim_set_current_buf(self.bufnr)
    self:activate()
    return true
  end
  return false
end

function Session:close(skip_buffer_delete)
  event_bus.emit(event_types.SESSION_DELETED, {
    session_id = self.id,
    session = self
  })
  
  if not skip_buffer_delete and self:is_valid() then
    pcall(function()
      vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end)
  end
  
  return true
end

function Session:update_metadata(key, value)
  self.metadata[key] = value
end

function Session:get_metadata(key)
  return self.metadata[key]
end

function Session:to_dict()
  return {
    id = self.id,
    bufnr = self.bufnr,
    name = self.name,
    created_at = self.created_at,
    last_accessed = self.last_accessed,
    status = self.status,
    working_directory = self.working_directory,
    shell_command = self.shell_command,
    metadata = self.metadata
  }
end

function Session.from_dict(data)
  return Session.new(data)
end

return Session