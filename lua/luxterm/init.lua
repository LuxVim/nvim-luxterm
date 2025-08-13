local config = require("luxterm.config")
local state = require("luxterm.state")
local ui = require("luxterm.ui")
local sessions = require("luxterm.sessions")
local keymaps = require("luxterm.keymaps")

local M = {}

--- Setup plugin with user options
-- @param user_config table
function M.setup(user_config)
  config.setup(user_config)

  -- Register user commands
  vim.api.nvim_create_user_command("LuxtermToggle", function()
    M.toggle_manager()
  end, {})

  -- Setup global keymaps for terminal navigation
  keymaps.setup_global_keymaps()

  -- Autocommands for session tracking
  vim.api.nvim_create_autocmd("TermOpen", {
    callback = function() 
      sessions.add_current_terminal()
      keymaps.set_terminal_keymaps(vim.api.nvim_get_current_buf())
    end
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    callback = function() 
      sessions.remove_closed_terminals() 
    end
  })
end

--- Toggle the Luxterm UI
function M.toggle_manager()
  if state.is_manager_open() then
    ui.close_manager()
  else
    -- Close any open session window first
    local windows = state.get_windows()
    if windows.manager and vim.api.nvim_win_is_valid(windows.manager) then
      ui.close_session_window()
    end
    ui.open_manager()
  end
end

return M
