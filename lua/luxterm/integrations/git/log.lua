local utils = require('luxterm.integrations.git.utils')

local M = {}

function M.run(args, terminal_name)
  args = args or {}
  
  local cmd = 'git log'
  
  local options = {
    oneline = args.oneline,
    graph = args.graph,
    decorate = args.decorate,
    all = args.all,
    stat = args.stat,
    ['name-only'] = args.name_only,
    ['name-status'] = args.name_status,
    abbrev = args.abbrev,
    pretty = args.pretty,
    format = args.format,
    since = args.since,
    until = args.until,
    author = args.author,
    grep = args.grep,
    ['follow'] = args.follow
  }
  
  if args.count and args.count > 0 then
    cmd = cmd .. ' -' .. args.count
  end
  
  if args.file and args.file ~= '' then
    cmd = cmd .. ' -- ' .. args.file
  end
  
  cmd = utils.build_command(cmd, options)
  utils.send_git_command(cmd, terminal_name)
end

function M.oneline(count, terminal_name)
  count = count or 10
  M.run({ oneline = true, count = count }, terminal_name)
end

function M.graph(count, terminal_name)
  count = count or 10
  M.run({ graph = true, oneline = true, count = count }, terminal_name)
end

function M.stat(count, terminal_name)
  count = count or 10
  M.run({ stat = true, count = count }, terminal_name)
end

function M.all_branches(count, terminal_name)
  count = count or 10
  M.run({ all = true, graph = true, oneline = true, count = count }, terminal_name)
end

function M.by_author(author, count, terminal_name)
  if not author or author == '' then
    utils.notify_error('Author name is required')
    return
  end
  
  count = count or 10
  M.run({ author = author, count = count }, terminal_name)
end

function M.search(pattern, count, terminal_name)
  if not pattern or pattern == '' then
    utils.notify_error('Search pattern is required')
    return
  end
  
  count = count or 10
  M.run({ grep = pattern, count = count }, terminal_name)
end

function M.since_date(date, count, terminal_name)
  if not date or date == '' then
    utils.notify_error('Date is required')
    return
  end
  
  count = count or 10
  M.run({ since = date, count = count }, terminal_name)
end

function M.file_history(file, count, terminal_name)
  if not file or file == '' then
    utils.notify_error('File path is required')
    return
  end
  
  count = count or 10
  M.run({ follow = true, count = count, file = file }, terminal_name)
end

function M.pretty_format(format, count, terminal_name)
  count = count or 10
  M.run({ pretty = format, count = count }, terminal_name)
end

return M