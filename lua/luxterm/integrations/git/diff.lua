local utils = require('luxterm.integrations.git.utils')

local M = {}

function M.run(files, args, terminal_name)
  args = args or {}
  
  local cmd = 'git diff'
  
  if files and files ~= '' then
    cmd = cmd .. ' ' .. files
  end
  
  local options = {
    cached = args.cached,
    staged = args.staged,
    ['name-only'] = args.name_only,
    ['name-status'] = args.name_status,
    stat = args.stat,
    ['numstat'] = args.numstat,
    ['shortstat'] = args.shortstat,
    ['word-diff'] = args.word_diff,
    ['color-words'] = args.color_words,
    ['no-color'] = args.no_color,
    ['unified'] = args.unified,
    ['ignore-whitespace'] = args.ignore_whitespace,
    ['ignore-space-change'] = args.ignore_space_change
  }
  
  cmd = utils.build_command(cmd, options)
  utils.send_git_command(cmd, terminal_name)
end

function M.working_tree(files, terminal_name)
  M.run(files, {}, terminal_name)
end

function M.staged(files, terminal_name)
  M.run(files, { staged = true }, terminal_name)
end

function M.cached(files, terminal_name)
  M.run(files, { cached = true }, terminal_name)
end

function M.name_only(files, terminal_name)
  M.run(files, { name_only = true }, terminal_name)
end

function M.name_status(files, terminal_name)
  M.run(files, { name_status = true }, terminal_name)
end

function M.stat(files, terminal_name)
  M.run(files, { stat = true }, terminal_name)
end

function M.word_diff(files, terminal_name)
  M.run(files, { word_diff = true }, terminal_name)
end

function M.color_words(files, terminal_name)
  M.run(files, { color_words = true }, terminal_name)
end

function M.between_commits(commit1, commit2, files, terminal_name)
  if not commit1 or commit1 == '' then
    utils.notify_error('First commit is required')
    return
  end
  
  if not commit2 or commit2 == '' then
    utils.notify_error('Second commit is required')
    return
  end
  
  local range = commit1 .. '..' .. commit2
  if files and files ~= '' then
    range = range .. ' ' .. files
  end
  
  M.run(range, {}, terminal_name)
end

function M.with_commit(commit, files, terminal_name)
  if not commit or commit == '' then
    utils.notify_error('Commit is required')
    return
  end
  
  local target = commit
  if files and files ~= '' then
    target = target .. ' ' .. files
  end
  
  M.run(target, {}, terminal_name)
end

function M.ignore_whitespace(files, terminal_name)
  M.run(files, { ignore_whitespace = true }, terminal_name)
end

return M