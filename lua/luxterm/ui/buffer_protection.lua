-- Reusable buffer protection utility
local M = {}

function M.setup_protection(buffer_id)
  if not buffer_id or not vim.api.nvim_buf_is_valid(buffer_id) then
    return false
  end
  
  -- Create autocmds to prevent any modification attempts
  local augroup = vim.api.nvim_create_augroup("LuxtermBufferProtection_" .. buffer_id, {clear = true})
  
  -- Prevent insertion mode and any text modification
  vim.api.nvim_create_autocmd({"InsertEnter", "TextChanged", "TextChangedI", "TextChangedP"}, {
    group = augroup,
    buffer = buffer_id,
    callback = function()
      -- Silently force back to normal mode if in insert mode
      if vim.api.nvim_get_mode().mode:match("[iR]") then
        vim.cmd("stopinsert")
      end
      return true -- prevent the event
    end
  })
  
  -- Override common editing commands
  local opts = {noremap = true, silent = true, buffer = buffer_id}
  local protected_keys = {"i", "I", "a", "A", "o", "O", "c", "C", "s", "S", "x", "X", "d", "D", "p", "P"}
  
  for _, key in ipairs(protected_keys) do
    vim.keymap.set("n", key, function()
      -- Silently ignore editing attempts
    end, opts)
  end
  
  -- Protect against paste operations
  vim.keymap.set({"n", "v"}, "<C-v>", function()
    -- Silently ignore paste attempts
  end, opts)
  
  return true
end

function M.setup_cursor_hiding(window_id, buffer_id)
  if not window_id or not vim.api.nvim_win_is_valid(window_id) then
    return false
  end
  
  if not buffer_id or not vim.api.nvim_buf_is_valid(buffer_id) then
    return false
  end
  
  -- Hide cursor in the window
  vim.api.nvim_win_set_option(window_id, "cursorline", false)
  vim.api.nvim_win_set_option(window_id, "cursorcolumn", false)
  
  -- Set cursor to invisible when in this window
  vim.api.nvim_create_autocmd("WinEnter", {
    buffer = buffer_id,
    callback = function()
      vim.opt.guicursor:append("a:hor1-Cursor/lCursor")
    end
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buffer_id,
    callback = function()
      vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"
    end
  })
  
  return true
end

return M