local M = {}

local management = require('luxterm.session.management')
local detection = require('luxterm.session.detection')
local persistence = require('luxterm.session.persistence')

function M.init()
  persistence.load()
end

M.get_current = management.get_current
M.set_current = management.set_current
M.get_terminals = management.get_terminals
M.add_terminal = management.add_terminal
M.remove_terminal = management.remove_terminal
M.get_last_terminal = management.get_last_terminal
M.set_last_terminal = management.set_last_terminal
M.clean = management.clean
M.list = management.list

M.get_project_root = detection.get_project_root
M.switch_to_project = detection.switch_to_project

M.save = persistence.save
M.load = persistence.load

return M
