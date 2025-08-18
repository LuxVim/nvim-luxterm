-- Consolidated highlight definitions for all UI components
local M = {}

-- Define highlight group names only - let colorscheme handle the colors
M.highlight_groups = {
  "LuxtermSessionIcon",
  "LuxtermSessionName", 
  "LuxtermSessionNameSelected",
  "LuxtermSessionKey",
  "LuxtermSessionSelected",
  "LuxtermSessionNormal",
  "LuxtermBorderSelected",
  "LuxtermBorderNormal",
  "LuxtermMenuIcon",
  "LuxtermMenuText",
  "LuxtermMenuKey", 
  "LuxtermPreviewTitle",
  "LuxtermPreviewContent",
  "LuxtermPreviewEmpty"
}

-- Fallback colors if no colorscheme defines them
M.fallback_highlights = {
  LuxtermSessionIcon         = { fg = "Yellow" },                  -- icon accent
  LuxtermSessionName         = { fg = "White" },                   -- main text
  LuxtermSessionNameSelected = { fg = "Cyan", bold = true },       -- active/selected
  LuxtermSessionKey          = { fg = "Magenta", bold = true },    -- shortcut keys
  LuxtermSessionSelected     = { fg = "Yellow", bold = true },     -- selected indicator
  LuxtermSessionNormal       = { fg = "Grey" },                    -- inactive
  LuxtermBorderSelected      = { fg = "Blue", bold = true },       -- active border
  LuxtermBorderNormal        = { fg = "Grey" },                    -- inactive border
  LuxtermMenuIcon            = { fg = "Cyan" },                    -- menu icons
  LuxtermMenuText            = { fg = "White" },                   -- menu text
  LuxtermMenuKey             = { fg = "Magenta", bold = true },    -- menu shortcuts
  LuxtermPreviewTitle        = { fg = "Cyan", bold = true },       -- preview title
  LuxtermPreviewContent      = { fg = "White" },                   -- preview text
  LuxtermPreviewEmpty        = { fg = "Grey", italic = true }      -- empty preview
}

function M.setup_all()
  -- Only set fallback colors if colorscheme hasn't defined them
  for _, group_name in ipairs(M.highlight_groups) do
    local existing = vim.api.nvim_get_hl(0, { name = group_name })
    if vim.tbl_isempty(existing) and M.fallback_highlights[group_name] then
      vim.api.nvim_set_hl(0, group_name, M.fallback_highlights[group_name])
    end
  end
end

function M.setup_session_highlights()
  -- Only setup fallbacks for session-related groups
  local session_groups = {
    "LuxtermSessionIcon", "LuxtermSessionName", "LuxtermSessionNameSelected",
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
