local M = {}

local test_frameworks = {
  npm = {
    files = { 'package.json' },
    patterns = {},
    config = {
      type = 'npm',
      test_cmd = 'npm test',
      test_verbose_cmd = 'npm test -- --verbose',
      test_watch_cmd = 'npm run test:watch',
      coverage_cmd = 'npm run test:coverage'
    }
  },
  cargo = {
    files = { 'Cargo.toml' },
    patterns = {},
    config = {
      type = 'cargo',
      test_cmd = 'cargo test',
      test_verbose_cmd = 'cargo test -- --nocapture',
      test_watch_cmd = 'cargo watch -x test',
      coverage_cmd = 'cargo tarpaulin'
    }
  },
  go = {
    files = { 'go.mod' },
    patterns = {},
    config = {
      type = 'go',
      test_cmd = 'go test ./...',
      test_verbose_cmd = 'go test -v ./...',
      test_watch_cmd = 'go test -watch ./...',
      coverage_cmd = 'go test -cover ./...'
    }
  },
  pytest = {
    files = {},
    patterns = { '**/test_*.py', '/**/*_test.py' },
    config = {
      type = 'pytest',
      test_cmd = 'pytest',
      test_verbose_cmd = 'pytest -v',
      test_watch_cmd = 'pytest --watch',
      coverage_cmd = 'pytest --cov'
    }
  },
  jest = {
    files = { 'jest.config.js', 'jest.config.ts', 'jest.config.json' },
    patterns = {},
    config = {
      type = 'jest',
      test_cmd = 'npm test',
      test_verbose_cmd = 'npm test -- --verbose',
      test_watch_cmd = 'npm test -- --watch',
      coverage_cmd = 'npm test -- --coverage'
    }
  },
  rspec = {
    files = { 'spec/spec_helper.rb', '.rspec' },
    patterns = {},
    config = {
      type = 'rspec',
      test_cmd = 'rspec',
      test_verbose_cmd = 'rspec --format documentation',
      test_watch_cmd = 'rspec --watch',
      coverage_cmd = 'rspec --coverage'
    }
  }
}

local function file_exists(path)
  return vim.fn.filereadable(path) == 1
end

local function pattern_exists(cwd, pattern)
  return vim.fn.glob(cwd .. pattern) ~= ''
end

function M.detect(cwd)
  cwd = cwd or vim.fn.getcwd()
  
  for name, framework in pairs(test_frameworks) do
    local matches = false
    
    for _, file in ipairs(framework.files) do
      if file_exists(cwd .. '/' .. file) then
        matches = true
        break
      end
    end
    
    if not matches then
      for _, pattern in ipairs(framework.patterns) do
        if pattern_exists(cwd, pattern) then
          matches = true
          break
        end
      end
    end
    
    if matches then
      return framework.config
    end
  end
  
  return {
    type = 'generic',
    test_cmd = 'make test',
    test_verbose_cmd = 'make test-verbose',
    test_watch_cmd = 'make test-watch',
    coverage_cmd = 'make coverage'
  }
end

function M.get_test_command(config, command_type)
  if not config then
    return nil
  end
  
  local cmd_map = {
    test = config.test_cmd,
    verbose = config.test_verbose_cmd,
    watch = config.test_watch_cmd,
    coverage = config.coverage_cmd
  }
  
  return cmd_map[command_type]
end

function M.run_test_command(command_type, terminal_name, cwd)
  local config = M.detect(cwd)
  local cmd = M.get_test_command(config, command_type)
  
  if not cmd then
    vim.notify('LuxTerm: No ' .. command_type .. ' command found for ' .. config.type, vim.log.levels.WARN)
    return
  end
  
  terminal_name = terminal_name or 'test'
  require('luxterm').send_command(terminal_name, cmd)
end

return M