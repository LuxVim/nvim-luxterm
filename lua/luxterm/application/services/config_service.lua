local M = {}

M.defaults = {
  manager_width = 0.8,
  manager_height = 0.8,
  preview_enabled = true,
  auto_close = false,
  focus_on_create = true,
  
  border = "rounded",
  left_pane_width = 0.3,
  
  preview_max_lines = 1000,
  preview_refresh_ms = 2000,
  
  default_shell = nil,
  session_name_template = "Terminal %d",
  
  performance = {
    cache_enabled = true,
    lazy_render = true,
    batch_delay_ms = 16,
    refresh_rate = 60,
    min_debounce_delay = 16
  },
  
  persistence = {
    enabled = false,
    storage_file = nil
  },
  
  keymaps = {
    toggle_manager = "<C-/>",
    global_session_nav = true,
    next_session = "<C-Right>",
    prev_session = "<C-Left>",
    
    manager = {
      new_session = "n",
      close_manager = "<Esc>",
      delete_session = "d",
      rename_session = "r",
      
      next_session = "<C-Right>",
      prev_session = "<C-Left>",
      select_session_1 = "1",
      select_session_2 = "2",
      select_session_3 = "3",
      select_session_4 = "4",
      select_session_5 = "5",
      select_session_6 = "6",
      select_session_7 = "7",
      select_session_8 = "8",
      select_session_9 = "9",
      
      move_down = "j",
      move_up = "k"
    }
  },
  
  highlights = {
    active_session = "PmenuSel",
    inactive_session = "Pmenu",
    border = "FloatBorder",
    preview_border = "FloatBorder"
  }
}

function M.setup(user_config)
  local config = vim.tbl_deep_extend("force", M.defaults, user_config or {})
  
  M.validate_config(config)
  M.setup_highlights(config)
  M.setup_persistence_config(config)
  
  return config
end

function M.validate_config(config)
  if config.manager_width <= 0 or config.manager_width > 1 then
    vim.notify("luxterm: manager_width must be between 0 and 1", vim.log.levels.WARN)
    config.manager_width = M.defaults.manager_width
  end
  
  if config.manager_height <= 0 or config.manager_height > 1 then
    vim.notify("luxterm: manager_height must be between 0 and 1", vim.log.levels.WARN)
    config.manager_height = M.defaults.manager_height
  end
  
  if config.left_pane_width <= 0 or config.left_pane_width >= 1 then
    vim.notify("luxterm: left_pane_width must be between 0 and 1", vim.log.levels.WARN)
    config.left_pane_width = M.defaults.left_pane_width
  end
  
  if config.preview_refresh_ms < 100 then
    vim.notify("luxterm: preview_refresh_ms should be at least 100ms", vim.log.levels.WARN)
    config.preview_refresh_ms = 100
  end
  
  if config.performance.refresh_rate < 10 or config.performance.refresh_rate > 144 then
    vim.notify("luxterm: refresh_rate should be between 10 and 144", vim.log.levels.WARN)
    config.performance.refresh_rate = M.defaults.performance.refresh_rate
  end
  
  if config.performance.batch_delay_ms < 1 or config.performance.batch_delay_ms > 100 then
    vim.notify("luxterm: batch_delay_ms should be between 1 and 100", vim.log.levels.WARN)
    config.performance.batch_delay_ms = M.defaults.performance.batch_delay_ms
  end
  
  if config.default_shell and vim.fn.executable(config.default_shell) == 0 then
    vim.notify("luxterm: default_shell '" .. config.default_shell .. "' not found, using vim.o.shell", vim.log.levels.WARN)
    config.default_shell = nil
  end
  
  M.validate_keymaps(config.keymaps)
end

function M.validate_keymaps(keymaps)
  local function is_valid_keymap(keymap)
    return type(keymap) == "string" and keymap ~= ""
  end
  
  if not is_valid_keymap(keymaps.toggle_manager) then
    vim.notify("luxterm: invalid toggle_manager keymap", vim.log.levels.WARN)
    keymaps.toggle_manager = M.defaults.keymaps.toggle_manager
  end
  
  if keymaps.global_session_nav then
    if not is_valid_keymap(keymaps.next_session) then
      vim.notify("luxterm: invalid next_session keymap", vim.log.levels.WARN)
      keymaps.next_session = M.defaults.keymaps.next_session
    end
    
    if not is_valid_keymap(keymaps.prev_session) then
      vim.notify("luxterm: invalid prev_session keymap", vim.log.levels.WARN)
      keymaps.prev_session = M.defaults.keymaps.prev_session
    end
  end
end

function M.setup_highlights(config)
  local highlights = {
    LuxtermActiveSession = { link = config.highlights.active_session },
    LuxtermInactiveSession = { link = config.highlights.inactive_session },
    LuxtermBorder = { link = config.highlights.border },
    LuxtermPreviewBorder = { link = config.highlights.preview_border }
  }
  
  for group, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

function M.setup_persistence_config(config)
  if config.persistence.enabled and not config.persistence.storage_file then
    config.persistence.storage_file = vim.fn.stdpath("data") .. "/luxterm_sessions.json"
  end
  
  if config.persistence.enabled and config.persistence.storage_file then
    local storage_dir = vim.fn.fnamemodify(config.persistence.storage_file, ":h")
    if not vim.fn.isdirectory(storage_dir) then
      vim.fn.mkdir(storage_dir, "p")
    end
  end
end

function M.get_shell(config)
  return config.default_shell or vim.o.shell
end

function M.get_session_name(config, session_id)
  return string.format(config.session_name_template, session_id)
end

function M.get_default_session_name(config)
  local session_manager = require("luxterm.domains.terminal.services.session_manager")
  local lowest_number = session_manager.get_lowest_available_session_number()
  return string.format(config.session_name_template, lowest_number)
end

function M.merge_layout_config(config, user_layout_config)
  local layout_config = {
    manager_width = config.manager_width,
    manager_height = config.manager_height,
    left_pane_width = config.left_pane_width,
    border = config.border
  }
  
  return vim.tbl_deep_extend("force", layout_config, user_layout_config or {})
end

function M.get_render_config(config)
  return {
    preview_enabled = config.preview_enabled,
    preview_max_lines = config.preview_max_lines,
    preview_refresh_ms = config.preview_refresh_ms,
    lazy_render = config.performance.lazy_render
  }
end

function M.get_performance_config(config)
  return {
    cache_enabled = config.performance.cache_enabled,
    batch_delay_ms = config.performance.batch_delay_ms,
    refresh_rate = config.performance.refresh_rate,
    min_debounce_delay = config.performance.min_debounce_delay
  }
end

function M.should_auto_close(config)
  return config.auto_close
end

function M.should_focus_on_create(config)
  return config.focus_on_create
end


return M