-- Consolidated highlight definitions for all UI components
local M = {}

-- Session list highlights
M.session_highlights = {
  LuxtermSessionIcon = {fg = "#ff7801"},
  LuxtermSessionName = {fg = "#ffffff"},
  LuxtermSessionNameSelected = {fg = "#ffffff", bold = true},
  LuxtermSessionKey = {fg = "#db2dee", bold = true},
  LuxtermSessionSelected = {fg = "#FFA500", bold = true},
  LuxtermSessionNormal = {fg = "#6B6B6B"},
  LuxtermBorderSelected = {fg = "#FFA500", bold = true},
  LuxtermBorderNormal = {fg = "#6B6B6B"}
}

-- Menu highlights
M.menu_highlights = {
  LuxtermMenuIcon = {fg = "#4ec9b0"},
  LuxtermMenuText = {fg = "#d4d4d4"},
  LuxtermMenuKey = {fg = "#db2dee", bold = true}
}

-- Preview pane highlights
M.preview_highlights = {
  LuxtermPreviewTitle = {fg = "#4ec9b0", bold = true},
  LuxtermPreviewContent = {fg = "#d4d4d4"},
  LuxtermPreviewEmpty = {fg = "#6B6B6B", italic = true}
}

function M.setup_all()
  -- Set all highlight groups
  for name, opts in pairs(M.session_highlights) do
    vim.api.nvim_set_hl(0, name, opts)
  end
  
  for name, opts in pairs(M.menu_highlights) do
    vim.api.nvim_set_hl(0, name, opts)
  end
  
  for name, opts in pairs(M.preview_highlights) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

function M.setup_session_highlights()
  for name, opts in pairs(M.session_highlights) do
    vim.api.nvim_set_hl(0, name, opts)
  end
  
  for name, opts in pairs(M.menu_highlights) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

function M.setup_preview_highlights()
  for name, opts in pairs(M.preview_highlights) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

return M