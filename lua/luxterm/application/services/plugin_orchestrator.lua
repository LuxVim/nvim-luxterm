local session_manager = require("luxterm.domains.terminal.services.session_manager")
local content_extractor = require("luxterm.domains.terminal.services.content_extractor")
local session_repository = require("luxterm.domains.terminal.repositories.session_repository")
local cache_coordinator = require("luxterm.infrastructure.cache.cache_coordinator")
local timer_manager = require("luxterm.infrastructure.nvim.timer_manager")
local api_adapter = require("luxterm.infrastructure.nvim.api_adapter")
local event_bus = require("luxterm.infrastructure.events.event_bus")
local event_types = require("luxterm.infrastructure.events.event_types")

local create_session_use_case = require("luxterm.application.use_cases.create_session")
local delete_session_use_case = require("luxterm.application.use_cases.delete_session")
local switch_session_use_case = require("luxterm.application.use_cases.switch_session")
local toggle_manager_use_case = require("luxterm.application.use_cases.toggle_manager")

local M = {
  initialized = false,
  config = {},
  stats = {
    sessions_created = 0,
    sessions_deleted = 0,
    manager_toggles = 0,
    uptime_start = nil
  }
}

function M.initialize(user_config)
  if M.initialized then
    return true
  end
  
  M.stats.uptime_start = vim.loop.now()
  
  local config_service = require("luxterm.application.services.config_service")
  M.config = config_service.setup(user_config)
  
  M._setup_infrastructure()
  M._setup_domain_services()
  M._setup_autocommands()
  M._setup_user_commands()
  M._setup_global_keymaps()
  M._setup_event_handlers()
  
  M.initialized = true
  
  event_bus.emit("luxterm_initialized", {
    config = M.config,
    timestamp = vim.loop.now()
  })
  
  return true
end

function M._setup_infrastructure()
  api_adapter.setup({
    batch_delay_ms = M.config.performance.batch_delay_ms or 16
  })
  
  timer_manager.setup({
    refresh_rate = M.config.performance.refresh_rate or 60,
    min_debounce_delay = M.config.performance.min_debounce_delay or 16
  })
  
  cache_coordinator.setup()
end

function M._setup_domain_services()
  session_manager.setup()
  content_extractor.setup()
  
  session_repository.setup({
    persistence_enabled = M.config.persistence.enabled or false,
    storage_file = M.config.persistence.storage_file
  })
  
  local session_list = require("luxterm.domains.ui.components.session_list")
  local preview_pane = require("luxterm.domains.ui.components.preview_pane")
  local floating_window = require("luxterm.domains.ui.components.floating_window")
  
  session_list.setup()
  preview_pane.setup()
  floating_window.setup()
end

function M._setup_autocommands()
  vim.api.nvim_create_autocmd("TermOpen", {
    group = vim.api.nvim_create_augroup("LuxtermTermOpen", { clear = true }),
    callback = function(args)
      M._handle_terminal_opened(args.buf)
    end
  })
  
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = vim.api.nvim_create_augroup("LuxtermBufWipeout", { clear = true }),
    callback = function(args)
      event_bus.emit(event_types.TERMINAL_CLOSED, { bufnr = args.buf })
    end
  })
  
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("LuxtermVimLeavePre", { clear = true }),
    callback = function()
      M.cleanup()
    end
  })
end

function M._handle_terminal_opened(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= 'terminal' then
    return
  end
  
  local sessions = session_manager.get_all_sessions()
  local already_managed = false
  
  for _, session in ipairs(sessions) do
    if session.bufnr == bufnr then
      already_managed = true
      break
    end
  end
  
  if not already_managed then
    local buf_name = vim.api.nvim_buf_get_name(bufnr)
    if not string.match(buf_name, "luxterm") then
      return
    end
  end
  
  event_bus.emit(event_types.TERMINAL_OPENED, { bufnr = bufnr })
end

function M._setup_user_commands()
  vim.api.nvim_create_user_command("LuxtermToggle", function()
    toggle_manager_use_case.execute()
    M.stats.manager_toggles = M.stats.manager_toggles + 1
  end, {
    desc = "Toggle Luxterm session manager"
  })
  
  vim.api.nvim_create_user_command("LuxtermNew", function(opts)
    local name = opts.args ~= "" and opts.args or nil
    create_session_use_case.execute({ name = name, focus_on_create = true })
  end, {
    nargs = "?",
    desc = "Create new terminal session"
  })
  
  vim.api.nvim_create_user_command("LuxtermNext", function()
    switch_session_use_case.execute_next_session({ focus_session = true })
  end, {
    desc = "Switch to next terminal session"
  })
  
  vim.api.nvim_create_user_command("LuxtermPrev", function()
    switch_session_use_case.execute_previous_session({ focus_session = true })
  end, {
    desc = "Switch to previous terminal session"
  })
  
  vim.api.nvim_create_user_command("LuxtermKill", function(opts)
    if opts.args ~= "" then
      delete_session_use_case.execute_by_pattern(opts.args, { confirm = true })
    else
      delete_session_use_case.execute_active_session({ confirm = true })
    end
  end, {
    nargs = "?",
    desc = "Delete terminal session(s)"
  })
  
  vim.api.nvim_create_user_command("LuxtermList", function()
    local sessions = session_manager.get_all_sessions()
    if #sessions == 0 then
      print("No active sessions")
      return
    end
    
    print("Active sessions:")
    for i, session in ipairs(sessions) do
      local status = session:get_status()
      local active_marker = session.id == session_manager.get_active_session().id and " (active)" or ""
      print(string.format("  %d. %s [%s]%s", i, session.name, status, active_marker))
    end
  end, {
    desc = "List all terminal sessions"
  })
  
  vim.api.nvim_create_user_command("LuxtermStats", function()
    M._show_stats()
  end, {
    desc = "Show Luxterm statistics"
  })
end

function M._setup_global_keymaps()
  local keymap_opts = { noremap = true, silent = true, desc = "Toggle Luxterm manager" }
  
  vim.keymap.set("n", M.config.keymaps.toggle_manager, function()
    toggle_manager_use_case.execute()
    M.stats.manager_toggles = M.stats.manager_toggles + 1
  end, keymap_opts)
  
  vim.keymap.set("t", M.config.keymaps.toggle_manager, function()
    toggle_manager_use_case.execute()
    M.stats.manager_toggles = M.stats.manager_toggles + 1
  end, keymap_opts)
  
  if M.config.keymaps.global_session_nav then
    vim.keymap.set("n", M.config.keymaps.next_session, function()
      switch_session_use_case.execute_next_session({ focus_session = true })
    end, { noremap = true, silent = true, desc = "Next terminal session" })
    
    vim.keymap.set("n", M.config.keymaps.prev_session, function()
      switch_session_use_case.execute_previous_session({ focus_session = true })
    end, { noremap = true, silent = true, desc = "Previous terminal session" })
  end
end

function M._setup_event_handlers()
  event_bus.subscribe(event_types.SESSION_CREATED, function(payload)
    M.stats.sessions_created = M.stats.sessions_created + 1
  end)
  
  event_bus.subscribe(event_types.SESSION_DELETED, function(payload)
    M.stats.sessions_deleted = M.stats.sessions_deleted + 1
  end)
  
  event_bus.subscribe(event_types.MANAGER_OPENED, function(payload)
    cache_coordinator.cleanup_old_entries()
  end)
end

function M._show_stats()
  local uptime = (vim.loop.now() - M.stats.uptime_start) / 1000
  local cache_stats = cache_coordinator.get_stats()
  
  local stats_lines = {
    "Luxterm Statistics:",
    "",
    string.format("Uptime: %.1f seconds", uptime),
    string.format("Sessions created: %d", M.stats.sessions_created),
    string.format("Sessions deleted: %d", M.stats.sessions_deleted),
    string.format("Manager toggles: %d", M.stats.manager_toggles),
    string.format("Active sessions: %d", session_manager.get_session_count()),
    "",
    "Cache Statistics:",
    string.format("Cache hit rate: %.1f%%", cache_stats.hit_rate),
    string.format("Cache hits: %d", cache_stats.hits),
    string.format("Cache misses: %d", cache_stats.misses),
    string.format("Cache invalidations: %d", cache_stats.invalidations),
    string.format("Active cache layers: %d", cache_stats.cache_count)
  }
  
  for _, line in ipairs(stats_lines) do
    print(line)
  end
end

function M.get_public_api()
  return {
    toggle_manager = function(params)
      return toggle_manager_use_case.execute(params)
    end,
    
    create_session = function(params)
      return create_session_use_case.execute(params)
    end,
    
    delete_session = function(session_id, params)
      return delete_session_use_case.execute(session_id, params)
    end,
    
    switch_session = function(session_id, params)
      return switch_session_use_case.execute(session_id, params)
    end,
    
    get_sessions = function()
      return session_manager.get_all_sessions()
    end,
    
    get_active_session = function()
      return session_manager.get_active_session()
    end,
    
    get_stats = function()
      return M.stats
    end,
    
    get_config = function()
      return M.config
    end,
    
    is_manager_open = function()
      return toggle_manager_use_case.is_manager_open()
    end
  }
end

function M.cleanup()
  if not M.initialized then
    return
  end
  
  timer_manager.cleanup_all()
  content_extractor.cleanup()
  cache_coordinator.cleanup_old_entries()
  event_bus.clear_all()
  
  M.initialized = false
end

function M.is_initialized()
  return M.initialized
end

return M