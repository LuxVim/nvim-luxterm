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
  LuxtermSessionIcon         = { fg = "#ff9e64" },               -- orange accent
  LuxtermSessionName         = { fg = "#c0caf5" },               -- main foreground
  LuxtermSessionNameSelected = { fg = "#7aa2f7", bold = true },  -- bright blue highlight
  LuxtermSessionKey          = { fg = "#bb9af7", bold = true },  -- purple accent for keys
  LuxtermSessionSelected     = { fg = "#e0af68", bold = true },  -- gold/yellow for selected
  LuxtermSessionNormal       = { fg = "#565f89" },               -- muted gray
  LuxtermBorderSelected      = { fg = "#7aa2f7", bold = true },  -- active border (blue)
  LuxtermBorderNormal        = { fg = "#414868" },               -- subtle border
  LuxtermMenuIcon            = { fg = "#2ac3de" },               -- cyan accent
  LuxtermMenuText            = { fg = "#c0caf5" },               -- normal fg
  LuxtermMenuKey             = { fg = "#bb9af7", bold = true },  -- purple for shortcuts
  LuxtermPreviewTitle        = { fg = "#2ac3de", bold = true },  -- cyan title
  LuxtermPreviewContent      = { fg = "#c0caf5" },               -- normal preview text
  LuxtermPreviewEmpty        = { fg = "#565f89", italic = true } -- muted/empty
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
