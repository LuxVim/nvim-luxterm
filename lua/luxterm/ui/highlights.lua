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
  LuxtermSessionIcon = {fg = "#ff7801"},
  LuxtermSessionName = {fg = "#ffffff"},
  LuxtermSessionNameSelected = {fg = "#ffffff", bold = true},
  LuxtermSessionKey = {fg = "#db2dee", bold = true},
  LuxtermSessionSelected = {fg = "#FFA500", bold = true},
  LuxtermSessionNormal = {fg = "#6B6B6B"},
  LuxtermBorderSelected = {fg = "#FFA500", bold = true},
  LuxtermBorderNormal = {fg = "#6B6B6B"},
  LuxtermMenuIcon = {fg = "#4ec9b0"},
  LuxtermMenuText = {fg = "#d4d4d4"},
  LuxtermMenuKey = {fg = "#db2dee", bold = true},
  LuxtermPreviewTitle = {fg = "#4ec9b0", bold = true},
  LuxtermPreviewContent = {fg = "#d4d4d4"},
  LuxtermPreviewEmpty = {fg = "#6B6B6B", italic = true}
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