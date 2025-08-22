-- Simplified preview pane component
local highlights = require("luxterm.ui.highlights")
local buffer_protection = require("luxterm.ui.buffer_protection")
local utils = require("luxterm.utils")

local M = {
  window_id = nil,
  buffer_id = nil,
  current_session = nil,
  namespace_id = nil,
  last_content_hash = nil
}

function M.setup(opts)
  highlights.setup_preview_highlights()
end

function M.create_window(winid, bufnr)
  M.window_id = winid
  M.buffer_id = bufnr
  
  -- Apply buffer protection and cursor hiding using shared utilities
  if utils.is_valid_buffer(M.buffer_id) then
    -- Set buffer options that aren't handled by the window factory
    vim.api.nvim_buf_set_option(M.buffer_id, "modifiable", false)
  end
  
  if utils.is_valid_window(M.window_id) then
    buffer_protection.setup_cursor_hiding(M.window_id, M.buffer_id)
  end
end


function M.generate_content_hash(session)
  if not session then
    return "empty"
  end
  
  local content_preview = session:get_content_preview()
  local content_string = table.concat(content_preview, "\n")
  return session.id .. ":" .. session.name .. ":" .. session:get_status() .. ":" .. content_string
end

function M.apply_highlights_optimized(highlights)
  local ns_id = vim.api.nvim_create_namespace("luxterm_preview")
  vim.api.nvim_buf_clear_namespace(M.buffer_id, ns_id, 0, -1)
  
  -- Use the original highlighting approach that was working
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(M.buffer_id, ns_id, hl.group, hl.line, hl.col_start, hl.col_end)
  end
end

function M.update_preview(session)
  if not utils.is_valid_window(M.window_id) then
    return
  end
  
  if not utils.is_valid_buffer(M.buffer_id) then
    return
  end
  
  -- Check if content actually changed to avoid unnecessary updates
  local content_hash = M.generate_content_hash(session)
  if M.last_content_hash == content_hash then
    return
  end
  
  M.current_session = session
  M.last_content_hash = content_hash
  
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
  
  -- Update buffer content using shared utility
  buffer_protection.update_protected_buffer_content(M.buffer_id, lines)
  
  -- Apply highlights optimized
  M.apply_highlights_optimized(highlights)
end

function M.clear_preview()
  M.update_preview(nil)
end

function M.destroy()
  M.window_id = nil
  M.buffer_id = nil
  M.current_session = nil
  M.namespace_id = nil
  M.last_content_hash = nil
end

function M.is_visible()
  return utils.is_valid_window(M.window_id)
end

return M