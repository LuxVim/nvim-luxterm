local M = {}

function M.setup(opts)
  opts = opts or {}
  
  local config = require('luxterm.config')
  
  for key, value in pairs(opts) do
    config.set(key, value)
  end
  
  require('luxterm').init()
end

return M