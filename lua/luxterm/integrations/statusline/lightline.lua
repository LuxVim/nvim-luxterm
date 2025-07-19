local M = {}

function M.is_available()
  return vim.g.lightline ~= nil
end

function M.setup()
  if not vim.g.lightline then
    vim.g.lightline = {}
  end
  
  if not vim.g.lightline.component_function then
    vim.g.lightline.component_function = {}
  end
  
  vim.g.lightline.component_function.luxterm = 'v:lua.require("luxterm.statusline").get_compact_string'
  
  if not vim.g.lightline.active then
    vim.g.lightline.active = {}
  end
  
  if not vim.g.lightline.active.right then
    vim.g.lightline.active.right = {}
  end
  
  local has_luxterm = false
  for _, section in ipairs(vim.g.lightline.active.right) do
    if type(section) == 'table' then
      for _, component in ipairs(section) do
        if component == 'luxterm' then
          has_luxterm = true
          break
        end
      end
    end
    if has_luxterm then break end
  end
  
  if not has_luxterm then
    table.insert(vim.g.lightline.active.right, { 'luxterm' })
  end
  
  return true
end

function M.remove()
  if not vim.g.lightline then
    return false
  end
  
  if vim.g.lightline.component_function then
    vim.g.lightline.component_function.luxterm = nil
  end
  
  if vim.g.lightline.active and vim.g.lightline.active.right then
    for i, section in ipairs(vim.g.lightline.active.right) do
      if type(section) == 'table' then
        for j, component in ipairs(section) do
          if component == 'luxterm' then
            table.remove(section, j)
            if #section == 0 then
              table.remove(vim.g.lightline.active.right, i)
            end
            return true
          end
        end
      end
    end
  end
  
  return true
end

return M