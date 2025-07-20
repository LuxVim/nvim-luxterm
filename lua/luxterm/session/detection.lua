local M = {}

function M.get_project_root()
  local markers = { '.git', 'package.json', 'Cargo.toml', 'go.mod', 'requirements.txt', 'Makefile' }
  
  local current_dir = vim.fn.getcwd()
  local root = current_dir
  
  while root ~= '/' do
    for _, marker in ipairs(markers) do
      if vim.fn.filereadable(root .. '/' .. marker) == 1 or 
         vim.fn.isdirectory(root .. '/' .. marker) == 1 then
        return root
      end
    end
    root = vim.fn.fnamemodify(root, ':h')
  end
  
  return current_dir
end

function M.switch_to_project()
  local config = require('luxterm.config')
  if not config.get('session_persistence') then
    return
  end
  
  local management = require('luxterm.session.management')
  local project_root = M.get_project_root()
  local project_name = vim.fn.fnamemodify(project_root, ':t')
  
  if project_name ~= management.get_current() then
    management.set_current(project_name)
  end
end

return M