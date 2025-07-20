local M = {}

local config = require('luxterm.config')

local integrations = {
  git = {},
  build = {},
  test = {}
}

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
  
  if integrations[category] and integrations[category][command] then
    local cmd = integrations[category][command]
    require('luxterm').send_command(terminal_name, cmd)
  end
end

function M.git_status(terminal_name)
  terminal_name = terminal_name or 'git'
  require('luxterm').send_command(terminal_name, 'git status')
end

function M.git_add(terminal_name)
  terminal_name = terminal_name or 'git'
  require('luxterm').send_command(terminal_name, 'git add .')
end

function M.git_commit(message, terminal_name)
  terminal_name = terminal_name or 'git'
  if message and message ~= '' then
    require('luxterm').send_command(terminal_name, 'git commit -m "' .. message .. '"')
  else
    require('luxterm').send_command(terminal_name, 'git commit')
  end
end

function M.git_push(terminal_name)
  terminal_name = terminal_name or 'git'
  require('luxterm').send_command(terminal_name, 'git push')
end

function M.git_pull(terminal_name)
  terminal_name = terminal_name or 'git'
  require('luxterm').send_command(terminal_name, 'git pull')
end

function M.git_log(terminal_name)
  terminal_name = terminal_name or 'git'
  require('luxterm').send_command(terminal_name, 'git log --oneline -10')
end

function M.git_diff(terminal_name)
  terminal_name = terminal_name or 'git'
  require('luxterm').send_command(terminal_name, 'git diff')
end

function M.build(terminal_name)
  terminal_name = terminal_name or 'build'
  M.run_command('build', 'build_cmd', terminal_name)
end

function M.run(terminal_name)
  terminal_name = terminal_name or 'run'
  M.run_command('build', 'start_cmd', terminal_name)
end

function M.dev(terminal_name)
  terminal_name = terminal_name or 'dev'
  M.run_command('build', 'dev_cmd', terminal_name)
end

function M.test(terminal_name)
  terminal_name = terminal_name or 'test'
  M.run_command('test', 'test_cmd', terminal_name)
end

function M.test_verbose(terminal_name)
  terminal_name = terminal_name or 'test'
  M.run_command('test', 'test_verbose_cmd', terminal_name)
end

function M.coverage(terminal_name)
  terminal_name = terminal_name or 'test'
  M.run_command('test', 'coverage_cmd', terminal_name)
end

function M.send_current_line(terminal_name)
  terminal_name = terminal_name or 'default'
  local line = vim.api.nvim_get_current_line()
  require('luxterm').send_command(terminal_name, line)
end

function M.send_selection(terminal_name)
  terminal_name = terminal_name or 'default'
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  
  local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  
  if #lines == 1 then
    local line = lines[1]
    local selection = line:sub(start_pos[3], end_pos[3])
    require('luxterm').send_command(terminal_name, selection)
  else
    local text = table.concat(lines, '\n')
    require('luxterm').send_command(terminal_name, text)
  end
end

function M.send_to_terminal(text, terminal_name)
  terminal_name = terminal_name or 'default'
  require('luxterm').send_command(terminal_name, text)
end

function M.get_integrations()
  return integrations
end

return M