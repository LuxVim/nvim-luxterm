local M = {}

local config = require('luxterm.config')

local floating_windows = {}
local size_cache = {}

function M.open(terminal_name, buffer_info)
  local position = buffer_info.position or config.get('position')
  
  -- Override position if floating_window is enabled
  if config.get('floating_window') then
    position = 'floating'
  end
  
  if position == 'floating' then
    return M.open_floating(terminal_name, buffer_info)
  else
    return M.open_split(terminal_name, buffer_info)
  end
end

function M.open_split(terminal_name, buffer_info)
  local position = buffer_info.position or config.get('position')
  local size = buffer_info.size or config.get('size')
  
  M.store_previous_window()
  
  local position_map = config.get_position_map()
  local pos_info = position_map[position] or position_map['bottom']
  
  local cmd
  if pos_info.direction == 'horizontal' then
    cmd = string.format('%s %dsplit', pos_info.split, size)
  else
    cmd = string.format('%s %dvsplit', pos_info.split, size)
  end
  
  
  vim.cmd(cmd)
  local win_id = vim.api.nvim_get_current_win()
  
  vim.api.nvim_win_set_buf(win_id, buffer_info.bufnr)
  
  M.setup_window(win_id, terminal_name, buffer_info)
  
  return win_id
end

function M.open_floating(terminal_name, buffer_info)
  local width = math.floor(vim.o.columns * config.get('floating_width'))
  local height = math.floor(vim.o.lines * config.get('floating_height'))
  
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  local border = config.get('floating_border')
  
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = border,
    title = ' Terminal: ' .. terminal_name .. ' ',
    title_pos = 'center'
  }
  
  M.store_previous_window()
  
  local win_id = vim.api.nvim_open_win(buffer_info.bufnr, true, opts)
  
  floating_windows[terminal_name] = {
    win_id = win_id,
    buffer_info = buffer_info
  }
  
  M.setup_window(win_id, terminal_name, buffer_info)
  
  return win_id
end

function M.setup_window(win_id, terminal_name, buffer_info)
  vim.wo[win_id].number = false
  vim.wo[win_id].relativenumber = false
  vim.wo[win_id].signcolumn = 'no'
  vim.wo[win_id].wrap = false
  
  vim.w[win_id].luxterm_terminal_name = terminal_name
  
  if config.get('focus_on_toggle') then
    vim.cmd('startinsert')
  end
  
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win_id),
    callback = function()
      M.on_window_closed(terminal_name, win_id)
    end,
    once = true
  })
end

function M.close(terminal_name)
  local win_id = M.get_window_id(terminal_name)
  if win_id then
    if floating_windows[terminal_name] then
      floating_windows[terminal_name] = nil
    end
    
    if vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_win_close(win_id, false)
    end
  end
  
  M.restore_previous_window()
end

function M.is_active(terminal_name)
  local win_id = M.get_window_id(terminal_name)
  return win_id and vim.api.nvim_win_is_valid(win_id)
end

function M.get_window_id(terminal_name)
  if floating_windows[terminal_name] then
    return floating_windows[terminal_name].win_id
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

function M.store_previous_window()
  local current_win = vim.api.nvim_get_current_win()
  vim.w.luxterm_previous_win = current_win
end

function M.restore_previous_window()
  if vim.w.luxterm_previous_win then
    if vim.fn.win_gotoid(vim.w.luxterm_previous_win) == 0 then
      vim.cmd('wincmd p')
    end
  else
    vim.cmd('wincmd p')
  end
end

function M.on_window_closed(terminal_name, win_id)
  if floating_windows[terminal_name] then
    floating_windows[terminal_name] = nil
  end
end

return M