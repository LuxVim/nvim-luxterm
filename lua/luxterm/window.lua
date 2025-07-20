local M = {}

local management = require('luxterm.window.management')

M.open = management.open
M.close = management.close
M.is_active = management.is_active
M.get_window_id = management.get_window_id
M.focus = management.focus
M.resize = management.resize
M.change_position = management.change_position
M.cache_size = management.cache_size
M.get_cached_size = management.get_cached_size

return M