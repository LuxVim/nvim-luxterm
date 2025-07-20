local common = require('luxterm.core.common')
local buffer_detect = require('luxterm.utils.buffer_detect')

local M = {}

function M.create_terminal_buffer(name, options)
  options = options or {}
  
  return common.with_config({'auto_cd', 'filetype', 'terminal_title', 'focus_on_toggle'}, function(config_values)
    local cwd = M.get_working_directory(config_values.auto_cd)
    local shell = vim.o.shell
    local bufnr = vim.api.nvim_create_buf(false, true)
    
    local chanid = M.create_terminal_in_buffer(bufnr, shell, cwd, name)
    if not chanid or chanid <= 0 then
      vim.api.nvim_buf_delete(bufnr, { force = true })
      return nil
    end
    
    local terminal_info = {
      bufnr = bufnr,
      chanid = chanid,
      terminal_name = name,
      position = options.position or config_values.position,
      size = options.size or config_values.size,
      directory = cwd,
      created_at = os.time()
    }
    
    M.setup_terminal_buffer(bufnr, name, config_values)
    return terminal_info
  end)
end

function M.create_terminal_in_buffer(bufnr, shell, cwd, name)
  local original_buf = vim.api.nvim_get_current_buf()
  local is_special = buffer_detect.is_special_buffer(original_buf)
  
  local chanid
  
  if is_special then
    chanid = M.create_in_temp_window(bufnr, shell, cwd, name)
  else
    chanid = M.create_in_current_context(bufnr, shell, cwd, name, original_buf)
  end
  
  return chanid
end

function M.create_in_temp_window(bufnr, shell, cwd, name)
  local temp_win = vim.api.nvim_open_win(bufnr, false, {
    relative = 'editor',
    width = 1, height = 1, row = 0, col = 0,
    style = 'minimal', focusable = false
  })
  
  vim.api.nvim_win_set_buf(temp_win, bufnr)
  
  local chanid
  vim.api.nvim_win_call(temp_win, function()
    chanid = vim.fn.termopen(shell, {
      cwd = cwd,
      on_exit = function(job_id, exit_code, event_type)
        M.on_terminal_exit(name, job_id, exit_code, event_type)
      end
    })
  end)
  
  if vim.api.nvim_win_is_valid(temp_win) then
    vim.api.nvim_win_close(temp_win, true)
  end
  
  return chanid
end

function M.create_in_current_context(bufnr, shell, cwd, name, original_buf)
  vim.api.nvim_set_current_buf(bufnr)
  
  local chanid = vim.fn.termopen(shell, {
    cwd = cwd,
    on_exit = function(job_id, exit_code, event_type)
      M.on_terminal_exit(name, job_id, exit_code, event_type)
    end
  })
  
  if vim.api.nvim_buf_is_valid(original_buf) then
    vim.api.nvim_set_current_buf(original_buf)
  end
  
  return chanid
end

function M.setup_terminal_buffer(bufnr, name, config_values)
  vim.bo[bufnr].buftype = 'terminal'
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = config_values.filetype or 'terminal'
  
  vim.b[bufnr].ts_highlight = false
  vim.bo[bufnr].syntax = "off"
  pcall(vim.treesitter.stop, bufnr)
  
  if config_values.terminal_title then
    vim.api.nvim_buf_set_name(bufnr, 'Terminal: ' .. name)
  end
  
  M.setup_buffer_autocmds(bufnr, config_values.focus_on_toggle)
end

function M.setup_buffer_autocmds(bufnr, focus_on_toggle)
  vim.api.nvim_create_autocmd('BufEnter', {
    buffer = bufnr,
    callback = function()
      vim.wo.number = false
      vim.wo.relativenumber = false
      vim.wo.signcolumn = 'no'
      
      if focus_on_toggle then
        vim.cmd('startinsert')
      end
    end
  })
end

function M.get_working_directory(auto_cd)
  local cwd = vim.fn.getcwd()
  
  if auto_cd then
    local session = require('luxterm.session')
    local project_root = session.get_project_root()
    if project_root and project_root ~= cwd then
      vim.cmd('cd ' .. project_root)
      return project_root
    end
  end
  
  return cwd
end

function M.update_terminal_name(bufnr, new_name)
  if vim.api.nvim_buf_is_valid(bufnr) then
    local config = require('luxterm.config')
    if config.get('terminal_title') then
      vim.api.nvim_buf_set_name(bufnr, 'Terminal: ' .. new_name)
    end
  end
end

function M.on_terminal_exit(name, job_id, exit_code, event_type)
  common.safe_operation(function()
    local session = require('luxterm.session')
    session.remove_terminal(name)
  end, 'Exit')
end

return M