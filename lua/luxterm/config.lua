local M = {}

local management = require('luxterm.config.management')
local validation = require('luxterm.config.validation')
local defaults = require('luxterm.config.defaults')

M.init = management.init
M.get = management.get
M.set = management.set
M.get_all = management.get_all
M.add_quick_command = management.add_quick_command
M.get_quick_command = management.get_quick_command
M.get_quick_commands = management.get_quick_commands

function M.validate_config()
  validation.validate_config(management.get_all())
end

function M.get_smart_position()
  return validation.get_smart_position(management.get_all())
end

M.get_position_map = defaults.get_position_map

return M
