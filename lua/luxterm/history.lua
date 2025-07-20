local M = {}

local core = require('luxterm.history.core')
local search = require('luxterm.history.search')
local stats = require('luxterm.history.stats')
local io = require('luxterm.history.io')

function M.init()
  io.load()
end

function M.add_entry(terminal_name, command, directory)
  core.add_entry(terminal_name, command, directory)
  io.save()
end

M.get_previous = core.get_previous
M.get_next = core.get_next
M.clear = function(terminal_name)
  core.clear(terminal_name)
  io.save()
end
M.get_history = core.get_history

M.search = search.search
M.get_most_used_commands = search.get_most_used_commands

M.get_stats = stats.get_stats

M.export_history = io.export_history
M.import_history = io.import_history
M.save = io.save
M.load = io.load

return M