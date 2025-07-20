local M = {}

local config = require('luxterm.config')

function M.setup_buffer(bufnr, terminal_name)
  vim.bo[bufnr].buftype = 'terminal'
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].swapfile = false
  
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

return M