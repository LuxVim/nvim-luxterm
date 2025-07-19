local utils = require('luxterm.integrations.git.utils')

local M = {}

function M.run(subcommand, args, terminal_name)
  args = args or {}
  
  local cmd = 'git stash'
  
  if subcommand and subcommand ~= '' then
    cmd = cmd .. ' ' .. subcommand
  end
  
  local options = {
    message = args.message,
    patch = args.patch,
    ['keep-index'] = args.keep_index,
    ['no-keep-index'] = args.no_keep_index,
    ['include-untracked'] = args.include_untracked,
    all = args.all,
    quiet = args.quiet,
    index = args.index
  }
  
  if args.message and args.message ~= '' then
    cmd = cmd .. ' -m "' .. args.message .. '"'
    options.message = nil
  end
  
  cmd = utils.build_command(cmd, options)
  utils.send_git_command(cmd, terminal_name)
end

function M.push(message, terminal_name)
  if message and message ~= '' then
    M.run('push', { message = message }, terminal_name)
  else
    M.run('push', {}, terminal_name)
  end
end

function M.pop(stash_ref, terminal_name)
  local subcommand = 'pop'
  if stash_ref and stash_ref ~= '' then
    subcommand = subcommand .. ' ' .. stash_ref
  end
  
  M.run(subcommand, {}, terminal_name)
end

function M.apply(stash_ref, terminal_name)
  local subcommand = 'apply'
  if stash_ref and stash_ref ~= '' then
    subcommand = subcommand .. ' ' .. stash_ref
  end
  
  M.run(subcommand, {}, terminal_name)
end

function M.list(terminal_name)
  M.run('list', {}, terminal_name)
end

function M.show(stash_ref, terminal_name)
  local subcommand = 'show'
  if stash_ref and stash_ref ~= '' then
    subcommand = subcommand .. ' ' .. stash_ref
  end
  
  M.run(subcommand, {}, terminal_name)
end

function M.drop(stash_ref, terminal_name)
  local subcommand = 'drop'
  if stash_ref and stash_ref ~= '' then
    subcommand = subcommand .. ' ' .. stash_ref
  end
  
  M.run(subcommand, {}, terminal_name)
end

function M.clear(terminal_name)
  M.run('clear', {}, terminal_name)
end

function M.branch(branch_name, stash_ref, terminal_name)
  if not branch_name or branch_name == '' then
    utils.notify_error('Branch name is required')
    return
  end
  
  local subcommand = 'branch ' .. branch_name
  if stash_ref and stash_ref ~= '' then
    subcommand = subcommand .. ' ' .. stash_ref
  end
  
  M.run(subcommand, {}, terminal_name)
end

function M.include_untracked(message, terminal_name)
  M.run('push', { message = message, include_untracked = true }, terminal_name)
end

function M.keep_index(message, terminal_name)
  M.run('push', { message = message, keep_index = true }, terminal_name)
end

function M.patch(message, terminal_name)
  M.run('push', { message = message, patch = true }, terminal_name)
end

function M.all_files(message, terminal_name)
  M.run('push', { message = message, all = true }, terminal_name)
end

function M.pop_with_index(stash_ref, terminal_name)
  local subcommand = 'pop'
  if stash_ref and stash_ref ~= '' then
    subcommand = subcommand .. ' ' .. stash_ref
  end
  
  M.run(subcommand, { index = true }, terminal_name)
end

return M