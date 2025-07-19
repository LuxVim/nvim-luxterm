local M = {}

function M.is_available()
  return vim.fn.exists('*airline#parts#define_function') == 1
end

function M.setup()
  if not M.is_available() then
    return false
  end
  
  vim.cmd([[
    if exists('*airline#parts#define_function')
      call airline#parts#define_function('luxterm', 'v:lua.require("luxterm.statusline").get_compact_string')
      let g:airline_section_x = get(g:, 'airline_section_x', '') . airline#section#create_right(['luxterm'])
    endif
  ]])
  
  return true
end

function M.remove()
  if not M.is_available() then
    return false
  end
  
  vim.cmd([[
    if exists('*airline#parts#define_function') && exists('g:airline_section_x')
      let g:airline_section_x = substitute(g:airline_section_x, 'airline#section#create_right(\[''luxterm''\])', '', 'g')
    endif
  ]])
  
  return true
end

return M