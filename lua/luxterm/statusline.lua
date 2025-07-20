local M = {}

local providers = require('luxterm.statusline.providers')
local formatting = require('luxterm.statusline.formatting')
local integration = require('luxterm.statusline.integration')

M.get_string = providers.get_statusline_string
M.get_compact_string = providers.get_statusline_string
M.get_terminal_status = providers.get_terminal_status

M.setup_integrations = integration.detect_and_setup
M.airline_integration = integration.setup_airline
M.lightline_integration = integration.setup_lightline

return M
