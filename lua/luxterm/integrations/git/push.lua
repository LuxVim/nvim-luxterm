local utils = require('luxterm.integrations.git.utils')

local M = {}

function M.run(remote, branch, args, terminal_name)
  args = args or {}
  
  local cmd = 'git push'
  
  if remote and remote ~= '' then
    cmd = cmd .. ' ' .. remote
    if branch and branch ~= '' then
      cmd = cmd .. ' ' .. branch
    end
  end
  
  local options = {
    force = args.force,
    ['force-with-lease'] = args.force_with_lease,
    ['set-upstream'] = args.set_upstream,
    tags = args.tags,
    ['dry-run'] = args.dry_run,
    verbose = args.verbose,
    quiet = args.quiet,
    ['follow-tags'] = args.follow_tags
  }
  
  cmd = utils.build_command(cmd, options)
  utils.send_git_command(cmd, terminal_name)
end

function M.origin(branch, terminal_name)
  M.run('origin', branch, {}, terminal_name)
end

function M.upstream(branch, terminal_name)
  branch = branch or ''
  M.run('origin', branch, { set_upstream = true }, terminal_name)
end

function M.force(remote, branch, terminal_name)
  M.run(remote, branch, { force = true }, terminal_name)
end

function M.force_with_lease(remote, branch, terminal_name)
  M.run(remote, branch, { force_with_lease = true }, terminal_name)
end

function M.tags(remote, terminal_name)
  remote = remote or 'origin'
  M.run(remote, '', { tags = true }, terminal_name)
end

function M.dry_run(remote, branch, terminal_name)
  M.run(remote, branch, { dry_run = true }, terminal_name)
end

function M.follow_tags(remote, branch, terminal_name)
  M.run(remote, branch, { follow_tags = true }, terminal_name)
end

function M.current_branch(terminal_name)
  M.run('', '', {}, terminal_name)
end

function M.all_branches(remote, terminal_name)
  remote = remote or 'origin'
  utils.send_git_command('git push ' .. remote .. ' --all', terminal_name)
end

return M