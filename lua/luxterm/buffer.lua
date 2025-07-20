local M = {}

local management = require('luxterm.buffer.management')

M.get = management.get
M.on_terminal_exit = management.on_terminal_exit
M.resize = management.resize
M.change_position = management.change_position
M.to_previous = management.to_previous

return M