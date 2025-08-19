local M = {}

function M.setup(user_config)
  local success, result = pcall(require("luxterm.core").setup, user_config)
  
  if not success then
    vim.notify("Luxterm setup failed: " .. tostring(result), vim.log.levels.ERROR)
    return {}
  end
  
  return result
end

return M
