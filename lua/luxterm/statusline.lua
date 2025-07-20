local info_provider = require('luxterm.services.info_provider')

local M = {}

function M.get_string()
    return info_provider.get_statusline_string()
end

function M.get_compact_string()
    return info_provider.get_statusline_string()
end

function M.setup_integrations()
    local airline = require('luxterm.integrations.statusline.airline')
    local lightline = require('luxterm.integrations.statusline.lightline')
  
    if airline.is_available() then
        airline.setup()
    end
  
    if lightline.is_available() then
        lightline.setup()
    end
end

function M.airline_integration()
    local airline = require('luxterm.integrations.statusline.airline')
    return airline.setup()
end

function M.lightline_integration()
    local lightline = require('luxterm.integrations.statusline.lightline')
    return lightline.setup()
end

function M.get_terminal_status(terminal_name)
    return info_provider.get_terminal_status(terminal_name)
end

return M
