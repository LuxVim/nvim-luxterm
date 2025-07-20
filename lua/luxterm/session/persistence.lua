local M = {}

function M.save()
  local config = require('luxterm.config')
  if not config.get('session_persistence') then
    return
  end
  
  local management = require('luxterm.session.management')
  local sessions = management.get_sessions()
  local current_session = management.get_current_session_name()
  
  local session_file = vim.fn.expand('~/.local/share/nvim/luxterm_sessions.json')
  local session_dir = vim.fn.fnamemodify(session_file, ':h')
  
  if vim.fn.isdirectory(session_dir) == 0 then
    vim.fn.mkdir(session_dir, 'p')
  end
  
  local clean_sessions = {}
  for session_name, session_data in pairs(sessions) do
    clean_sessions[session_name] = {
      terminals = {},
      last_terminal = session_data.last_terminal
    }
    
    for term_name, term_info in pairs(session_data.terminals) do
      clean_sessions[session_name].terminals[term_name] = {
        position = term_info.position,
        size = term_info.size,
        directory = term_info.directory
      }
    end
  end
  
  local json_data = vim.fn.json_encode({
    sessions = clean_sessions,
    current_session = current_session
  })
  
  vim.uv.fs_open(session_file, 'w', 438, function(err, fd)
    if err or not fd then
      vim.notify('LuxTerm: Failed to open session file: ' .. (err or 'unknown'), vim.log.levels.WARN)
      return
    end
    
    vim.uv.fs_write(fd, json_data, -1, function(err)
      vim.uv.fs_close(fd, function() end)
      if err then
        vim.notify('LuxTerm: Failed to save session: ' .. err, vim.log.levels.WARN)
      end
    end)
  end)
end

function M.load()
  local config = require('luxterm.config')
  if not config.get('session_persistence') then
    return
  end
  
  local management = require('luxterm.session.management')
  local session_file = vim.fn.expand('~/.local/share/nvim/luxterm_sessions.json')
  
  vim.uv.fs_stat(session_file, function(err, stat)
    if err or not stat then
      return
    end
    
    vim.uv.fs_open(session_file, 'r', 438, function(err, fd)
      if err or not fd then
        return
      end
      
      vim.uv.fs_read(fd, stat.size, 0, function(err, data)
        vim.uv.fs_close(fd, function() end)
        
        if err or not data then
          return
        end
        
        local ok, parsed_data = pcall(vim.fn.json_decode, data)
        if ok and parsed_data then
          management.set_sessions(parsed_data.sessions or {})
          management.set_current_session_name(parsed_data.current_session or 'default')
        end
      end)
    end)
  end)
end

return M