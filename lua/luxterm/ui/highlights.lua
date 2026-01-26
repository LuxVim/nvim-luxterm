-- Consolidated highlight definitions for all UI components
local M = {}

-- Define highlight group names only - let colorscheme handle the colors
M.highlight_groups = {
  -- Selected/Active states
  "LuxtermSessionIconSelected",
  "LuxtermSessionNameSelected",
  "LuxtermSessionSelected",
  "LuxtermBorderSelected",

  -- Normal/Inactive states
  "LuxtermSessionIcon",
  "LuxtermSessionName",
  "LuxtermSessionNormal",
  "LuxtermBorderNormal",

  -- Menu items
  "LuxtermMenuIcon",
  "LuxtermMenuText",
  "LuxtermMenuKey",

  -- Preview pane
  "LuxtermPreviewTitle",
  "LuxtermPreviewContent",
  "LuxtermPreviewEmpty",

  -- Interactive elements
  "LuxtermSessionKey",

  -- New redesign highlights
  "LuxtermStatusActive",
  "LuxtermStatusStale",
  "LuxtermStatusStopped",
  "LuxtermStatusError",
  "LuxtermSelected",
  "LuxtermDimmed",
  "LuxtermDirectory",
  "LuxtermProcess",
  "LuxtermCommand",
  "LuxtermKey",
  "LuxtermKeyLabel",
  "LuxtermSeparator",
  "LuxtermTime",
  "LuxtermHotkey",
}

M.linked_highlights = {
  LuxtermStatusActive = "DiagnosticOk",
  LuxtermStatusStale = "DiagnosticWarn",
  LuxtermStatusStopped = "Comment",
  LuxtermStatusError = "DiagnosticError",
  LuxtermSelected = "Visual",
  LuxtermDimmed = "Comment",
  LuxtermDirectory = "Directory",
  LuxtermProcess = "Normal",
  LuxtermCommand = "Comment",
  LuxtermKey = "Special",
  LuxtermKeyLabel = "Comment",
  LuxtermSeparator = "Comment",
  LuxtermTime = "Comment",
  LuxtermHotkey = "Comment",
  LuxtermSessionName = "Normal",
  LuxtermPreviewTitle = "Title",
  LuxtermPreviewContent = "Normal",
  LuxtermPreviewEmpty = "Comment",
}

-- Fallback colors if no colorscheme defines them
M.fallback_highlights = {
  -- Selected/Active states
  LuxtermSessionIconSelected = { fg = "Cyan", bold = true },       -- selected icon
  LuxtermSessionNameSelected = { fg = "Cyan", bold = true },       -- active/selected
  LuxtermSessionSelected     = { fg = "Yellow", bold = true },     -- selected indicator
  LuxtermBorderSelected      = { fg = "Blue", bold = true },       -- active border
  
  -- Normal/Inactive states
  LuxtermSessionIcon         = { fg = "Yellow" },                  -- icon accent
  LuxtermSessionName         = { fg = "White" },                   -- main text
  LuxtermSessionNormal       = { fg = "Grey" },                    -- inactive
  LuxtermBorderNormal        = { fg = "Grey" },                    -- inactive border
  
  -- Menu items
  LuxtermMenuIcon            = { fg = "Cyan" },                    -- menu icons
  LuxtermMenuText            = { fg = "White" },                   -- menu text
  LuxtermMenuKey             = { fg = "Magenta", bold = true },    -- menu shortcuts
  
  -- Preview pane
  LuxtermPreviewTitle        = { fg = "Cyan", bold = true },       -- preview title
  LuxtermPreviewContent      = { fg = "White" },                   -- preview text
  LuxtermPreviewEmpty        = { fg = "Grey", italic = true },     -- empty preview
  
  -- Interactive elements
  LuxtermSessionKey          = { fg = "Magenta", bold = true }     -- shortcut keys
}

function M.setup_all()
  for group_name, link_target in pairs(M.linked_highlights) do
    local existing = vim.api.nvim_get_hl(0, { name = group_name })
    if vim.tbl_isempty(existing) then
      vim.api.nvim_set_hl(0, group_name, { link = link_target })
    end
  end

  vim.defer_fn(function()
    for group_name, fallback in pairs(M.fallback_highlights) do
      local existing = vim.api.nvim_get_hl(0, { name = group_name })
      if vim.tbl_isempty(existing) then
        vim.api.nvim_set_hl(0, group_name, fallback)
      end
    end
  end, 200)
end

function M.setup_session_highlights()
  -- Only setup fallbacks for session-related groups
  local session_groups = {
    "LuxtermSessionIcon", "LuxtermSessionIconSelected", "LuxtermSessionName", "LuxtermSessionNameSelected",
    "LuxtermSessionKey", "LuxtermSessionSelected", "LuxtermSessionNormal", 
    "LuxtermBorderSelected", "LuxtermBorderNormal", "LuxtermMenuIcon",
    "LuxtermMenuText", "LuxtermMenuKey"
  }
  
  for _, group_name in ipairs(session_groups) do
    local existing = vim.api.nvim_get_hl(0, { name = group_name })
    if vim.tbl_isempty(existing) and M.fallback_highlights[group_name] then
      vim.api.nvim_set_hl(0, group_name, M.fallback_highlights[group_name])
    end
  end
end

function M.setup_preview_highlights()
  -- Only setup fallbacks for preview-related groups
  local preview_groups = {
    "LuxtermPreviewTitle", "LuxtermPreviewContent", "LuxtermPreviewEmpty"
  }
  
  for _, group_name in ipairs(preview_groups) do
    local existing = vim.api.nvim_get_hl(0, { name = group_name })
    if vim.tbl_isempty(existing) and M.fallback_highlights[group_name] then
      vim.api.nvim_set_hl(0, group_name, M.fallback_highlights[group_name])
    end
  end
end

return M
