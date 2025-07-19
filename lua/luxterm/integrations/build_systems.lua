local M = {}

local build_systems = {
  npm = {
    files = { 'package.json' },
    config = {
      type = 'npm',
      build_cmd = 'npm run build',
      dev_cmd = 'npm run dev',
      start_cmd = 'npm start',
      install_cmd = 'npm install',
      test_cmd = 'npm test'
    }
  },
  cargo = {
    files = { 'Cargo.toml' },
    config = {
      type = 'cargo',
      build_cmd = 'cargo build',
      dev_cmd = 'cargo run',
      start_cmd = 'cargo run --release',
      install_cmd = 'cargo install',
      test_cmd = 'cargo test'
    }
  },
  go = {
    files = { 'go.mod' },
    config = {
      type = 'go',
      build_cmd = 'go build',
      dev_cmd = 'go run .',
      start_cmd = 'go run .',
      install_cmd = 'go mod tidy',
      test_cmd = 'go test ./...'
    }
  },
  make = {
    files = { 'Makefile', 'makefile' },
    config = {
      type = 'make',
      build_cmd = 'make',
      dev_cmd = 'make dev',
      start_cmd = 'make run',
      install_cmd = 'make install',
      test_cmd = 'make test'
    }
  },
  python = {
    files = { 'setup.py', 'pyproject.toml', 'requirements.txt' },
    config = function(cwd)
      return {
        type = 'python',
        build_cmd = 'python setup.py build',
        dev_cmd = 'python -m pip install -e .',
        start_cmd = 'python -m ' .. vim.fn.fnamemodify(cwd, ':t'),
        install_cmd = 'pip install -e .',
        test_cmd = 'python -m pytest'
      }
    end
  }
}

local function file_exists(path)
  return vim.fn.filereadable(path) == 1
end

function M.detect(cwd)
  cwd = cwd or vim.fn.getcwd()
  
  for name, system in pairs(build_systems) do
    for _, file in ipairs(system.files) do
      if file_exists(cwd .. '/' .. file) then
        local config = system.config
        if type(config) == 'function' then
          config = config(cwd)
        end
        return config
      end
    end
  end
  
  return {
    type = 'generic',
    build_cmd = 'make',
    dev_cmd = './run.sh',
    start_cmd = './start.sh',
    install_cmd = './install.sh',
    test_cmd = './test.sh'
  }
end

function M.get_build_command(config, command_type)
  if not config then
    return nil
  end
  
  local cmd_map = {
    build = config.build_cmd,
    dev = config.dev_cmd,
    start = config.start_cmd,
    install = config.install_cmd,
    test = config.test_cmd
  }
  
  return cmd_map[command_type]
end

function M.run_build_command(command_type, terminal_name, cwd)
  local config = M.detect(cwd)
  local cmd = M.get_build_command(config, command_type)
  
  if not cmd then
    vim.notify('LuxTerm: No ' .. command_type .. ' command found for ' .. config.type, vim.log.levels.WARN)
    return
  end
  
  terminal_name = terminal_name or 'build'
  require('luxterm').send_command(terminal_name, cmd)
end

return M