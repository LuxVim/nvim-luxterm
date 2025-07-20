local M = {}

function M.is_special_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  
  local buftype = vim.bo[bufnr].buftype
  local filetype = vim.bo[bufnr].filetype
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  
  -- Check buffer type - any non-empty buftype indicates a special buffer
  if buftype ~= '' then
    return true
  end
  
  -- Check if buffer is not modifiable (often indicates special buffers)
  if not vim.bo[bufnr].modifiable then
    return true
  end
  
  -- Check for common special buffer characteristics
  local special_indicators = {
    -- Buffer has no name (scratch buffers, etc.)
    function() return bufname == '' end,
    
    -- Buffer name starts with special patterns
    function() 
      local special_prefixes = {
        '^%[.*%]$',        -- [Buffer Name] format
        '^__.*__$',        -- __name__ format  
        '^%*.*%*$',        -- *name* format
        '^term://',        -- terminal buffers
        '^oil://',         -- oil buffers
        '^fugitive://',    -- fugitive buffers
        '^gitsigns://',    -- gitsigns buffers
        '^diff://',        -- diff buffers
      }
      
      for _, pattern in ipairs(special_prefixes) do
        if string.match(bufname, pattern) then
          return true
        end
      end
      return false
    end,
    
    -- Check if buffer is readonly and not a normal file
    function()
      return vim.bo[bufnr].readonly and not vim.fn.filereadable(bufname)
    end,
    
    -- Check for special filetypes that indicate non-content buffers
    function()
      local special_ft_patterns = {
        'help',
        'qf',           -- quickfix
        'man',
        'diff',
        'git.*',        -- git-related filetypes
        '.*tree.*',     -- any tree-like interface
        'aerial',
        'neotest.*',
        'dap.*',
        'toggleterm',
        'terminal',
        'TelescopePrompt',
        'alpha',        -- dashboard
        'dashboard',
        'startify',
        'undotree',
        'tagbar',
        'vista.*',
        'minimap',
        'nerdtree',
        'outline',
        'symbols.*',
        'lazy',
        'mason',
        'lspinfo',
        'checkhealth',
        'noice',
      }
      
      for _, pattern in ipairs(special_ft_patterns) do
        if string.match(filetype or '', '^' .. pattern .. '$') then
          return true
        end
      end
      return false
    end,
    
    -- Check if buffer is unlisted (often special buffers)
    function()
      return not vim.bo[bufnr].buflisted
    end,
  }
  
  -- Run all checks
  for _, check in ipairs(special_indicators) do
    if check() then
      return true
    end
  end
  
  return false
end

function M.is_suitable_previous_window(win_id)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return false
  end
  
  local bufnr = vim.api.nvim_win_get_buf(win_id)
  
  -- Don't use special buffers as previous windows
  if M.is_special_buffer(bufnr) then
    return false
  end
  
  -- Check if it's a floating window (usually not suitable for returning to)
  local config = vim.api.nvim_win_get_config(win_id)
  if config.relative ~= '' then
    return false
  end
  
  -- Additional checks for window suitability
  local width = vim.api.nvim_win_get_width(win_id)
  local height = vim.api.nvim_win_get_height(win_id)
  
  -- Avoid very small windows (probably special purpose)
  if width < 10 or height < 3 then
    return false
  end
  
  return true
end

function M.find_suitable_previous_window(exclude_win)
  exclude_win = exclude_win or vim.api.nvim_get_current_win()
  
  local all_wins = vim.api.nvim_list_wins()
  local suitable_windows = {}
  
  for _, win_id in ipairs(all_wins) do
    if win_id ~= exclude_win and M.is_suitable_previous_window(win_id) then
      table.insert(suitable_windows, win_id)
    end
  end
  
  -- Prefer larger windows (more likely to be main content)
  table.sort(suitable_windows, function(a, b)
    local a_area = vim.api.nvim_win_get_width(a) * vim.api.nvim_win_get_height(a)
    local b_area = vim.api.nvim_win_get_width(b) * vim.api.nvim_win_get_height(b)
    return a_area > b_area
  end)
  
  return suitable_windows[1]
end

return M