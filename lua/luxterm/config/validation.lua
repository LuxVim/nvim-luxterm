local M = {}

function M.validate_config(config_cache)
  local valid_positions = { 'bottom', 'top', 'left', 'right', 'floating' }
  local valid_borders = { 'none', 'single', 'double', 'rounded', 'solid', 'shadow' }
  
  if not vim.tbl_contains(valid_positions, config_cache.position) then
    config_cache.position = 'bottom'
  end
  
  if not vim.tbl_contains(valid_borders, config_cache.floating_border) then
    config_cache.floating_border = 'rounded'
  end
  
  if config_cache.floating_width < 0.1 or config_cache.floating_width > 1.0 then
    config_cache.floating_width = 0.8
  end
  
  if config_cache.floating_height < 0.1 or config_cache.floating_height > 1.0 then
    config_cache.floating_height = 0.6
  end
  
  if config_cache.history_size < 1 then
    config_cache.history_size = 100
  end
  
  if config_cache.size < 1 then
    config_cache.size = 20
  end
end

function M.get_smart_position(config_cache)
  if not config_cache.smart_position then
    return config_cache.position
  end
  
  local width = vim.o.columns
  local height = vim.o.lines
  
  if width > height * 2 then
    return 'right'
  elseif height > width then
    return 'bottom'
  else
    return config_cache.position
  end
end

return M