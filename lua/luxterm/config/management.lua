local defaults = require('luxterm.config.defaults')
local validation = require('luxterm.config.validation')

local M = {}

local config_cache = {}

function M.init()
  config_cache = vim.tbl_deep_extend('force', defaults.default_config, config_cache)
  validation.validate_config(config_cache)
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