local core = require("luxterm.core")

local M = {}

function M.setup(user_config)
  local success, result = pcall(core.setup, user_config)
  
  if not success then
    vim.notify("Luxterm setup failed: " .. tostring(result), vim.log.levels.ERROR)
    return {}
  end
  
  return result
end

return M