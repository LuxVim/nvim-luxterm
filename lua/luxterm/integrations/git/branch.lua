local utils = require('luxterm.integrations.git.utils')

local M = {}

function M.run(branch_name, args, terminal_name)
  args = args or {}
  
  local cmd = 'git branch'
  
  if branch_name and branch_name ~= '' then
    cmd = cmd .. ' ' .. branch_name
  end
  
  local options = {
    all = args.all,
    remotes = args.remotes,
    delete = args.delete,
    ['delete-force'] = args.delete_force,
    move = args.move,
    copy = args.copy,
    list = args.list,
    verbose = args.verbose,
    merged = args.merged,
    ['no-merged'] = args.no_merged,
    contains = args.contains,
    ['set-upstream-to'] = args.set_upstream_to,
    ['unset-upstream'] = args.unset_upstream
  }
  
  cmd = utils.build_command(cmd, options)
  utils.send_git_command(cmd, terminal_name)
end

function M.list(terminal_name)
  M.run('', { list = true }, terminal_name)
end

function M.list_all(terminal_name)
  M.run('', { all = true }, terminal_name)
end

function M.list_remotes(terminal_name)
  M.run('', { remotes = true }, terminal_name)
end

function M.create(branch_name, terminal_name)
  if not branch_name or branch_name == '' then
    utils.notify_error('Branch name is required')
    return
  end
  
  M.run(branch_name, {}, terminal_name)
end

function M.delete(branch_name, terminal_name)
  if not branch_name or branch_name == '' then
    utils.notify_error('Branch name is required')
    return
  end
  
  M.run(branch_name, { delete = true }, terminal_name)
end

function M.force_delete(branch_name, terminal_name)
  if not branch_name or branch_name == '' then
    utils.notify_error('Branch name is required')
    return
  end
  
  M.run(branch_name, { delete_force = true }, terminal_name)
end

function M.rename(old_name, new_name, terminal_name)
  if not old_name or old_name == '' then
    utils.notify_error('Old branch name is required')
    return
  end
  
  if not new_name or new_name == '' then
    utils.notify_error('New branch name is required')
    return
  end
  
  M.run(old_name .. ' ' .. new_name, { move = true }, terminal_name)
end

function M.merged(base_branch, terminal_name)
  base_branch = base_branch or 'HEAD'
  M.run('', { merged = base_branch }, terminal_name)
end

function M.no_merged(base_branch, terminal_name)
  base_branch = base_branch or 'HEAD'
  M.run('', { no_merged = base_branch }, terminal_name)
end

function M.contains(commit, terminal_name)
  if not commit or commit == '' then
    utils.notify_error('Commit is required')
    return
  end
  
  M.run('', { contains = commit }, terminal_name)
end

function M.set_upstream(branch_name, upstream, terminal_name)
  if not branch_name or branch_name == '' then
    utils.notify_error('Branch name is required')
    return
  end
  
  if not upstream or upstream == '' then
    utils.notify_error('Upstream branch is required')
    return
  end
  
  M.run(branch_name, { set_upstream_to = upstream }, terminal_name)
end

function M.unset_upstream(branch_name, terminal_name)
  if not branch_name or branch_name == '' then
    utils.notify_error('Branch name is required')
    return
  end
  
  M.run(branch_name, { unset_upstream = true }, terminal_name)
end

return M