local M = {}

local display = require('luxterm.terminal.display')
local buffer = require('luxterm.buffer')

function M.show(terminal_name)
    local buffer_info = buffer.get(terminal_name)
    if buffer_info then
        display.show_terminal(terminal_name, buffer_info)
    end
end

function M.hide(terminal_name)
    display.hide_terminal(terminal_name)
end

function M.is_active(terminal_name)
    return display.is_terminal_visible(terminal_name)
end

function M.close(terminal_name)
    M.hide(terminal_name)
  
    local session = require('luxterm.session')
    local terminals = session.get_terminals()
  
    if terminals[terminal_name] then
        local buffer_info = terminals[terminal_name]
        if buffer_info.bufnr and vim.api.nvim_buf_is_valid(buffer_info.bufnr) then
            vim.api.nvim_buf_delete(buffer_info.bufnr, { force = true })
        end
        session.remove_terminal(terminal_name)
    end
end

return M