local M = {}

local status = require('luxterm.integrations.git.status')
local add = require('luxterm.integrations.git.add')
local commit = require('luxterm.integrations.git.commit')
local push = require('luxterm.integrations.git.push')
local pull = require('luxterm.integrations.git.pull')
local log = require('luxterm.integrations.git.log')
local diff = require('luxterm.integrations.git.diff')
local branch = require('luxterm.integrations.git.branch')
local checkout = require('luxterm.integrations.git.checkout')
local stash = require('luxterm.integrations.git.stash')

function M.status(terminal_name)
  status.run({}, terminal_name)
end

function M.add(files, terminal_name)
  if files then
    add.specific_files(files, terminal_name)
  else
    add.all(terminal_name)
  end
end

function M.commit(message, terminal_name)
  if message and message ~= '' then
    commit.with_message(message, terminal_name)
  else
    commit.interactive(terminal_name)
  end
end

function M.push(terminal_name, remote, branch_name)
  if remote or branch_name then
    push.run(remote, branch_name, {}, terminal_name)
  else
    push.current_branch(terminal_name)
  end
end

function M.pull(terminal_name, remote, branch_name)
  if remote or branch_name then
    pull.run(remote, branch_name, {}, terminal_name)
  else
    pull.current_branch(terminal_name)
  end
end

function M.log(terminal_name, count)
  log.oneline(count, terminal_name)
end

function M.diff(files, terminal_name)
  diff.working_tree(files, terminal_name)
end

function M.branch(branch_name, terminal_name)
  if branch_name and branch_name ~= '' then
    branch.create(branch_name, terminal_name)
  else
    branch.list(terminal_name)
  end
end

function M.checkout(branch_name, terminal_name)
  if not branch_name or branch_name == '' then
    require('luxterm.integrations.git.utils').notify_error('Branch name required for checkout')
    return
  end
  checkout.branch(branch_name, terminal_name)
end

function M.stash(message, terminal_name)
  stash.push(message, terminal_name)
end

function M.stash_pop(terminal_name)
  stash.pop(nil, terminal_name)
end

return M