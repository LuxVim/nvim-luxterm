local Session = require("luxterm.domains.terminal.entities.session")

local M = {
  storage = {},
  persistence_enabled = false,
  storage_file = nil
}

function M.setup(opts)
  opts = opts or {}
  M.persistence_enabled = opts.persistence_enabled or false
  M.storage_file = opts.storage_file or vim.fn.stdpath("data") .. "/luxterm_sessions.json"
  
  if M.persistence_enabled then
    M._load_from_storage()
  end
end

function M.save_session(session)
  if not session or not session.id then
    return false
  end
  
  M.storage[session.id] = session:to_dict()
  
  if M.persistence_enabled then
    M._persist_to_storage()
  end
  
  return true
end

function M.get_session(session_id)
  local session_data = M.storage[session_id]
  if session_data then
    return Session.from_dict(session_data)
  end
  return nil
end

function M.get_all_sessions()
  local sessions = {}
  for session_id, session_data in pairs(M.storage) do
    local session = Session.from_dict(session_data)
    if session:is_valid() then
      table.insert(sessions, session)
    end
  end
  
  table.sort(sessions, function(a, b)
    return a.last_accessed > b.last_accessed
  end)
  
  return sessions
end

function M.delete_session(session_id)
  M.storage[session_id] = nil
  
  if M.persistence_enabled then
    M._persist_to_storage()
  end
  
  return true
end

function M.update_session(session)
  if not session or not session.id then
    return false
  end
  
  M.storage[session.id] = session:to_dict()
  
  if M.persistence_enabled then
    M._persist_to_storage()
  end
  
  return true
end

function M.find_sessions_by_name(name_pattern)
  local matching_sessions = {}
  
  for _, session_data in pairs(M.storage) do
    if string.match(session_data.name, name_pattern) then
      local session = Session.from_dict(session_data)
      if session:is_valid() then
        table.insert(matching_sessions, session)
      end
    end
  end
  
  return matching_sessions
end

function M.find_sessions_by_status(status)
  local matching_sessions = {}
  
  for _, session_data in pairs(M.storage) do
    local session = Session.from_dict(session_data)
    if session:is_valid() and session:get_status() == status then
      table.insert(matching_sessions, session)
    end
  end
  
  return matching_sessions
end

function M.get_session_count()
  return vim.tbl_count(M.storage)
end

function M.cleanup_invalid_sessions()
  local invalid_session_ids = {}
  
  for session_id, session_data in pairs(M.storage) do
    local session = Session.from_dict(session_data)
    if not session:is_valid() then
      table.insert(invalid_session_ids, session_id)
    end
  end
  
  for _, session_id in ipairs(invalid_session_ids) do
    M.delete_session(session_id)
  end
  
  return #invalid_session_ids
end

function M.clear_all_sessions()
  M.storage = {}
  
  if M.persistence_enabled then
    M._persist_to_storage()
  end
end

function M._persist_to_storage()
  if not M.storage_file then
    return false
  end
  
  local encoded = vim.json.encode(M.storage)
  if not encoded then
    return false
  end
  
  local file = io.open(M.storage_file, "w")
  if not file then
    return false
  end
  
  file:write(encoded)
  file:close()
  
  return true
end

function M._load_from_storage()
  if not M.storage_file or not vim.fn.filereadable(M.storage_file) then
    return false
  end
  
  local file = io.open(M.storage_file, "r")
  if not file then
    return false
  end
  
  local content = file:read("*all")
  file:close()
  
  if not content or content == "" then
    return false
  end
  
  local success, decoded = pcall(vim.json.decode, content)
  if success and type(decoded) == "table" then
    local valid_sessions = {}
    for session_id, session_data in pairs(decoded) do
      if session_data and session_data.id then
        valid_sessions[session_id] = session_data
      end
    end
    M.storage = valid_sessions
    return true
  end
  
  return false
end

function M.export_sessions(export_file)
  export_file = export_file or (vim.fn.stdpath("data") .. "/luxterm_sessions_export.json")
  
  local export_data = {
    version = "1.0",
    exported_at = os.time(),
    sessions = M.storage
  }
  
  local encoded = vim.json.encode(export_data)
  if not encoded then
    return false, "Failed to encode session data"
  end
  
  local file = io.open(export_file, "w")
  if not file then
    return false, "Failed to open export file"
  end
  
  file:write(encoded)
  file:close()
  
  return true, export_file
end

function M.import_sessions(import_file)
  if not import_file or not vim.fn.filereadable(import_file) then
    return false, "Import file not found or not readable"
  end
  
  local file = io.open(import_file, "r")
  if not file then
    return false, "Failed to open import file"
  end
  
  local content = file:read("*all")
  file:close()
  
  local success, decoded = pcall(vim.json.decode, content)
  if not success or type(decoded) ~= "table" then
    return false, "Invalid import file format"
  end
  
  if decoded.sessions and type(decoded.sessions) == "table" then
    for session_id, session_data in pairs(decoded.sessions) do
      if session_data and session_data.id then
        M.storage[session_id] = session_data
      end
    end
    
    if M.persistence_enabled then
      M._persist_to_storage()
    end
    
    return true, "Sessions imported successfully"
  end
  
  return false, "No valid session data found in import file"
end

return M