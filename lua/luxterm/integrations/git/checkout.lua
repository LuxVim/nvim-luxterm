local utils = require('luxterm.integrations.git.utils')

local M = {}

function M.run(target, args, terminal_name)
  args = args or {}
  
  if not target or target == '' then
    utils.notify_error('Branch, commit, or file is required for checkout')
    return
  end
  
  local cmd = 'git checkout ' .. target
  
  local options = {
    branch = args.branch,
    ['new-branch'] = args.new_branch,
    force = args.force,
    merge = args.merge,
    conflict = args.conflict,
    patch = args.patch,
    track = args.track,
    ['no-track'] = args.no_track,
    orphan = args.orphan,
    quiet = args.quiet
  }
  
  cmd = utils.build_command(cmd, options)
  utils.send_git_command(cmd, terminal_name)
end

function M.branch(branch_name, terminal_name)
  if not branch_name or branch_name == '' then
    utils.notify_error('Branch name is required')
    return
  end
  
  M.run(branch_name, {}, terminal_name)
end

function M.new_branch(branch_name, start_point, terminal_name)
  if not branch_name or branch_name == '' then
    utils.notify_error('Branch name is required')
    return
  end
  
  local target = branch_name
  if start_point and start_point ~= '' then
    target = target .. ' ' .. start_point
  end
  
  M.run(target, { new_branch = true }, terminal_name)
end

function M.commit(commit_hash, terminal_name)
  if not commit_hash or commit_hash == '' then
    utils.notify_error('Commit hash is required')
    return
  end
  
  M.run(commit_hash, {}, terminal_name)
end

function M.file(file_path, terminal_name)
  if not file_path or file_path == '' then
    utils.notify_error('File path is required')
    return
  end
  
  M.run('-- ' .. file_path, {}, terminal_name)
end

function M.force(target, terminal_name)
  M.run(target, { force = true }, terminal_name)
end

function M.merge(target, terminal_name)
  M.run(target, { merge = true }, terminal_name)
end

function M.patch(target, terminal_name)
  M.run(target, { patch = true }, terminal_name)
end

function M.track(branch_name, remote_branch, terminal_name)
  if not branch_name or branch_name == '' then
    utils.notify_error('Branch name is required')
    return
  end
  
  if not remote_branch or remote_branch == '' then
    utils.notify_error('Remote branch is required')
    return
  end
  
  M.run(branch_name .. ' ' .. remote_branch, { track = true }, terminal_name)
end

function M.orphan(branch_name, terminal_name)
  if not branch_name or branch_name == '' then
    utils.notify_error('Branch name is required')
    return
  end
  
  M.run(branch_name, { orphan = true }, terminal_name)
end

function M.previous(terminal_name)
  M.run('-', {}, terminal_name)
end

function M.restore_files(file_paths, terminal_name)
  if not file_paths or file_paths == '' then
    utils.notify_error('File paths are required')
    return
  end
  
  M.run('-- ' .. file_paths, {}, terminal_name)
end

return M