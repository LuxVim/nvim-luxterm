-- Simplified preview pane component
local M = {
  window_id = nil,
  buffer_id = nil,
  current_session = nil
}

function M.setup(opts)
  -- Setup is minimal
end

function M.create_window(winid, bufnr)
  M.window_id = winid
  M.buffer_id = bufnr
  
  -- Set buffer properties
  if M.buffer_id and vim.api.nvim_buf_is_valid(M.buffer_id) then
    -- Set buffer options
    vim.api.nvim_buf_set_option(M.buffer_id, "buftype", "nofile")
    vim.api.nvim_buf_set_option(M.buffer_id, "swapfile", false)
    vim.api.nvim_buf_set_option(M.buffer_id, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(M.buffer_id, "filetype", "luxterm_preview")
    -- Only set modifiable to false, don't set readonly (causes conflicts)
    vim.api.nvim_buf_set_option(M.buffer_id, "modifiable", false)
  end
  
  -- Hide cursor in the preview window
  if M.window_id and vim.api.nvim_win_is_valid(M.window_id) then
    vim.api.nvim_win_set_option(M.window_id, "cursorline", false)
    vim.api.nvim_win_set_option(M.window_id, "cursorcolumn", false)
    -- Set cursor to invisible when in this window
    vim.api.nvim_create_autocmd("WinEnter", {
      buffer = M.buffer_id,
      callback = function()
        vim.opt.guicursor:append("a:hor1-Cursor/lCursor")
      end
    })
    vim.api.nvim_create_autocmd("WinLeave", {
      buffer = M.buffer_id,
      callback = function()
        vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"
      end
    })
  end
  
  M.setup_highlights()
end

function M.setup_highlights()
  vim.api.nvim_set_hl(0, "LuxtermPreviewTitle", {fg = "#4ec9b0", bold = true})
  vim.api.nvim_set_hl(0, "LuxtermPreviewContent", {fg = "#d4d4d4"})
  vim.api.nvim_set_hl(0, "LuxtermPreviewEmpty", {fg = "#6B6B6B", italic = true})
end

function M.update_preview(session)
  if not M.window_id or not vim.api.nvim_win_is_valid(M.window_id) then
    return
  end
  
  if not M.buffer_id or not vim.api.nvim_buf_is_valid(M.buffer_id) then
    return
  end
  
  M.current_session = session
  
  local lines = {}
  local highlights = {}
  
  if not session then
    table.insert(lines, "")
    table.insert(lines, "  Select a session to preview")
    table.insert(highlights, {
      line = 1,
      col_start = 0,
      col_end = -1,
      group = "LuxtermPreviewEmpty"
    })
  else
    -- Session info header
    table.insert(lines, "  Session: " .. session.name)
    table.insert(lines, "  Status: " .. session:get_status())
    table.insert(lines, "")
    
    -- Highlight header
    table.insert(highlights, {
      line = 0,
      col_start = 0,
      col_end = -1,
      group = "LuxtermPreviewTitle"
    })
    table.insert(highlights, {
      line = 1,
      col_start = 0,
      col_end = -1,
      group = "LuxtermPreviewTitle"
    })
    
    -- Get content preview
    local content_lines = session:get_content_preview()
    
    if #content_lines > 0 then
      table.insert(lines, "  Recent output:")
      table.insert(lines, "")
      
      table.insert(highlights, {
        line = #lines - 2,
        col_start = 0,
        col_end = -1,
        group = "LuxtermPreviewTitle"
      })
      
      -- Add content lines with proper highlighting
      for _, content_line in ipairs(content_lines) do
        local display_line = "  " .. content_line
        table.insert(lines, display_line)
        
        table.insert(highlights, {
          line = #lines - 1,
          col_start = 0,
          col_end = -1,
          group = "LuxtermPreviewContent"
        })
      end
    else
      table.insert(lines, "  No recent output")
      table.insert(highlights, {
        line = #lines - 1,
        col_start = 0,
        col_end = -1,
        group = "LuxtermPreviewEmpty"
      })
    end
  end
  
  -- Update buffer content
  vim.api.nvim_buf_set_option(M.buffer_id, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.buffer_id, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.buffer_id, "modifiable", false)
  
  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace("luxterm_preview")
  vim.api.nvim_buf_clear_namespace(M.buffer_id, ns_id, 0, -1)
  
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(M.buffer_id, ns_id, hl.group, hl.line, hl.col_start, hl.col_end)
  end
end

function M.clear_preview()
  M.update_preview(nil)
end

function M.destroy()
  M.window_id = nil
  M.buffer_id = nil
  M.current_session = nil
end

function M.is_visible()
  return M.window_id and vim.api.nvim_win_is_valid(M.window_id)
end

return M