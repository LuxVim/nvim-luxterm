local M = {}

function M.setup(user_config)
  return require("luxterm.setup").setup(user_config)
end

return M
