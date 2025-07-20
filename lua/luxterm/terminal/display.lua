local common = require('luxterm.core.common')
local window_utils = require('luxterm.utils.window')
local buffer_detect = require('luxterm.utils.buffer_detect')

local M = {}

local floating_windows = {}

function M.show_terminal(name, terminal_info)
  local position = terminal_info.position
  
  return common.with_config({'floating_window'}, function(config_values)
    if config_values.floating_window then
      position = 'floating'
    end
    
    M.store_previous_window()
    
    if position == 'floating' then
      return M.show_floating(name, terminal_info)
    else
      return M.show_split(name, terminal_info, position)
    end
  end)
end

function M.show_floating(name, terminal_info)
  return common.with_config({
    'floating_width', 'floating_height', 'floating_border'
  }, function(config_values)
    local win_id = window_utils.create_window(terminal_info.bufnr, 'floating', name)
    
    if not win_id then
      common.notify_error('Failed to create floating window', 'Window')
      return nil
    end
    
    floating_windows[name] = {
      win_id = win_id,
      terminal_info = terminal_info
    }
    
    M.setup_terminal_window(win_id, name, terminal_info)
    return win_id
  end)
end

function M.show_split(name, terminal_info, position)
  local size = terminal_info.size
  
  return common.with_config({'size'}, function(config_values)
    size = size or config_values.size
    
    local win_id = window_utils.create_window(terminal_info.bufnr, position)
    
    if not win_id then
      common.notify_error('Failed to create split window', 'Window')
      return nil
    end
    
    M.setup_terminal_window(win_id, name, terminal_info)
    return win_id
  end)
end

function M.setup_terminal_window(win_id, name, terminal_info)
  window_utils.configure_terminal_window(win_id)
  
  vim.w[win_id].luxterm_terminal_name = name
  
  common.with_config({'focus_on_toggle'}, function(config_values)
    if config_values.focus_on_toggle then
      vim.cmd('startinsert')
    end
  end)
  
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win_id),
    callback = function()
      M.on_window_closed(name, win_id)
    end,
    once = true
  })
end

function M.hide_terminal(name)
  local win_id = M.get_terminal_window(name)
  if not win_id then
    return false
  end
  
  if floating_windows[name] then
    floating_windows[name] = nil
  end
  
  if vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_win_close(win_id, false)
  end
  
  M.restore_previous_window()
  return true
end

function M.is_terminal_visible(name)
  local win_id = M.get_terminal_window(name)
  return win_id and vim.api.nvim_win_is_valid(win_id)
end

function M.get_terminal_window(name)
  if floating_windows[name] then
    return floating_windows[name].win_id
  end
  
  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win_id) then
      local ok, terminal_name = pcall(vim.api.nvim_win_get_var, win_id, 'luxterm_terminal_name')
      if ok and terminal_name == name then
        return win_id
      end
    end
  end
  
  return nil
end

function M.focus_terminal(name)
  local win_id = M.get_terminal_window(name)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return false
  end
  
  vim.api.nvim_set_current_win(win_id)
  
  common.with_config({'focus_on_toggle'}, function(config_values)
    if config_values.focus_on_toggle then
      vim.cmd('startinsert')
    end
  end)
  
  return true
end

function M.resize_terminal(name, size)
  local win_id = M.get_terminal_window(name)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    return false
  end
  
  return common.with_terminal_info(name, function(terminal_info)
    local position = terminal_info.position
    
    if position == 'floating' then
      M.resize_floating_window(win_id, size)
    else
      M.resize_split_window(win_id, position, size)
    end
    
    terminal_info.size = size
    return true
  end)
end

function M.resize_floating_window(win_id, size)
  local width = math.floor(vim.o.columns * (size / 100))
  local height = math.floor(vim.o.lines * (size / 100))
  
  vim.api.nvim_win_set_config(win_id, {
    width = width,
    height = height
  })
end

function M.resize_split_window(win_id, position, size)
  if position == 'left' or position == 'right' then
    vim.api.nvim_win_set_width(win_id, size)
  else
    vim.api.nvim_win_set_height(win_id, size)
  end
end

function M.change_terminal_position(name, new_position)
  local was_visible = M.is_terminal_visible(name)
  
  if was_visible then
    M.hide_terminal(name)
  end
  
  return common.with_terminal_info(name, function(terminal_info)
    terminal_info.position = new_position
    
    if was_visible then
      M.show_terminal(name, terminal_info)
    end
    return true
  end)
end

function M.store_previous_window()
  local current_win = vim.api.nvim_get_current_win()
  
  if buffer_detect.is_suitable_previous_window(current_win) then
    vim.w.luxterm_previous_win = current_win
  else
    local suitable_win = buffer_detect.find_suitable_previous_window(current_win)
    vim.w.luxterm_previous_win = suitable_win
  end
end

function M.restore_previous_window()
  if vim.w.luxterm_previous_win and vim.api.nvim_win_is_valid(vim.w.luxterm_previous_win) then
    vim.api.nvim_set_current_win(vim.w.luxterm_previous_win)
  end
end

function M.on_window_closed(name, win_id)
  if floating_windows[name] then
    floating_windows[name] = nil
  end
end

return M