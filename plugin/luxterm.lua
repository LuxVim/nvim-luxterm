if vim.g.luxterm_loaded then
  return
end

vim.g.luxterm_loaded = true

local function luxterm_toggle(args)
  local terminal_name = args.args and args.args ~= '' and args.args or nil
  pcall(require('luxterm').toggle, terminal_name)
end

local function luxterm_list()
  local terminals = require('luxterm').list()
  if #terminals == 0 then
    print('No terminals found')
  else
    print('Active terminals:')
    for _, terminal in ipairs(terminals) do
      print('  ' .. terminal)
    end
  end
end

local function luxterm_kill(args)
  local terminal_name = args.args
  if terminal_name and terminal_name ~= '' then
    require('luxterm').kill(terminal_name)
    print('Killed terminal: ' .. terminal_name)
  else
    print('Error: Terminal name required')
  end
end

local function luxterm_rename(args)
  local names = vim.split(args.args, '%s+')
  if #names >= 2 then
    local old_name, new_name = names[1], names[2]
    require('luxterm').rename(old_name, new_name)
    print('Renamed terminal: ' .. old_name .. ' -> ' .. new_name)
  else
    print('Error: Both old and new names required')
  end
end

local function luxterm_next()
  require('luxterm').next_terminal()
end

local function luxterm_prev()
  require('luxterm').prev_terminal()
end

local function luxterm_send(args)
  local parts = vim.split(args.args, '%s+', { plain = false })
  if #parts >= 2 then
    local terminal_name = parts[1]
    local command = table.concat(parts, ' ', 2)
    require('luxterm').send_command(terminal_name, command)
  else
    print('Error: Terminal name and command required')
  end
end

local function luxterm_position(args)
  local position = args.args
  local valid_positions = { 'bottom', 'top', 'left', 'right', 'floating' }
  
  if not vim.tbl_contains(valid_positions, position) then
    print('Invalid position. Valid options: ' .. table.concat(valid_positions, ', '))
    return
  end
  
  require('luxterm.config').set('position', position)
  print('Terminal position set to: ' .. position)
end

local function luxterm_resize(args)
  local parts = vim.split(args.args, '%s+')
  if #parts >= 2 then
    local terminal_name = parts[1]
    local size = tonumber(parts[2])
    if size then
      require('luxterm.window').resize(terminal_name, size)
      print('Resized terminal ' .. terminal_name .. ' to size: ' .. size)
    else
      print('Error: Size must be a number')
    end
  else
    print('Error: Terminal name and size required')
  end
end

local function luxterm_session(args)
  local session_name = args.args
  local session = require('luxterm.session')
  
  if not session_name or session_name == '' then
    print('Current session: ' .. session.get_current())
    local sessions = session.list()
    if #sessions > 1 then
      print('Available sessions: ' .. table.concat(sessions, ', '))
    end
  else
    session.set_current(session_name)
    print('Switched to session: ' .. session_name)
  end
end

local function luxterm_clean()
  require('luxterm.session').clean()
  print('Cleaned up inactive terminals')
end

local function luxterm_config()
  local config = require('luxterm.config').get_all()
  print('LuxTerm Configuration:')
  for key, value in pairs(config) do
    print('  ' .. key .. ': ' .. vim.inspect(value))
  end
end

vim.api.nvim_create_user_command('LuxTerm', luxterm_toggle, { nargs = '?' })
vim.api.nvim_create_user_command('LuxTermList', luxterm_list, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermKill', luxterm_kill, { nargs = 1 })
vim.api.nvim_create_user_command('LuxTermRename', luxterm_rename, { nargs = '+' })
vim.api.nvim_create_user_command('LuxTermNext', luxterm_next, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermPrev', luxterm_prev, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermSend', luxterm_send, { nargs = '+' })
vim.api.nvim_create_user_command('LuxTermPosition', luxterm_position, { nargs = 1 })
vim.api.nvim_create_user_command('LuxTermResize', luxterm_resize, { nargs = '+' })
vim.api.nvim_create_user_command('LuxTermSession', luxterm_session, { nargs = '?' })
vim.api.nvim_create_user_command('LuxTermClean', luxterm_clean, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermConfig', luxterm_config, { nargs = 0 })

local integration = require('luxterm.integration')

vim.api.nvim_create_user_command('LuxTermGitStatus', function() integration.git_status() end, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermGitAdd', function() integration.git_add() end, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermGitCommit', function(args) integration.git_commit(args.args) end, { nargs = '?' })
vim.api.nvim_create_user_command('LuxTermGitPush', function() integration.git_push() end, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermGitPull', function() integration.git_pull() end, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermGitLog', function() integration.git_log() end, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermGitDiff', function() integration.git_diff() end, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermBuild', function() integration.build() end, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermRun', function() integration.run() end, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermTest', function() integration.test() end, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermTestVerbose', function() integration.test_verbose() end, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermCoverage', function() integration.coverage() end, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermSendLine', function() integration.send_current_line() end, { nargs = 0 })
vim.api.nvim_create_user_command('LuxTermSendSelection', function() integration.send_selection() end, { range = true })

local augroup = vim.api.nvim_create_augroup('luxterm_terminal_settings', { clear = true })

vim.api.nvim_create_autocmd('VimEnter', {
  group = augroup,
  callback = function()
    require('luxterm').init()
    if require('luxterm.config').get('autostart') then
      require('luxterm').toggle()
    end
  end
})

vim.api.nvim_create_autocmd('TermOpen', {
  group = augroup,
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'
  end
})