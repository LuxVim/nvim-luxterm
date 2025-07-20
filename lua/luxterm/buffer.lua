local M = {}

local config = require('luxterm.config')
local session = require('luxterm.session')

function M.get(terminal_name)
  local terminals = session.get_terminals()
  
  if terminals[terminal_name] then
    local buffer_info = terminals[terminal_name]
    if buffer_info.bufnr and vim.api.nvim_buf_is_valid(buffer_info.bufnr) then
      return buffer_info
    end
  end
  
  return M.create_terminal(terminal_name)
end

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
  
  -- Save current window and buffer context
  local original_buf = vim.api.nvim_get_current_buf()
  local original_win = vim.api.nvim_get_current_win()
  local buffer_detect = require('luxterm.utils.buffer_detect')
  
  -- Check if we're in a special buffer that shouldn't be modified
  local is_special_buffer = buffer_detect.is_special_buffer(original_buf)
  
  local chanid
  
  if is_special_buffer then
    -- For special buffers, create terminal without switching current buffer
    -- We'll create a temporary scratch window to run termopen
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
          M.on_terminal_exit(terminal_name, job_id, exit_code, event_type)
        end
      })
    end)
    
    -- Close the temporary window
    if vim.api.nvim_win_is_valid(temp_win) then
      vim.api.nvim_win_close(temp_win, true)
    end
  else
    -- For normal buffers, use the existing method
    vim.api.nvim_set_current_buf(bufnr)
    
    chanid = vim.fn.termopen(shell, {
      cwd = cwd,
      on_exit = function(job_id, exit_code, event_type)
        M.on_terminal_exit(terminal_name, job_id, exit_code, event_type)
      end
    })
    
    -- Restore original buffer
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
  
  M.setup_buffer(bufnr, terminal_name)
  session.add_terminal(terminal_name, buffer_info)
  
  return buffer_info
end

function M.setup_buffer(bufnr, terminal_name)
  vim.bo[bufnr].buftype = 'terminal'
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].swapfile = false
  
  -- Disable treesitter to prevent highlighting errors
  vim.b[bufnr].ts_highlight = false
  vim.bo[bufnr].syntax = "off"
  pcall(vim.treesitter.stop, bufnr)
  
  local filetype = config.get('filetype')
  if filetype then
    vim.bo[bufnr].filetype = filetype
  else
    vim.bo[bufnr].filetype = 'terminal'
  end
  
  if config.get('terminal_title') then
    vim.api.nvim_buf_set_name(bufnr, 'Terminal: ' .. terminal_name)
  end
  
  vim.api.nvim_create_autocmd('BufEnter', {
    buffer = bufnr,
    callback = function()
      vim.wo.number = false
      vim.wo.relativenumber = false
      vim.wo.signcolumn = 'no'
      
      if config.get('focus_on_toggle') then
        vim.cmd('startinsert')
      end
    end
  })
end

function M.on_terminal_exit(terminal_name, job_id, exit_code, event_type)
  local terminals = session.get_terminals()
  if terminals[terminal_name] then
    session.remove_terminal(terminal_name)
  end
end

function M.resize(terminal_name, size)
  local terminals = session.get_terminals()
  if terminals[terminal_name] then
    terminals[terminal_name].size = size
    require('luxterm.window').resize(terminal_name, size)
  end
end

function M.change_position(terminal_name, position)
  local terminals = session.get_terminals()
  if terminals[terminal_name] then
    terminals[terminal_name].position = position
    
    if require('luxterm.window').is_active(terminal_name) then
      require('luxterm.window').close(terminal_name)
      require('luxterm.window').open(terminal_name, terminals[terminal_name])
    end
  end
end

function M.to_previous()
  local win_id = vim.fn.win_getid()
  if vim.w.luxterm_previous_win then
    if vim.fn.win_gotoid(vim.w.luxterm_previous_win) == 0 then
      vim.cmd('wincmd p')
    end
  else
    vim.cmd('wincmd p')
  end
end

return M