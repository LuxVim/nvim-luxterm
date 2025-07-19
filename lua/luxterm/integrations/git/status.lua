local utils = require('luxterm.integrations.git.utils')

local M = {}

function M.run(args, terminal_name)
  args = args or {}
  
  local options = {
    short = args.short,
    porcelain = args.porcelain,
    verbose = args.verbose,
    branch = args.branch
  }
  
  local cmd = utils.build_command('git status', options)
  utils.send_git_command(cmd, terminal_name)
end

function M.short(terminal_name)
  M.run({ short = true }, terminal_name)
end

function M.porcelain(terminal_name)
  M.run({ porcelain = true }, terminal_name)
end

function M.verbose(terminal_name)
  M.run({ verbose = true }, terminal_name)
end

function M.with_branch(terminal_name)
  M.run({ branch = true }, terminal_name)
end

return M