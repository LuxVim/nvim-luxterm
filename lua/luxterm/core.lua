-- Core luxterm module - consolidates all use cases and manages the plugin
local session_manager = require("luxterm.session_manager")
local session_list = require("luxterm.ui.session_list")
local preview_pane = require("luxterm.ui.preview_pane")
local floating_window = require("luxterm.ui.floating_window")
local events = require("luxterm.events")
local highlights = require("luxterm.ui.highlights")
local utils = require("luxterm.utils")

local M = {
  initialized = false,
  config = {},
  manager_layout = nil,
  stats = {
    sessions_created = 0,
    sessions_deleted = 0,
    manager_toggles = 0,
    uptime_start = nil
  },
  refresh_timer = nil,
  manager_refresh_timer = nil,
  autocmd_ids = {},
  keymap_ids = {}
}

-- Debounced refresh function to prevent excessive updates
local function debounced_refresh()
  if M.refresh_timer then
    M.refresh_timer:stop()
    M.refresh_timer:close()
  end
  
  M.refresh_timer = vim.loop.new_timer()
  M.refresh_timer:start(100, 0, vim.schedule_wrap(function()
    if M.is_manager_open() and M.config.preview_enabled then
      M.refresh_manager()
    end
    M.refresh_timer:close()
    M.refresh_timer = nil
  end))
end

-- Debounced manager refresh to prevent excessive UI updates
local function debounced_manager_refresh(preserve_selection_position)
  if M.manager_refresh_timer then
    M.manager_refresh_timer:stop()
    M.manager_refresh_timer:close()
  end
  
  M.manager_refresh_timer = vim.loop.new_timer()
  M.manager_refresh_timer:start(50, 0, vim.schedule_wrap(function()
    if M.is_manager_open() then
      M.refresh_manager(preserve_selection_position)
    end
    M.manager_refresh_timer:close()
    M.manager_refresh_timer = nil
  end))
end

-- Batched window operations helper to reduce API calls
local function process_session_windows(operations)
  local results = {}
  
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and floating_window.is_floating_window(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local filetype = vim.api.nvim_buf_get_option(buf, "filetype")
      
      if filetype == "terminal" or vim.api.nvim_buf_get_option(buf, "buftype") == "terminal" then
        local session = session_manager.get_session_by_buffer(buf)
        if session then
          for _, operation in ipairs(operations) do
            local result = operation.func(win, buf, session)
            if operation.collect_results then
              table.insert(results, result)
            end
            if result and operation.early_exit then
              return results
            end
          end
        end
      end
    end
  end
  
  return results
end

-- Default configuration
local default_config = {
  manager_width = 0.8,
  manager_height = 0.8,
  preview_enabled = true,
  focus_on_create = false,
  auto_hide = true,  -- Auto-hide floating windows when cursor leaves
  keymaps = {
    toggle_manager = "<C-/>",
    next_session = "<C-k>",   -- Vi-style: k for up/next
    prev_session = "<C-j>",   -- Vi-style: j for down/previous
    global_session_nav = false
  }
}

function M.setup(user_config)
  if M.initialized then
    return M.get_api()
  end
  
  M.config = vim.tbl_deep_extend("force", default_config, user_config or {})
  M.stats.uptime_start = vim.loop.now()
  
  -- Initialize components
  highlights.setup_all()
  session_manager.setup_autocmds()
  session_list.setup()
  preview_pane.setup()
  
  
  M.setup_event_handlers()
  M.setup_autocmds()
  M.setup_user_commands()
  M.setup_global_keymaps()
  M.setup_existing_terminal_keymaps()
  
  M.initialized = true
  
  events.emit(events.MANAGER_OPENED, {config = M.config})
  
  return M.get_api()
end

function M.setup_event_handlers()
  -- Session list action handlers
  session_list.on_action("new_session", function()
    M.create_session()
  end)
  
  session_list.on_action("delete_session", function()
    M.delete_selected_session()
  end)
  
  session_list.on_action("rename_session", function()
    M.rename_selected_session()
  end)
  
  session_list.on_action("close_manager", function()
    M.close_manager()
  end)
  
  session_list.on_action("open_session", function()
    M.open_selected_session()
  end)
  
  session_list.on_action("select_session", function(payload)
    M.select_session_by_index(payload.index)
  end)
  
  session_list.on_action("selection_changed", function(payload)
    M.update_preview_for_selection(payload.session)
  end)
  
  -- Event tracking
  events.on(events.SESSION_CREATED, function()
    M.stats.sessions_created = M.stats.sessions_created + 1
  end)
  
  events.on(events.SESSION_DELETED, function()
    M.stats.sessions_deleted = M.stats.sessions_deleted + 1
  end)
end

function M.setup_autocmds()
  vim.api.nvim_create_autocmd("TermOpen", {
    group = vim.api.nvim_create_augroup("LuxtermTermOpen", {clear = true}),
    callback = function(args)
      M.handle_terminal_opened(args.buf)
      -- Only set up keymaps for confirmed luxterm sessions (strict filtering applied in function)
      M.setup_terminal_keymaps(args.buf)
    end
  })
  
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("LuxtermVimLeavePre", {clear = true}),
    callback = function()
      M.cleanup()
    end
  })
  
  -- Protect luxterm_main buffers from user modification
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("LuxtermMainProtection", {clear = true}),
    pattern = "luxterm_main",
    callback = function(args)
      -- Silently ensure luxterm_main buffers remain protected
      vim.api.nvim_buf_set_option(args.buf, "modifiable", false)
    end
  })
  
  -- Auto-refresh preview when terminal content changes
  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI", "TextChangedP"}, {
    group = vim.api.nvim_create_augroup("LuxtermContentUpdate", {clear = true}),
    callback = function(args)
      if vim.bo[args.buf].buftype == "terminal" then
        local session = session_manager.get_session_by_buffer(args.buf)
        if session then
          debounced_refresh()
        end
      end
    end
  })
end

function M.handle_terminal_opened(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= 'terminal' then
    return
  end
  
  local existing_session = session_manager.get_session_by_buffer(bufnr)
  if existing_session then
    return -- Already managed
  end
  
  -- Only auto-manage terminals with "luxterm" in their name
  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  if string.match(buf_name, "luxterm") then
    events.emit(events.TERMINAL_OPENED, {bufnr = bufnr})
  end
end

function M.setup_user_commands()
  vim.api.nvim_create_user_command("LuxtermToggle", function()
    M.toggle_manager()
  end, {desc = "Toggle Luxterm session manager"})
  
  vim.api.nvim_create_user_command("LuxtermNew", function(opts)
    local name = opts.args ~= "" and opts.args or nil
    M.create_session({name = name, focus_on_create = true})
  end, {nargs = "?", desc = "Create new terminal session"})
  
  vim.api.nvim_create_user_command("LuxtermNext", function()
    M.switch_to_next_session()
  end, {desc = "Switch to next terminal session"})
  
  vim.api.nvim_create_user_command("LuxtermPrev", function()
    M.switch_to_previous_session()
  end, {desc = "Switch to previous terminal session"})
  
  vim.api.nvim_create_user_command("LuxtermKill", function(opts)
    if opts.args ~= "" then
      M.delete_sessions_by_pattern(opts.args)
    else
      M.delete_active_session()
    end
  end, {nargs = "?", desc = "Delete terminal session(s)"})
  
  vim.api.nvim_create_user_command("LuxtermList", function()
    M.list_sessions()
  end, {desc = "List all terminal sessions"})
  
  vim.api.nvim_create_user_command("LuxtermStats", function()
    M.show_stats()
  end, {desc = "Show Luxterm statistics"})
end

function M.setup_global_keymaps()
  local opts = {noremap = true, silent = true}
  
  vim.keymap.set({"n", "t"}, M.config.keymaps.toggle_manager, function()
    M.toggle_manager()
  end, vim.tbl_extend("force", opts, {desc = "Toggle Luxterm manager"}))
  
  if M.config.keymaps.global_session_nav then
    vim.keymap.set("n", M.config.keymaps.next_session, function()
      M.switch_to_next_session()
    end, vim.tbl_extend("force", opts, {desc = "Next terminal session"}))
    
    vim.keymap.set("n", M.config.keymaps.prev_session, function()
      M.switch_to_previous_session()
    end, vim.tbl_extend("force", opts, {desc = "Previous terminal session"}))
  end
end

function M.setup_terminal_keymaps(bufnr)
  local session = session_manager.get_session_by_buffer(bufnr)
  
  -- STRICT filtering: Only set up keymaps for terminals that are definitely luxterm sessions
  -- Do NOT set up keymaps based on buffer name matching - this is too broad and interferes with other terminals
  if not session then
    return
  end
  
  local opts = {noremap = true, silent = true, buffer = bufnr}
  
  -- Set up session navigation keybindings for terminal mode
  local next_key = M.config.keymaps.next_session
  local prev_key = M.config.keymaps.prev_session
  
  -- Blacklist of keys that should never be mapped in terminal mode
  local blacklisted_keys = {
    "<Esc>", "<ESC>", "<C-[>", 
    -- Add other potentially problematic keys
  }
  
  local function is_blacklisted(key)
    for _, blacklisted in ipairs(blacklisted_keys) do
      if key == blacklisted then
        return true
      end
    end
    return false
  end
  
  -- Store keymaps for cleanup
  if not M.keymap_ids[bufnr] then
    M.keymap_ids[bufnr] = {}
  end
  
  if next_key and not is_blacklisted(next_key) then
    vim.keymap.set("t", next_key, function()
      M.switch_to_next_session()
    end, vim.tbl_extend("force", opts, {desc = "Next terminal session"}))
    M.keymap_ids[bufnr]["next"] = next_key
  end
  
  if prev_key and not is_blacklisted(prev_key) then
    vim.keymap.set("t", prev_key, function()
      M.switch_to_previous_session()
    end, vim.tbl_extend("force", opts, {desc = "Previous terminal session"}))
    M.keymap_ids[bufnr]["prev"] = prev_key
  end
end

function M.setup_existing_terminal_keymaps()
  -- Set up keymaps for any existing terminal sessions
  local sessions = session_manager.get_all_sessions()
  for _, session in ipairs(sessions) do
    if session:is_valid() then
      M.setup_terminal_keymaps(session.bufnr)
    end
  end
end

-- Core functionality
function M.toggle_manager()
  M.stats.manager_toggles = M.stats.manager_toggles + 1
  
  -- Check if we're currently in a session window 
  local current_win = vim.api.nvim_get_current_win()
  local is_in_session_window = false
  
  if floating_window.is_floating_window(current_win) then
    local current_buf = vim.api.nvim_win_get_buf(current_win)
    local filetype = vim.api.nvim_buf_get_option(current_buf, "filetype")
    if filetype == "terminal" or vim.api.nvim_buf_get_option(current_buf, "buftype") == "terminal" then
      is_in_session_window = true
      -- Close ALL session terminal windows, not just the current one
      M.close_all_session_windows()
    end
  end
  
  -- If we were in a session window, always open the manager
  -- Otherwise, toggle based on current manager state
  if is_in_session_window then
    M.open_manager()
  elseif M.is_manager_open() then
    M.close_manager()
  else
    M.open_manager()
  end
end

function M.open_manager()
  if M.is_manager_open() then
    return true
  end
  
  local total_width, total_height = utils.calculate_size_from_ratio(M.config.manager_width, M.config.manager_height)
  local row, col = utils.calculate_centered_position(total_width, total_height)
  
  if M.config.preview_enabled then
    -- Calculate dynamic left panel width based on session list content
    local session_list = require("luxterm.ui.session_list")
    local required_width = session_list.calculate_required_width() + 2
    local left_width = math.min(required_width, math.floor(total_width * 0.6)) -- Cap at 60% max
    local left_width_ratio = left_width / total_width
    
    -- Create split layout
    local base_config = {
      width = total_width,
      height = total_height,
      row = row,
      col = col,
      border = "rounded"
    }
    
    local left_config = {
      title = " Sessions ",
      width_ratio = left_width_ratio,
      enter = true,
      buffer_options = {filetype = "luxterm_main"},
      auto_hide = M.config.auto_hide,
      auto_hide_callback = function(winid, bufnr)
        M.close_manager()
      end
    }
    
    local right_config = {
      title = " Preview ",
      enter = false,
      buffer_options = {filetype = "luxterm_preview"},
      auto_hide = M.config.auto_hide,
      auto_hide_callback = function(winid, bufnr)
        M.close_manager()
      end
    }
    
    local windows = floating_window.create_split_layout(base_config, left_config, right_config)
    
    M.manager_layout = {
      type = "split",
      windows = windows
    }
    
    -- Initialize components
    session_list.window_id = windows.left.winid
    session_list.buffer_id = windows.left.bufnr
    session_list.setup_keymaps()
    
    preview_pane.create_window(windows.right.winid, windows.right.bufnr)
  else
    -- Create single window layout
    local winid, bufnr = session_list.create_window({
      width = total_width,
      height = total_height,
      row = row,
      col = col,
      auto_hide = M.config.auto_hide,
      auto_hide_callback = function(winid, bufnr)
        M.close_manager()
      end
    })
    
    M.manager_layout = {
      type = "single",
      window_id = winid,
      buffer_id = bufnr
    }
  end
  
  M.refresh_manager()
  
  -- Setup close handler
  M.setup_manager_close_handler()
  
  events.emit(events.MANAGER_OPENED)
  return true
end

function M.setup_manager_close_handler()
  if M.manager_layout.type == "split" then
    -- Watch both left and right windows for closure
    local left_winid = M.manager_layout.windows.left.winid
    local right_winid = M.manager_layout.windows.right.winid
    
    if left_winid then
      local autocmd_id = vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(left_winid),
        callback = function()
          M.cleanup_manager_autocmd(autocmd_id)
          M.close_manager()
        end,
        once = true
      })
      M.autocmd_ids[autocmd_id] = true
    end
    
    if right_winid then
      local autocmd_id = vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(right_winid),
        callback = function()
          M.cleanup_manager_autocmd(autocmd_id)
          M.close_manager()
        end,
        once = true
      })
      M.autocmd_ids[autocmd_id] = true
    end
  else
    -- Single window layout
    local winid_to_watch = M.manager_layout.window_id
    if winid_to_watch then
      local autocmd_id = vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(winid_to_watch),
        callback = function()
          M.cleanup_manager_autocmd(autocmd_id)
          M.close_manager()
        end,
        once = true
      })
      M.autocmd_ids[autocmd_id] = true
    end
  end
end

function M.cleanup_manager_autocmd(autocmd_id)
  if M.autocmd_ids[autocmd_id] then
    M.autocmd_ids[autocmd_id] = nil
  end
end

function M.cleanup_all_manager_autocmds()
  for autocmd_id, _ in pairs(M.autocmd_ids) do
    pcall(vim.api.nvim_del_autocmd, autocmd_id)
  end
  M.autocmd_ids = {}
end

function M.close_manager()
  if not M.manager_layout then
    return false
  end
  
  local layout = M.manager_layout
  M.manager_layout = nil  -- Set to nil first to prevent re-entry
  
  -- Clean up all manager autocmds
  M.cleanup_all_manager_autocmds()
  
  if layout.type == "split" then
    if layout.windows and layout.windows.left then
      floating_window.close_window(layout.windows.left.winid)
    end
    if layout.windows and layout.windows.right then
      floating_window.close_window(layout.windows.right.winid)
    end
    preview_pane.destroy()
  else
    session_list.destroy()
  end
  
  events.emit(events.MANAGER_CLOSED)
  return true
end

function M.is_manager_open()
  return M.manager_layout ~= nil
end

function M.refresh_manager(preserve_selection_position)
  if not M.is_manager_open() then
    return
  end
  
  -- Trigger periodic cleanup during refresh
  session_manager.periodic_cleanup()
  
  local sessions = session_manager.get_all_sessions()
  local active_session = session_manager.get_active_session()
  local active_id = active_session and active_session.id or nil
  
  session_list.update_sessions(sessions, active_id, preserve_selection_position)
  
  if M.config.preview_enabled and preview_pane.is_visible() then
    local selected = session_list.get_selected_session()
    preview_pane.update_preview(selected)
  end
end

function M.update_preview_for_selection(session)
  if M.config.preview_enabled and preview_pane.is_visible() then
    preview_pane.update_preview(session)
  end
end

-- Session management operations
function M.create_session(opts)
  opts = opts or {}
  
  local session = session_manager.create_session({
    name = opts.name,
    activate = opts.activate
  })
  
  events.emit(events.SESSION_CREATED, {session = session})
  
  if M.is_manager_open() then
    debounced_manager_refresh()
  end
  
  if opts.focus_on_create or M.config.focus_on_create then
    M.open_session_window(session)
  end
  
  return session
end

function M.delete_session(session_id, opts)
  opts = opts or {}
  
  if opts.confirm then
    local session = session_manager.get_session(session_id)
    if session then
      local choice = vim.fn.confirm(
        "Delete session '" .. session.name .. "'?",
        "&Yes\n&No",
        2
      )
      if choice ~= 1 then
        return false
      end
    end
  end
  
  local session = session_manager.get_session(session_id)
  local bufnr = session and session.bufnr or nil
  
  local success = session_manager.delete_session(session_id)
  if success then
    -- Clean up keymaps for this session
    if bufnr then
      M.cleanup_session_keymaps(bufnr)
    end
    
    events.emit(events.SESSION_DELETED, {session_id = session_id})
    if M.is_manager_open() then
      debounced_manager_refresh(true)
    end
  end
  
  return success
end

function M.delete_active_session()
  local active = session_manager.get_active_session()
  if active then
    return M.delete_session(active.id, {confirm = true})
  end
  return false
end

function M.delete_selected_session()
  local session = session_list.get_selected_session()
  if session then
    return M.delete_session(session.id, {confirm = true})
  end
  return false
end

function M.delete_sessions_by_pattern(pattern)
  local deleted = session_manager.delete_by_pattern(pattern)
  for _, session in ipairs(deleted) do
    events.emit(events.SESSION_DELETED, {session_id = session.id})
  end
  if M.is_manager_open() then
    debounced_manager_refresh(true)
  end
  return deleted
end

function M.switch_session(session_id)
  local session = session_manager.switch_session(session_id)
  if session then
    events.emit(events.SESSION_SWITCHED, {session = session})
    if M.is_manager_open() then
      debounced_manager_refresh()
    end
  end
  return session
end

function M.switch_to_next_session()
  -- Close all existing session windows before opening the new one
  M.close_all_session_windows()
  
  local session = session_manager.switch_to_next()
  if session then
    events.emit(events.SESSION_SWITCHED, {session = session})
    if M.is_manager_open() then
      debounced_manager_refresh()
    end
    M.open_session_window(session)
  end
  return session
end

function M.switch_to_previous_session()
  -- Close all existing session windows before opening the new one
  M.close_all_session_windows()
  
  local session = session_manager.switch_to_previous()
  if session then
    events.emit(events.SESSION_SWITCHED, {session = session})
    if M.is_manager_open() then
      debounced_manager_refresh()
    end
    M.open_session_window(session)
  end
  return session
end

function M.open_selected_session()
  local session = session_list.get_selected_session()
  if session then
    -- Close all existing session windows before opening the selected one
    M.close_all_session_windows()
    M.switch_session(session.id)
    M.open_session_window(session)
    M.close_manager()
  end
end

function M.select_session_by_index(index)
  local session = session_list.get_session_at_index(index)
  if session then
    -- Close all existing session windows before opening the selected one
    M.close_all_session_windows()
    M.switch_session(session.id)
    M.open_session_window(session)
    M.close_manager()
  end
end

function M.open_session_window(session)
  if not session or not session:is_valid() then
    return false
  end
  
  floating_window.create_session_window(session, {
    auto_hide = M.config.auto_hide
  })
  
  -- Ensure terminal keymaps are set up for this session
  M.setup_terminal_keymaps(session.bufnr)
  
  return true
end

function M.rename_selected_session()
  local session = session_list.get_selected_session()
  if not session then
    return false
  end
  
  vim.ui.input({prompt = "New session name (max 12 chars): ", default = session.name}, function(new_name)
    if new_name and new_name ~= "" and new_name ~= session.name then
      -- Limit to 12 characters
      if #new_name > 12 then
        new_name = string.sub(new_name, 1, 12)
      end
      session.name = new_name
      events.emit(events.SESSION_RENAMED, {session = session})
      
      -- Update session window title if it's currently open
      M.update_session_window_title(session)
      
      if M.is_manager_open() then
        debounced_manager_refresh()
      end
    end
  end)
  
  return true
end

function M.close_all_session_windows()
  local results = process_session_windows({
    {
      func = function(win, buf, session)
        floating_window.close_window(win)
        return 1
      end,
      collect_results = true
    }
  })
  
  return #results
end

function M.update_session_window_title(session)
  if not session or not session:is_valid() then
    return false
  end
  
  -- Cache the window configuration to avoid redundant API calls
  local new_title = " " .. session.name .. " "
  local results = process_session_windows({
    {
      func = function(win, buf, found_session)
        if buf == session.bufnr then
          -- Only update if title actually changed
          local current_config = vim.api.nvim_win_get_config(win)
          if current_config.title ~= new_title then
            vim.api.nvim_win_set_config(win, {
              title = new_title,
              title_pos = "center"
            })
          end
          return true
        end
        return false
      end,
      early_exit = true
    }
  })
  
  return #results > 0
end

-- Utility functions
function M.list_sessions()
  local sessions = session_manager.get_all_sessions()
  if #sessions == 0 then
    vim.notify("No active sessions", vim.log.levels.INFO)
    return
  end
  
  local session_lines = {"Active sessions:"}
  for i, session in ipairs(sessions) do
    local status = session:get_status()
    table.insert(session_lines, string.format("  %d. %s [%s]", i, session.name, status))
  end
  vim.notify(table.concat(session_lines, "\n"), vim.log.levels.INFO)
end

function M.show_stats()
  local uptime = (vim.loop.now() - M.stats.uptime_start) / 1000
  local session_count = session_manager.get_session_count()
  local memory_stats = events.get_memory_stats()
  
  local stats_lines = {
    "Luxterm Statistics:",
    "",
    string.format("Uptime: %.1f seconds", uptime),
    string.format("Sessions created: %d", M.stats.sessions_created),
    string.format("Sessions deleted: %d", M.stats.sessions_deleted),
    string.format("Manager toggles: %d", M.stats.manager_toggles),
    string.format("Active sessions: %d", session_count),
    "",
    "Memory Statistics:",
    string.format("Event handlers: %d", memory_stats.total_handlers),
    string.format("Event types: %d", memory_stats.event_types),
    string.format("Memory usage: %.2f MB", memory_stats.memory_usage / 1024 / 1024)
  }
  
  vim.notify(table.concat(stats_lines, "\n"), vim.log.levels.INFO)
end

function M.cleanup_session_keymaps(bufnr)
  if M.keymap_ids[bufnr] then
    for _, key in pairs(M.keymap_ids[bufnr]) do
      pcall(vim.keymap.del, "t", key, {buffer = bufnr})
    end
    M.keymap_ids[bufnr] = nil
  end
end

function M.cleanup_all_session_keymaps()
  for bufnr, _ in pairs(M.keymap_ids) do
    M.cleanup_session_keymaps(bufnr)
  end
end

function M.cleanup()
  if not M.initialized then
    return
  end
  
  if M.refresh_timer then
    M.refresh_timer:stop()
    M.refresh_timer:close()
    M.refresh_timer = nil
  end
  
  if M.manager_refresh_timer then
    M.manager_refresh_timer:stop()
    M.manager_refresh_timer:close()
    M.manager_refresh_timer = nil
  end
  
  -- Clean up all autocmds and keymaps
  M.cleanup_all_manager_autocmds()
  M.cleanup_all_session_keymaps()
  
  M.close_manager()
  events.clear_all()
  M.initialized = false
end

-- Public API
function M.get_api()
  return {
    toggle_manager = function() return M.toggle_manager() end,
    create_session = function(opts) return M.create_session(opts) end,
    delete_session = function(session_id, opts) return M.delete_session(session_id, opts) end,
    switch_session = function(session_id) return M.switch_session(session_id) end,
    get_sessions = function() return session_manager.get_all_sessions() end,
    get_active_session = function() return session_manager.get_active_session() end,
    get_stats = function() return M.stats end,
    get_config = function() return M.config end,
    is_manager_open = function() return M.is_manager_open() end
  }
end

return M