local M = {}

local config = require('luxterm.config')
local floating = require('luxterm.window.floating')

local size_cache = {}

function M.open(terminal_name, buffer_info)
  local position = buffer_info.position or config.get('position')
  
  if config.get('floating_window') then
    position = 'floating'
  end
  
  if position == 'floating' then
    return floating.open_floating(terminal_name, buffer_info)
  else
    return require('luxterm.window.split').open_split(terminal_name, buffer_info)
  end
end

function M.close(terminal_name)
  local win_id = M.get_window_id(terminal_name)
  if win_id then
    local floating_window = floating.get_floating_window(terminal_name)
    if floating_window then
      floating.remove_floating_window(terminal_name)
    end
    
    if vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_win_close(win_id, false)
    end
  end
  
  require('luxterm.window.utils').restore_previous_window()
end

function M.is_active(terminal_name)
  local win_id = M.get_window_id(terminal_name)
  return win_id and vim.api.nvim_win_is_valid(win_id)
end

function M.get_window_id(terminal_name)
  local floating_window = floating.get_floating_window(terminal_name)
  if floating_window then
    return floating_window.win_id
  end
  
  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win_id) then
      local ok, name = pcall(vim.api.nvim_win_get_var, win_id, 'luxterm_terminal_name')
      if ok and name == terminal_name then
        return win_id
      end
    end
  end
  
  return nil
end

function M.focus(terminal_name)
  local win_id = M.get_window_id(terminal_name)
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_set_current_win(win_id)
    if config.get('focus_on_toggle') then
      vim.cmd('startinsert')
    end
  end
end

function M.resize(terminal_name, size)
  local win_id = M.get_window_id(terminal_name)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return
  end
  
  local session = require('luxterm.session')
  local terminals = session.get_terminals()
  local buffer_info = terminals[terminal_name]
  
  if not buffer_info then
    return
  end
  
  local position = buffer_info.position or config.get('position')
  
  if position == 'floating' then
    local width = math.floor(vim.o.columns * (size / 100))
    local height = math.floor(vim.o.lines * (size / 100))
    
    vim.api.nvim_win_set_config(win_id, {
      width = width,
      height = height
    })
  else
    if position == 'left' or position == 'right' then
      vim.api.nvim_win_set_width(win_id, size)
    else
      vim.api.nvim_win_set_height(win_id, size)
    end
  end
  
  buffer_info.size = size
  M.cache_size(terminal_name, position, size)
end

function M.change_position(terminal_name, new_position)
  local was_active = M.is_active(terminal_name)
  
  if was_active then
    M.close(terminal_name)
  end
  
  local session = require('luxterm.session')
  local terminals = session.get_terminals()
  local buffer_info = terminals[terminal_name]
  
  if buffer_info then
    buffer_info.position = new_position
    
    if was_active then
      M.open(terminal_name, buffer_info)
    end
  end
end

function M.cache_size(terminal_name, position, size)
  if not config.get('remember_size') then
    return
  end
  
  if not size_cache[position] then
    size_cache[position] = {}
  end
  
  size_cache[position][terminal_name] = size
end

function M.get_cached_size(terminal_name, position)
  if not config.get('remember_size') then
    return nil
  end
  
  return size_cache[position] and size_cache[position][terminal_name]
end

function M.on_window_closed(terminal_name, win_id)
  local floating_window = floating.get_floating_window(terminal_name)
  if floating_window then
    floating.remove_floating_window(terminal_name)
  end
end

return M