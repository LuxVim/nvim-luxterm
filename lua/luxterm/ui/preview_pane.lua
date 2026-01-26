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

local function shorten_path(path)
  if not path then return "unknown" end
  local home = vim.fn.expand("~")
  if path:sub(1, #home) == home then
    path = "~" .. path:sub(#home + 1)
  end
  if #path > 40 then
    path = "..." .. path:sub(-37)
  end
  return path
end

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
    table.insert(lines, "")

    local cwd = shorten_path(session:get_cwd())
    table.insert(lines, "  " .. cwd)
    table.insert(highlights, {
      line = #lines - 1,
      col_start = 0,
      col_end = -1,
      group = "LuxtermDirectory"
    })

    local process, status = session:get_process()
    local last_cmd = session:get_last_command()
    local process_line
    if process then
      if last_cmd then
        process_line = process .. " (" .. last_cmd:sub(1, 30) .. ")"
      else
        process_line = process
      end
    else
      process_line = status
    end
    table.insert(lines, "  " .. process_line)
    table.insert(highlights, {
      line = #lines - 1,
      col_start = 0,
      col_end = -1,
      group = "LuxtermProcess"
    })

    if last_cmd then
      table.insert(lines, "  $ " .. last_cmd:sub(1, 40))
      table.insert(highlights, {
        line = #lines - 1,
        col_start = 0,
        col_end = -1,
        group = "LuxtermCommand"
      })
    end

    table.insert(lines, "")
    table.insert(lines, "  " .. string.rep("─", 36))
    table.insert(highlights, {
      line = #lines - 1,
      col_start = 0,
      col_end = -1,
      group = "LuxtermSeparator"
    })
    table.insert(lines, "")

    local content_lines = session:get_content_preview()

    if #content_lines > 0 then
      local max_lines = 15
      local start_idx = math.max(1, #content_lines - max_lines + 1)

      for i = start_idx, #content_lines do
        local content_line = content_lines[i]
        if content_line and #content_line > 0 then
          local display_line = "  " .. content_line:sub(1, 60)
          table.insert(lines, display_line)

          table.insert(highlights, {
            line = #lines - 1,
            col_start = 0,
            col_end = -1,
            group = "LuxtermPreviewContent"
          })
        end
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

  buffer_protection.update_protected_buffer_content(M.buffer_id, lines)
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