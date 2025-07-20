local M = {}

local control = require('luxterm.terminal.control')
local creation = require('luxterm.terminal.creation')
local display = require('luxterm.terminal.display')

M.show = control.show
M.hide = control.hide
M.is_active = control.is_active
M.close = control.close

M.create_terminal_buffer = creation.create_terminal_buffer
M.update_terminal_name = creation.update_terminal_name

M.show_terminal = display.show_terminal
M.hide_terminal = display.hide_terminal
M.is_terminal_visible = display.is_terminal_visible
M.focus_terminal = display.focus_terminal
M.resize_terminal = display.resize_terminal
M.change_terminal_position = display.change_terminal_position

return M
