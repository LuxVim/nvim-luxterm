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
  local cwd = vim.fn.getcwd()
  
  if vim.fn.filereadable(cwd .. '/package.json') == 1 then
    integrations.build = {
      type = 'npm',
      build_cmd = 'npm run build',
      dev_cmd = 'npm run dev',
      start_cmd = 'npm start',
      install_cmd = 'npm install'
    }
  elseif vim.fn.filereadable(cwd .. '/Cargo.toml') == 1 then
    integrations.build = {
      type = 'cargo',
      build_cmd = 'cargo build',
      dev_cmd = 'cargo run',
      start_cmd = 'cargo run --release',
      install_cmd = 'cargo install'
    }
  elseif vim.fn.filereadable(cwd .. '/go.mod') == 1 then
    integrations.build = {
      type = 'go',
      build_cmd = 'go build',
      dev_cmd = 'go run .',
      start_cmd = 'go run .',
      install_cmd = 'go mod tidy'
    }
  elseif vim.fn.filereadable(cwd .. '/Makefile') == 1 or vim.fn.filereadable(cwd .. '/makefile') == 1 then
    integrations.build = {
      type = 'make',
      build_cmd = 'make',
      dev_cmd = 'make dev',
      start_cmd = 'make run',
      install_cmd = 'make install'
    }
  elseif vim.fn.filereadable(cwd .. '/setup.py') == 1 or vim.fn.filereadable(cwd .. '/pyproject.toml') == 1 then
    integrations.build = {
      type = 'python',
      build_cmd = 'python setup.py build',
      dev_cmd = 'python -m pip install -e .',
      start_cmd = 'python -m ' .. vim.fn.fnamemodify(cwd, ':t'),
      install_cmd = 'pip install -e .'
    }
  else
    integrations.build = {
      type = 'generic',
      build_cmd = 'make',
      dev_cmd = './run.sh',
      start_cmd = './start.sh',
      install_cmd = './install.sh'
    }
  end
end

function M.detect_test_framework()
  local cwd = vim.fn.getcwd()
  
  if vim.fn.filereadable(cwd .. '/package.json') == 1 then
    integrations.test = {
      type = 'npm',
      test_cmd = 'npm test',
      test_verbose_cmd = 'npm test -- --verbose',
      test_watch_cmd = 'npm run test:watch',
      coverage_cmd = 'npm run test:coverage'
    }
  elseif vim.fn.filereadable(cwd .. '/Cargo.toml') == 1 then
    integrations.test = {
      type = 'cargo',
      test_cmd = 'cargo test',
      test_verbose_cmd = 'cargo test -- --nocapture',
      test_watch_cmd = 'cargo watch -x test',
      coverage_cmd = 'cargo tarpaulin'
    }
  elseif vim.fn.filereadable(cwd .. '/go.mod') == 1 then
    integrations.test = {
      type = 'go',
      test_cmd = 'go test ./...',
      test_verbose_cmd = 'go test -v ./...',
      test_watch_cmd = 'go test -watch ./...',
      coverage_cmd = 'go test -cover ./...'
    }
  elseif vim.fn.glob(cwd .. '/**/test_*.py') ~= '' or vim.fn.glob(cwd .. '/**/*_test.py') ~= '' then
    integrations.test = {
      type = 'pytest',
      test_cmd = 'pytest',
      test_verbose_cmd = 'pytest -v',
      test_watch_cmd = 'pytest --watch',
      coverage_cmd = 'pytest --cov'
    }
  else
    integrations.test = {
      type = 'generic',
      test_cmd = 'make test',
      test_verbose_cmd = 'make test-verbose',
      test_watch_cmd = 'make test-watch',
      coverage_cmd = 'make coverage'
    }
  end
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