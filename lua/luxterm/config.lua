local M = {}

local default_config = {
  autostart = false,
  position = 'bottom',
  size = 20,
  filetype = 'sh',
  session_persistence = true,
  floating_window = true,
  floating_width = 0.8,
  floating_height = 0.6,
  floating_border = 'rounded',
  smart_position = true,
  focus_on_toggle = true,
  remember_size = true,
  statusline_integration = true,
  history_size = 100,
  shell_integration = true,
  auto_cd = true,
  terminal_title = true,
  quick_commands = {}
}

local config_cache = {}

function M.init()
  config_cache = vim.tbl_deep_extend('force', default_config, config_cache)
  M.validate_config()
end

function M.get(key)
  return config_cache[key]
end

function M.set(key, value)
  config_cache[key] = value
end

function M.get_all()
  return vim.tbl_deep_extend('force', {}, config_cache)
end

function M.validate_config()
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

function M.get_position_map()
  local positions = {
    bottom = { split = 'botright', direction = 'horizontal' },
    top = { split = 'topleft', direction = 'horizontal' },
    left = { split = 'topleft', direction = 'vertical' },
    right = { split = 'botright', direction = 'vertical' },
    floating = { split = 'floating', direction = 'floating' }
  }
  return positions
end

function M.get_smart_position()
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

function M.add_quick_command(name, command)
  config_cache.quick_commands[name] = command
end

function M.get_quick_command(name)
  return config_cache.quick_commands[name]
end

function M.get_quick_commands()
  return config_cache.quick_commands
end

return M