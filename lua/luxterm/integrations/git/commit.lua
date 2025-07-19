local utils = require('luxterm.integrations.git.utils')

local M = {}

function M.run(message, args, terminal_name)
  args = args or {}
  
  local cmd = 'git commit'
  
  if message and message ~= '' then
    cmd = cmd .. ' -m "' .. message .. '"'
  end
  
  local options = {
    all = args.all,
    amend = args.amend,
    ['no-edit'] = args.no_edit,
    ['sign-off'] = args.sign_off,
    verbose = args.verbose,
    ['dry-run'] = args.dry_run,
    ['allow-empty'] = args.allow_empty,
    ['no-verify'] = args.no_verify
  }
  
  cmd = utils.build_command(cmd, options)
  utils.send_git_command(cmd, terminal_name)
end

function M.with_message(message, terminal_name)
  if not message or message == '' then
    utils.notify_error('Commit message is required')
    return
  end
  
  M.run(message, {}, terminal_name)
end

function M.amend(message, terminal_name)
  local args = { amend = true }
  if not message or message == '' then
    args.no_edit = true
  end
  
  M.run(message, args, terminal_name)
end

function M.all_with_message(message, terminal_name)
  if not message or message == '' then
    utils.notify_error('Commit message is required')
    return
  end
  
  M.run(message, { all = true }, terminal_name)
end

function M.signed_off(message, terminal_name)
  if not message or message == '' then
    utils.notify_error('Commit message is required')
    return
  end
  
  M.run(message, { sign_off = true }, terminal_name)
end

function M.dry_run(message, terminal_name)
  M.run(message, { dry_run = true }, terminal_name)
end

function M.allow_empty(message, terminal_name)
  M.run(message, { allow_empty = true }, terminal_name)
end

function M.no_verify(message, terminal_name)
  if not message or message == '' then
    utils.notify_error('Commit message is required')
    return
  end
  
  M.run(message, { no_verify = true }, terminal_name)
end

function M.interactive(terminal_name)
  utils.send_git_command('git commit', terminal_name)
end

return M