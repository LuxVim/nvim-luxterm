local M = {}

local config = require('luxterm.config')
local session = require('luxterm.session')

function M.create_terminal(terminal_name)
  local cwd = vim.fn.getcwd()
  
  if config.get('auto_cd') then
    local project_root = session.get_project_root()
    if project_root ~= cwd then
      vim.cmd('cd ' .. project_root)
    end
  end
  
  local shell = vim.o.shell
  local bufnr = vim.api.nvim_create_buf(false, true)
  
  local original_buf = vim.api.nvim_get_current_buf()
  local original_win = vim.api.nvim_get_current_win()
  local buffer_detect = require('luxterm.utils.buffer_detect')
  
  local is_special_buffer = buffer_detect.is_special_buffer(original_buf)
  
  local chanid
  
  if is_special_buffer then
    local temp_win = vim.api.nvim_open_win(bufnr, false, {
      relative = 'editor',
      width = 1,
      height = 1,
      row = 0,
      col = 0,
      style = 'minimal',
      focusable = false
    })
    
    vim.api.nvim_win_set_buf(temp_win, bufnr)
    
    vim.api.nvim_win_call(temp_win, function()
      chanid = vim.fn.termopen(shell, {
        cwd = cwd,
        on_exit = function(job_id, exit_code, event_type)
          require('luxterm.buffer').on_terminal_exit(terminal_name, job_id, exit_code, event_type)
        end
      })
    end)
    
    if vim.api.nvim_win_is_valid(temp_win) then
      vim.api.nvim_win_close(temp_win, true)
    end
  else
    vim.api.nvim_set_current_buf(bufnr)
    
    chanid = vim.fn.termopen(shell, {
      cwd = cwd,
      on_exit = function(job_id, exit_code, event_type)
        require('luxterm.buffer').on_terminal_exit(terminal_name, job_id, exit_code, event_type)
      end
    })
    
    if vim.api.nvim_buf_is_valid(original_buf) then
      vim.api.nvim_set_current_buf(original_buf)
    end
  end
  
  if chanid <= 0 then
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return nil
  end
  
  local buffer_info = {
    bufnr = bufnr,
    chanid = chanid,
    terminal_name = terminal_name,
    position = config.get('position'),
    size = config.get('size'),
    directory = cwd,
    created_at = os.time()
  }
  
  require('luxterm.buffer.setup').setup_buffer(bufnr, terminal_name)
  session.add_terminal(terminal_name, buffer_info)
  
  return buffer_info
end

return M