local utils = require('luxterm.integrations.git.utils')

local M = {}

function M.run(remote, branch, args, terminal_name)
  args = args or {}
  
  local cmd = 'git pull'
  
  if remote and remote ~= '' then
    cmd = cmd .. ' ' .. remote
    if branch and branch ~= '' then
      cmd = cmd .. ' ' .. branch
    end
  end
  
  local options = {
    rebase = args.rebase,
    ['no-rebase'] = args.no_rebase,
    ['ff-only'] = args.ff_only,
    ['no-ff'] = args.no_ff,
    squash = args.squash,
    strategy = args.strategy,
    ['strategy-option'] = args.strategy_option,
    verbose = args.verbose,
    quiet = args.quiet,
    ['dry-run'] = args.dry_run,
    force = args.force
  }
  
  cmd = utils.build_command(cmd, options)
  utils.send_git_command(cmd, terminal_name)
end

function M.origin(branch, terminal_name)
  M.run('origin', branch, {}, terminal_name)
end

function M.rebase(remote, branch, terminal_name)
  M.run(remote, branch, { rebase = true }, terminal_name)
end

function M.no_rebase(remote, branch, terminal_name)
  M.run(remote, branch, { no_rebase = true }, terminal_name)
end

function M.ff_only(remote, branch, terminal_name)
  M.run(remote, branch, { ff_only = true }, terminal_name)
end

function M.no_ff(remote, branch, terminal_name)
  M.run(remote, branch, { no_ff = true }, terminal_name)
end

function M.squash(remote, branch, terminal_name)
  M.run(remote, branch, { squash = true }, terminal_name)
end

function M.dry_run(remote, branch, terminal_name)
  M.run(remote, branch, { dry_run = true }, terminal_name)
end

function M.force(remote, branch, terminal_name)
  M.run(remote, branch, { force = true }, terminal_name)
end

function M.current_branch(terminal_name)
  M.run('', '', {}, terminal_name)
end

function M.upstream(terminal_name)
  utils.send_git_command('git pull --set-upstream', terminal_name)
end

return M