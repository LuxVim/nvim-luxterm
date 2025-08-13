local config = require("luxterm.config")
local sessions = require("luxterm.sessions")

local M = {}

--- Keymaps for Manager UI
function M.set_manager_keymaps(bufnr, ui_callbacks)
  local opts = { noremap = true, silent = true, buffer = bufnr }

  vim.keymap.set("n", config.options.keymaps.new_session, function()
    ui_callbacks.create_new_session()
  end, opts)

  vim.keymap.set("n", config.options.keymaps.close_manager, function()
    ui_callbacks.close_manager()
  end, opts)

  vim.keymap.set("n", "d", function()
    ui_callbacks.delete_active_session()
  end, opts)

  vim.keymap.set("n", "r", function()
    M.rename_session(ui_callbacks.render_manager)
  end, opts)

  for i = 1, 9 do
    vim.keymap.set("n", tostring(i), function()
      ui_callbacks.select_session(i)
    end, opts)
  end

  vim.keymap.set("n", "j", function()
    M.select_next_session(ui_callbacks.navigate_to_session)
  end, opts)

  vim.keymap.set("n", "k", function()
    M.select_previous_session(ui_callbacks.navigate_to_session)
  end, opts)

  vim.keymap.set("n", "<Down>", function()
    M.select_next_session(ui_callbacks.navigate_to_session)
  end, opts)

  vim.keymap.set("n", "<Up>", function()
    M.select_previous_session(ui_callbacks.navigate_to_session)
  end, opts)

  vim.keymap.set("n", "<CR>", function()
    local active_session = sessions.get_active_session()
    if active_session then
      local session_list = sessions.get_sessions()
      for i, session in ipairs(session_list) do
        if session.id == active_session.id then
          ui_callbacks.select_session(i)
          break
        end
      end
    end
  end, opts)
end

--- Keymaps for in-terminal navigation
function M.set_terminal_keymaps(bufnr)
  local opts = { noremap = true, silent = true, buffer = bufnr }

  vim.keymap.set("t", config.options.keymaps.next_session, function()
    local next_id = sessions.get_next_session_id()
    if next_id then
      sessions.switch_to_session(next_id)
    end
  end, opts)

  vim.keymap.set("t", config.options.keymaps.prev_session, function()
    local prev_id = sessions.get_previous_session_id()
    if prev_id then
      sessions.switch_to_session(prev_id)
    end
  end, opts)
end

--- Setup global keymaps for terminal navigation
function M.setup_global_keymaps()
  -- Terminal manager toggle with Control+T (works in normal and terminal mode)
  vim.keymap.set("n", "<C-t>", function()
    local init = require("luxterm.init")
    init.toggle_manager()
  end, { noremap = true, silent = true, desc = "Toggle Luxterm" })
  
  vim.keymap.set("t", "<C-t>", function()
    local init = require("luxterm.init")
    init.toggle_manager()
  end, { noremap = true, silent = true, desc = "Toggle Luxterm" })

  vim.keymap.set("n", config.options.keymaps.next_session, function()
    local next_id = sessions.get_next_session_id()
    if next_id then
      sessions.switch_to_session(next_id)
    end
  end, { noremap = true, silent = true })

  vim.keymap.set("n", config.options.keymaps.prev_session, function()
    local prev_id = sessions.get_previous_session_id()
    if prev_id then
      sessions.switch_to_session(prev_id)
    end
  end, { noremap = true, silent = true })
end

--- Select next session in manager
function M.select_next_session(select_callback)
  local session_list = sessions.get_sessions()
  if #session_list == 0 then return end

  local active_id = sessions.get_active_session()
  local current_index = 1

  if active_id then
    for i, session in ipairs(session_list) do
      if session.id == active_id.id then
        current_index = i
        break
      end
    end
  end

  local next_index = (current_index % #session_list) + 1
  select_callback(next_index)
end

--- Select previous session in manager
function M.select_previous_session(select_callback)
  local session_list = sessions.get_sessions()
  if #session_list == 0 then return end

  local active_id = sessions.get_active_session()
  local current_index = 1

  if active_id then
    for i, session in ipairs(session_list) do
      if session.id == active_id.id then
        current_index = i
        break
      end
    end
  end

  local prev_index = current_index == 1 and #session_list or current_index - 1
  select_callback(prev_index)
end

--- Rename the active session
function M.rename_session(render_callback)
  local active_session = sessions.get_active_session()
  if not active_session then return end

  vim.ui.input({
    prompt = "New session name: ",
    default = active_session.name
  }, function(input)
    if input and input ~= "" then
      active_session.name = input
      render_callback()
    end
  end)
end

--- Keymaps for individual session floating window
function M.set_session_window_keymaps(bufnr)
  local opts = { noremap = true, silent = true, buffer = bufnr }

  -- Allow Escape to close the session window and return to normal mode
  vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", opts)
  
  -- Ctrl+Esc to close the floating window entirely
  vim.keymap.set("t", "<C-Esc>", function()
    local ui = require("luxterm.ui")
    ui.close_session_window()
  end, opts)
  
  vim.keymap.set("n", "<Esc>", function()
    local ui = require("luxterm.ui")
    ui.close_session_window()
  end, opts)
end

return M
