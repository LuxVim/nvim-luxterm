local M = {}

local config = require('luxterm.config')

local sessions = {}
local current_session = 'default'
local last_terminal = 'default'

function M.init()
  M.load()
end

function M.get_current()
  return current_session
end

function M.set_current(session_name)
  current_session = session_name
  if not sessions[session_name] then
    sessions[session_name] = {
      terminals = {},
      last_terminal = 'default'
    }
  end
end

function M.get_terminals()
  if not sessions[current_session] then
    sessions[current_session] = {
      terminals = {},
      last_terminal = 'default'
    }
  end
  return sessions[current_session].terminals
end

function M.add_terminal(name, buffer_info)
  if not sessions[current_session] then
    sessions[current_session] = {
      terminals = {},
      last_terminal = 'default'
    }
  end
  sessions[current_session].terminals[name] = buffer_info
  sessions[current_session].last_terminal = name
  last_terminal = name
end

function M.remove_terminal(name)
  if sessions[current_session] and sessions[current_session].terminals[name] then
    sessions[current_session].terminals[name] = nil
    if sessions[current_session].last_terminal == name then
      local terminals = vim.tbl_keys(sessions[current_session].terminals)
      sessions[current_session].last_terminal = terminals[1] or 'default'
    end
  end
end

function M.get_last_terminal()
  if sessions[current_session] then
    return sessions[current_session].last_terminal
  end
  return 'default'
end

function M.set_last_terminal(name)
  if not sessions[current_session] then
    sessions[current_session] = {
      terminals = {},
      last_terminal = 'default'
    }
  end
  sessions[current_session].last_terminal = name
  last_terminal = name
end

function M.get_project_root()
  local markers = { '.git', 'package.json', 'Cargo.toml', 'go.mod', 'requirements.txt', 'Makefile' }
  
  local current_dir = vim.fn.getcwd()
  local root = current_dir
  
  while root ~= '/' do
    for _, marker in ipairs(markers) do
      if vim.fn.filereadable(root .. '/' .. marker) == 1 or 
         vim.fn.isdirectory(root .. '/' .. marker) == 1 then
        return root
      end
    end
    root = vim.fn.fnamemodify(root, ':h')
  end
  
  return current_dir
end

function M.switch_to_project()
  if not config.get('session_persistence') then
    return
  end
  
  local project_root = M.get_project_root()
  local project_name = vim.fn.fnamemodify(project_root, ':t')
  
  if project_name ~= current_session then
    M.set_current(project_name)
  end
end

function M.save()
  if not config.get('session_persistence') then
    return
  end
  
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
  if not config.get('session_persistence') then
    return
  end
  
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
          sessions = parsed_data.sessions or {}
          current_session = parsed_data.current_session or 'default'
        end
      end)
    end)
  end)
end

function M.clean()
  if not sessions[current_session] then
    return
  end
  
  local terminals = sessions[current_session].terminals
  for name, info in pairs(terminals) do
    if info.bufnr and not vim.api.nvim_buf_is_valid(info.bufnr) then
      terminals[name] = nil
    end
  end
end

function M.list()
  return vim.tbl_keys(sessions)
end

return M
