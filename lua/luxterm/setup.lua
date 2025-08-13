local plugin_orchestrator = require("luxterm.application.services.plugin_orchestrator")

local M = {}

function M.setup(user_config)
  local success, error_msg = pcall(plugin_orchestrator.initialize, user_config)
  
  if not success then
    vim.notify("Luxterm setup failed: " .. (error_msg or "Unknown error"), vim.log.levels.ERROR)
    return false
  end
  
  return plugin_orchestrator.get_public_api()
end

return M