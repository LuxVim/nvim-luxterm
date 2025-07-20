local command_sender = require('luxterm.core.command_sender')

local M = {}

local integrations = {}

function M.init()
  M.detect_build_system()
  M.detect_test_framework()
end

function M.detect_build_system()
  vim.schedule(function()
    local build_systems = require('luxterm.integrations.build_systems')
    integrations.build = build_systems.detect()
  end)
end

function M.detect_test_framework()
  vim.schedule(function()
    local test_frameworks = require('luxterm.integrations.test_frameworks')
    integrations.test = test_frameworks.detect()
  end)
end

function M.run_command(category, command, terminal_name)
  terminal_name = terminal_name or 'default'
  
  local config = integrations[category]
  if not config then
    vim.notify('LuxTerm: No ' .. category .. ' configuration found', vim.log.levels.WARN)
    return false
  end
  
  local cmd = config[command .. '_cmd']
  if not cmd then
    vim.notify('LuxTerm: No ' .. command .. ' command found for ' .. config.type, vim.log.levels.WARN)
    return false
  end
  
  return command_sender.send(terminal_name, cmd, { show_terminal = true })
end

function M.build(terminal_name)
  return M.run_command('build', 'build', terminal_name or 'build')
end

function M.dev(terminal_name)
  return M.run_command('build', 'dev', terminal_name or 'build')
end

function M.start(terminal_name)
  return M.run_command('build', 'start', terminal_name or 'build')
end

function M.install(terminal_name)
  return M.run_command('build', 'install', terminal_name or 'build')
end

function M.test(terminal_name)
  return M.run_command('test', 'test', terminal_name or 'test')
end

function M.test_verbose(terminal_name)
  return M.run_command('test', 'test_verbose', terminal_name or 'test')
end

function M.test_watch(terminal_name)
  return M.run_command('test', 'test_watch', terminal_name or 'test')
end

function M.coverage(terminal_name)
  return M.run_command('test', 'coverage', terminal_name or 'test')
end

function M.git_status(terminal_name)
  local git = require('luxterm.integrations.git')
  return git.status(terminal_name)
end

function M.git_add(terminal_name)
  local git = require('luxterm.integrations.git')
  return git.add(nil, terminal_name)
end

function M.git_commit(message, terminal_name)
  local git = require('luxterm.integrations.git')
  return git.commit(message, terminal_name)
end

function M.git_push(terminal_name)
  local git = require('luxterm.integrations.git')
  return git.push(terminal_name)
end

function M.git_pull(terminal_name)
  local git = require('luxterm.integrations.git')
  return git.pull(terminal_name)
end

function M.git_log(terminal_name)
  local git = require('luxterm.integrations.git')
  return git.log(terminal_name)
end

function M.git_diff(terminal_name)
  local git = require('luxterm.integrations.git')
  return git.diff(nil, terminal_name)
end

return M