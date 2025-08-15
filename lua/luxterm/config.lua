local M = {}

M.defaults = {
  manager_width = 0.8,     -- Percentage of editor width
  manager_height = 0.8,    -- Percentage of editor height
  preview_enabled = true,  -- Show live preview in right pane
  auto_close = false,      -- Auto close when switching to session
  focus_on_create = false, -- Focus terminal after creating session
  
  -- Window layout options
  border = "rounded",      -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
  left_pane_width = 0.3,   -- Left pane width as percentage of total width
  
  -- Preview options
  preview_max_lines = 1000,  -- Max lines to show in preview
  preview_refresh_ms = 2000, -- Preview refresh interval in milliseconds
  
  -- Session options
  default_shell = nil,     -- Default shell (nil = use vim.o.shell)
  session_name_template = "Terminal %d", -- Template for auto-generated names
  
  -- Performance options
  cache_enabled = true,    -- Enable caching for better performance
  lazy_render = true,      -- Only render when content changes
  
  -- Keymaps for manager window
  keymaps = {
    -- Manager controls
    new_session = "n",
    close_manager = "<Esc>",
    delete_session = "d",
    rename_session = "r",
    
    -- Navigation
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
    
    -- Vim-style navigation
    move_down = "j",
    move_up = "k",
  },
  
  -- Colors and highlights
  highlights = {
    active_session = "PmenuSel",   -- Highlight group for active session
    inactive_session = "Pmenu",    -- Highlight group for inactive sessions
    border = "FloatBorder",        -- Highlight group for window borders
    preview_border = "FloatBorder" -- Highlight group for preview border
  }
}

M.options = {}

function M.setup(user_config)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_config or {})
  
  -- Validate configuration
  M.validate_config()
  
  -- Set up highlights if needed
  M.setup_highlights()
end

--- Validate user configuration
function M.validate_config()
  local opts = M.options
  
  -- Validate numeric ranges
  if opts.manager_width <= 0 or opts.manager_width > 1 then
    vim.notify("luxterm: manager_width must be between 0 and 1", vim.log.levels.WARN)
    opts.manager_width = M.defaults.manager_width
  end
  
  if opts.manager_height <= 0 or opts.manager_height > 1 then
    vim.notify("luxterm: manager_height must be between 0 and 1", vim.log.levels.WARN)
    opts.manager_height = M.defaults.manager_height
  end
  
  if opts.left_pane_width <= 0 or opts.left_pane_width >= 1 then
    vim.notify("luxterm: left_pane_width must be between 0 and 1", vim.log.levels.WARN)
    opts.left_pane_width = M.defaults.left_pane_width
  end
  
  -- Validate preview refresh interval
  if opts.preview_refresh_ms < 100 then
    vim.notify("luxterm: preview_refresh_ms should be at least 100ms", vim.log.levels.WARN)
    opts.preview_refresh_ms = 100
  end
  
  -- Ensure shell is available
  if opts.default_shell and vim.fn.executable(opts.default_shell) == 0 then
    vim.notify("luxterm: default_shell '" .. opts.default_shell .. "' not found, using vim.o.shell", vim.log.levels.WARN)
    opts.default_shell = nil
  end
end

--- Setup highlight groups
function M.setup_highlights()
  -- These are just fallbacks, users can override with their own colorscheme
  local highlights = {
    LuxtermActiveSession = { link = M.options.highlights.active_session },
    LuxtermInactiveSession = { link = M.options.highlights.inactive_session },
    LuxtermBorder = { link = M.options.highlights.border },
    LuxtermPreviewBorder = { link = M.options.highlights.preview_border }
  }
  
  for group, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

--- Get effective shell to use
function M.get_shell()
  return M.options.default_shell or vim.o.shell
end

--- Get session name from template
function M.get_session_name(session_id)
  return string.format(M.options.session_name_template, session_id)
end

return M
