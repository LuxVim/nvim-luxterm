local M = {}

function M.setup_airline()
  if vim.fn.exists(':AirlineRefresh') == 2 then
    vim.g.airline_section_x = vim.g.airline_section_x or ''
    vim.g.airline_section_x = vim.g.airline_section_x .. '%{luxterm#statusline()}'
    vim.cmd('AirlineRefresh')
  end
end

function M.setup_lightline()
  if vim.g.lightline then
    local lightline = vim.g.lightline or {}
    lightline.component_function = lightline.component_function or {}
    lightline.component_function.luxterm = 'luxterm#statusline'
    
    lightline.active = lightline.active or {}
    lightline.active.right = lightline.active.right or {}
    
    if not vim.tbl_contains(vim.fn.flatten(lightline.active.right), 'luxterm') then
      table.insert(lightline.active.right, {'luxterm'})
    end
    
    vim.g.lightline = lightline
  end
end

function M.setup_lualine()
  local ok, lualine = pcall(require, 'lualine')
  if ok then
    local config = lualine.get_config()
    config.sections = config.sections or {}
    config.sections.lualine_x = config.sections.lualine_x or {}
    
    local formatting = require('luxterm.statusline.formatting')
    table.insert(config.sections.lualine_x, formatting.get_statusline_component)
    
    lualine.setup(config)
  end
end

function M.detect_and_setup()
  local config = require('luxterm.config')
  if not config.get('statusline_integration') then
    return
  end
  
  if vim.fn.exists(':AirlineRefresh') == 2 then
    M.setup_airline()
  elseif vim.g.lightline then
    M.setup_lightline()
  elseif pcall(require, 'lualine') then
    M.setup_lualine()
  end
end

return M