local M = {}

function M.get_statusline_component()
  local providers = require('luxterm.statusline.providers')
  return providers.get_statusline_string()
end

function M.format_status_for_plugin(plugin_name)
  local providers = require('luxterm.statusline.providers')
  local status_string = providers.get_statusline_string()
  
  if plugin_name == 'airline' then
    return status_string ~= '' and string.format('%%{"%s"}', status_string) or ''
  elseif plugin_name == 'lightline' then
    return status_string
  else
    return status_string
  end
end

return M