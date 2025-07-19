local utils = require('luxterm.integrations.git.utils')

local M = {}

function M.run(files, args, terminal_name)
  files = files or '.'
  args = args or {}
  
  local options = {
    all = args.all,
    update = args.update,
    force = args.force,
    verbose = args.verbose,
    ['dry-run'] = args.dry_run,
    patch = args.patch
  }
  
  local cmd = utils.build_command('git add ' .. files, options)
  utils.send_git_command(cmd, terminal_name)
end

function M.all(terminal_name)
  M.run('.', { all = true }, terminal_name)
end

function M.update(terminal_name)
  M.run('.', { update = true }, terminal_name)
end

function M.patch(files, terminal_name)
  files = files or '.'
  M.run(files, { patch = true }, terminal_name)
end

function M.force(files, terminal_name)
  files = files or '.'
  M.run(files, { force = true }, terminal_name)
end

function M.dry_run(files, terminal_name)
  files = files or '.'
  M.run(files, { dry_run = true }, terminal_name)
end

function M.specific_files(file_list, terminal_name)
  if not file_list or file_list == '' then
    utils.notify_error('No files specified for git add')
    return
  end
  
  M.run(file_list, {}, terminal_name)
end

return M