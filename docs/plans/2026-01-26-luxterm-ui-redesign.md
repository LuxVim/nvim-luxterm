# Luxterm UI Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Modernize Luxterm manager UI with Lazygit-inspired terminal-native aesthetic featuring row-based session items, structured preview metadata, and theme-aware colors.

**Architecture:** Replace bordered-box session items with single-line rows. Add status bar component. Restructure preview pane with metadata header. All highlights link to Neovim standard groups for automatic theme integration.

**Tech Stack:** Pure Lua, Neovim 0.8+ API, no external dependencies.

---

## Phase 1: Configuration & Highlights Foundation

### Task 1: Extend Configuration Schema

**Files:**
- Modify: `lua/luxterm/config.lua`

**Step 1: Add new UI configuration options**

Add new `ui` table to defaults:

```lua
M.defaults = {
  manager_width = 0.8,
  manager_height = 0.8,
  preview_enabled = true,
  focus_on_create = false,
  auto_hide = true,
  keymaps = {
    toggle_manager = "<C-/>",
    next_session = "<C-k>",
    prev_session = "<C-j>",
    global_session_nav = false
  },
  ui = {
    preview = "always",
    split_ratio = 0.35,
    width = 0.7,
    height = 0.6,
    stale_timeout = 300,
    fade_timeout = 1800,
  }
}
```

**Step 2: Update schema with ui validation**

```lua
M.schema = {
  manager_width = "number",
  manager_height = "number",
  preview_enabled = "boolean",
  focus_on_create = "boolean",
  auto_hide = "boolean",
  keymaps = "table",
  ui = "table"
}
```

**Step 3: Update presets for new layout**

```lua
M.presets = {
  minimal = {
    preview_enabled = false,
    auto_hide = false,
    ui = {
      preview = "toggle",
      width = 0.4,
      height = 0.5,
    }
  },

  compact = {
    ui = {
      preview = "always",
      width = 0.6,
      height = 0.5,
    }
  },

  full_screen = {
    auto_hide = false,
    ui = {
      preview = "always",
      width = 0.95,
      height = 0.9,
    }
  }
}
```

**Step 4: Verify changes load**

Run: `lux -c "lua print(vim.inspect(require('luxterm.config').defaults.ui))"`
Expected: Shows new ui table

**Step 5: Commit**

```bash
git add lua/luxterm/config.lua
git commit -m "feat(config): add ui configuration options for redesign"
```

---

### Task 2: Implement Theme-Linked Highlights

**Files:**
- Modify: `lua/luxterm/ui/highlights.lua`

**Step 1: Replace hardcoded colors with highlight links**

Replace entire `M.fallback_highlights` and add linked highlights:

```lua
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

M.fallback_highlights = {
  LuxtermSessionIconSelected = { fg = "Cyan", bold = true },
  LuxtermSessionNameSelected = { fg = "Cyan", bold = true },
  LuxtermSessionSelected = { fg = "Yellow", bold = true },
  LuxtermBorderSelected = { fg = "Blue", bold = true },
  LuxtermSessionIcon = { fg = "Yellow" },
  LuxtermSessionName = { fg = "White" },
  LuxtermSessionNormal = { fg = "Grey" },
  LuxtermBorderNormal = { fg = "Grey" },
  LuxtermMenuIcon = { fg = "Cyan" },
  LuxtermMenuText = { fg = "White" },
  LuxtermMenuKey = { fg = "Magenta", bold = true },
  LuxtermPreviewTitle = { fg = "Cyan", bold = true },
  LuxtermPreviewContent = { fg = "White" },
  LuxtermPreviewEmpty = { fg = "Grey", italic = true },
  LuxtermSessionKey = { fg = "Magenta", bold = true }
}
```

**Step 2: Update setup_all to create linked highlights**

```lua
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
```

**Step 3: Verify highlights link correctly**

Run: `lux -c "lua vim.api.nvim_set_hl(0, 'LuxtermStatusActive', { link = 'DiagnosticOk' }); print(vim.inspect(vim.api.nvim_get_hl(0, { name = 'LuxtermStatusActive' })))"`
Expected: Shows linked highlight

**Step 4: Commit**

```bash
git add lua/luxterm/ui/highlights.lua
git commit -m "feat(highlights): link to standard Neovim highlight groups"
```

---

## Phase 2: Session Manager Metadata

### Task 3: Add Session Metadata Fields

**Files:**
- Modify: `lua/luxterm/session_manager.lua`

**Step 1: Update session object constructor with new fields**

In `create_session` function, add new fields:

```lua
local session = {
  id = tostring(M.next_id),
  name = name,
  bufnr = opts.bufnr,
  created_at = vim.loop.now(),
  last_accessed = vim.loop.now(),
  cwd = opts.cwd or vim.fn.getcwd(),
  shell = vim.o.shell,
  last_command = nil,
  command_history = {},
}
```

**Step 2: Add get_cwd method to session object**

After `session:get_content_preview()`, add:

```lua
function session:get_cwd()
  if not self:is_valid() then
    return self.cwd or "unknown"
  end

  local job_id = vim.bo[self.bufnr].channel
  if job_id and job_id > 0 then
    local pid = vim.fn.jobpid(job_id)
    if pid then
      local cwd_path = vim.fn.resolve("/proc/" .. pid .. "/cwd")
      if vim.fn.isdirectory(cwd_path) == 1 then
        self.cwd = cwd_path
        return cwd_path
      end
    end
  end

  return self.cwd or vim.fn.getcwd()
end
```

**Step 3: Add get_process method**

```lua
function session:get_process()
  if not self:is_valid() then
    return nil, "stopped"
  end

  local job_id = vim.bo[self.bufnr].channel
  if not job_id or job_id <= 0 then
    return nil, "idle"
  end

  local pid = vim.fn.jobpid(job_id)
  if not pid then
    return nil, "idle"
  end

  local proc_info = vim.api.nvim_get_proc(pid)
  if proc_info and proc_info.name then
    local proc_name = proc_info.name
    local shell_name = vim.fn.fnamemodify(vim.o.shell, ":t")
    if proc_name == shell_name then
      return nil, "idle"
    end
    return proc_name, "running"
  end

  return nil, "idle"
end
```

**Step 4: Add get_last_command method**

```lua
function session:get_last_command()
  if self.last_command then
    return self.last_command
  end

  if not self:is_valid() then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(self.bufnr, -50, -1, false)
  for i = #lines, 1, -1 do
    local line = lines[i]
    if line:match("^%s*%$%s+(.+)") then
      local cmd = line:match("^%s*%$%s+(.+)")
      self.last_command = cmd
      return cmd
    elseif line:match("^%s*%%%s+(.+)") then
      local cmd = line:match("^%s*%%%s+(.+)")
      self.last_command = cmd
      return cmd
    end
  end

  return nil
end
```

**Step 5: Add get_time_since_active method**

```lua
function session:get_time_since_active()
  local now = vim.loop.now()
  local diff_ms = now - self.last_accessed
  local diff_seconds = math.floor(diff_ms / 1000)

  if diff_seconds < 60 then
    return "now"
  elseif diff_seconds < 3600 then
    return math.floor(diff_seconds / 60) .. "m"
  elseif diff_seconds < 86400 then
    return math.floor(diff_seconds / 3600) .. "h"
  else
    return math.floor(diff_seconds / 86400) .. "d"
  end
end
```

**Step 6: Add serialize/deserialize stubs for persistence readiness**

At end of file before `return M`:

```lua
function M.serialize_session(session)
  return {
    id = session.id,
    name = session.name,
    cwd = session.cwd,
    shell = session.shell,
    created_at = session.created_at,
    last_accessed = session.last_accessed,
    last_command = session.last_command,
    command_history = session.command_history,
  }
end

function M.deserialize_session(data)
  return data
end
```

**Step 7: Verify methods work**

Run: `lux -c "lua local sm = require('luxterm.session_manager'); local s = sm.create_session(); print(s:get_time_since_active())"`
Expected: "now"

**Step 8: Commit**

```bash
git add lua/luxterm/session_manager.lua
git commit -m "feat(session): add metadata methods for UI redesign"
```

---

## Phase 3: Session List Rewrite

### Task 4: Create Row-Based Session Item Renderer

**Files:**
- Modify: `lua/luxterm/ui/session_list.lua`

**Step 1: Add status icon helper function**

Replace existing `M.get_status_icon`:

```lua
function M.get_status_icon_and_highlight(session, config)
  local process, process_status = session:get_process()
  local time_since = session:get_time_since_active()
  local stale_timeout = config.ui and config.ui.stale_timeout or 300
  local fade_timeout = config.ui and config.ui.fade_timeout or 1800

  local diff_seconds = (vim.loop.now() - session.last_accessed) / 1000

  if session:get_status() == "stopped" then
    return "○", "LuxtermStatusStopped"
  elseif process_status == "running" then
    if diff_seconds > stale_timeout then
      return "◐", "LuxtermStatusStale"
    else
      return "●", "LuxtermStatusActive"
    end
  else
    if diff_seconds > fade_timeout then
      return "○", "LuxtermDimmed"
    elseif diff_seconds > stale_timeout then
      return "◐", "LuxtermStatusStale"
    else
      return "●", "LuxtermStatusActive"
    end
  end
end
```

**Step 2: Add display name helper**

```lua
function M.get_display_name(session)
  local process, _ = session:get_process()
  if process then
    return process
  end

  local cwd = session:get_cwd()
  if cwd then
    local basename = vim.fn.fnamemodify(cwd, ":t")
    if basename and basename ~= "" then
      return basename
    end
  end

  return session.name
end
```

**Step 3: Commit partial progress**

```bash
git add lua/luxterm/ui/session_list.lua
git commit -m "feat(session_list): add status icon and display name helpers"
```

---

### Task 5: Rewrite Session Content Generation

**Files:**
- Modify: `lua/luxterm/ui/session_list.lua`

**Step 1: Replace add_session_content with row-based renderer**

Replace entire `M.add_session_content` function:

```lua
function M.add_session_content(lines, highlights, session, index, config)
  local is_selected = index == M.selected_session_index
  local line_num = #lines

  local icon, icon_hl = M.get_status_icon_and_highlight(session, config)
  local display_name = M.get_display_name(session)
  local time_since = session:get_time_since_active()
  local hotkey = string.format("[%d]", index)

  if #display_name > 15 then
    display_name = display_name:sub(1, 12) .. "..."
  end

  local name_col = 5
  local time_col = 22
  local hotkey_col = 28

  local line = string.format("  %s %-15s %4s  %s", icon, display_name, time_since, hotkey)
  table.insert(lines, line)

  local icon_start = 2
  local icon_end = icon_start + #icon
  table.insert(highlights, {
    line = line_num,
    col_start = icon_start,
    col_end = icon_end,
    group = icon_hl
  })

  local name_hl = is_selected and "LuxtermSelected" or "LuxtermSessionName"
  local fade_timeout = config.ui and config.ui.fade_timeout or 1800
  local diff_seconds = (vim.loop.now() - session.last_accessed) / 1000
  if diff_seconds > fade_timeout then
    name_hl = "LuxtermDimmed"
  end

  table.insert(highlights, {
    line = line_num,
    col_start = name_col,
    col_end = name_col + #display_name,
    group = name_hl
  })

  table.insert(highlights, {
    line = line_num,
    col_start = time_col,
    col_end = time_col + #time_since,
    group = "LuxtermTime"
  })

  table.insert(highlights, {
    line = line_num,
    col_start = hotkey_col,
    col_end = -1,
    group = "LuxtermHotkey"
  })

  if is_selected then
    table.insert(highlights, {
      line = line_num,
      col_start = 0,
      col_end = -1,
      group = "LuxtermSelected",
      priority = 50
    })
  end
end
```

**Step 2: Update generate_content to pass config**

In `M.generate_content`, update the session loop:

```lua
function M.generate_content()
  local cache_key = generate_cache_key()
  if M.cached_content and M.cached_highlights and M.content_cache_key == cache_key then
    return M.cached_content, M.cached_highlights
  end

  M.cleanup_cache_if_needed()

  local lines = {}
  local highlights = {}
  local cfg = require("luxterm.config").get()

  if #M.sessions_data == 0 then
    table.insert(lines, "")
    table.insert(lines, "  No sessions")
    table.insert(lines, "")
    table.insert(highlights, {
      line = 1,
      col_start = 0,
      col_end = -1,
      group = "LuxtermPreviewEmpty"
    })
  else
    table.insert(lines, "")
    for i, session in ipairs(M.sessions_data) do
      M.add_session_content(lines, highlights, session, i, cfg)
    end
  end

  table.insert(lines, "")
  M.add_shortcuts_content(lines, highlights)

  if #M.sessions_data <= M.max_cache_entries then
    M.cached_content = lines
    M.cached_highlights = highlights
    M.content_cache_key = cache_key
  end

  return lines, highlights
end
```

**Step 3: Verify new row format renders**

Run: `lux` then `:LuxtermNew` then toggle manager
Expected: Sessions show as single rows with icon, name, time, hotkey

**Step 4: Commit**

```bash
git add lua/luxterm/ui/session_list.lua
git commit -m "feat(session_list): implement row-based session items"
```

---

### Task 6: Implement Status Bar

**Files:**
- Modify: `lua/luxterm/ui/session_list.lua`

**Step 1: Replace add_shortcuts_content with status bar renderer**

Replace entire `M.add_shortcuts_content`:

```lua
function M.add_shortcuts_content(lines, highlights)
  local line_num = #lines

  table.insert(lines, string.rep("─", 40))
  table.insert(highlights, {
    line = line_num,
    col_start = 0,
    col_end = -1,
    group = "LuxtermSeparator"
  })

  line_num = #lines

  local shortcuts
  if #M.sessions_data == 0 then
    shortcuts = "[n]ew  [Esc] close"
  else
    shortcuts = "[n]ew  [d]el  [r]ename  [1-9] jump  [Esc]"
  end

  local status_line = " " .. shortcuts
  table.insert(lines, status_line)

  local pos = 1
  for key, label in shortcuts:gmatch("%[([^%]]+)%]([^%[]*)") do
    local key_str = "[" .. key .. "]"
    local key_start = status_line:find(key_str, pos, true)
    if key_start then
      table.insert(highlights, {
        line = line_num,
        col_start = key_start - 1,
        col_end = key_start - 1 + #key_str,
        group = "LuxtermKey"
      })

      local label_start = key_start + #key_str
      local label_trimmed = label:match("^%s*(%S*)") or ""
      if #label_trimmed > 0 then
        table.insert(highlights, {
          line = line_num,
          col_start = label_start - 1,
          col_end = label_start - 1 + #label + 1,
          group = "LuxtermKeyLabel"
        })
      end

      pos = key_start + #key_str
    end
  end
end
```

**Step 2: Update calculate_required_width for new format**

```lua
function M.calculate_required_width()
  local min_width = 42

  local max_name_length = 0
  for _, session in ipairs(M.sessions_data) do
    local display_name = M.get_display_name(session)
    max_name_length = math.max(max_name_length, #display_name)
  end

  local content_width = 2 + 2 + math.min(max_name_length, 15) + 2 + 4 + 2 + 3 + 2

  return math.max(min_width, content_width)
end
```

**Step 3: Verify status bar renders**

Run: `lux` then toggle manager
Expected: Status bar shows at bottom with highlighted keys

**Step 4: Commit**

```bash
git add lua/luxterm/ui/session_list.lua
git commit -m "feat(session_list): implement status bar with contextual hints"
```

---

## Phase 4: Preview Pane Redesign

### Task 7: Implement Structured Preview Header

**Files:**
- Modify: `lua/luxterm/ui/preview_pane.lua`

**Step 1: Add helper for shortening paths**

Add at top after M definition:

```lua
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
```

**Step 2: Rewrite update_preview with structured header**

Replace entire `M.update_preview`:

```lua
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
```

**Step 3: Verify preview shows structured header**

Run: `lux` then `:LuxtermNew` then toggle manager
Expected: Preview shows CWD, process status, last command, separator, then output

**Step 4: Commit**

```bash
git add lua/luxterm/ui/preview_pane.lua
git commit -m "feat(preview): implement structured metadata header"
```

---

## Phase 5: Core Integration

### Task 8: Update Layout Calculations

**Files:**
- Modify: `lua/luxterm/core.lua`

**Step 1: Update calculate_manager_dimensions to use new config**

Replace `calculate_manager_dimensions`:

```lua
local function calculate_manager_dimensions()
  local cfg = config.get()
  local ui_config = cfg.ui or {}

  local width_ratio = ui_config.width or cfg.manager_width or 0.7
  local height_ratio = ui_config.height or cfg.manager_height or 0.6

  local total_width, total_height = utils.calculate_size_from_ratio(width_ratio, height_ratio)
  local row, col = utils.calculate_centered_position(total_width, total_height)
  return total_width, total_height, row, col
end
```

**Step 2: Update setup_split_layout to use new split ratio**

Replace `setup_split_layout`:

```lua
local function setup_split_layout(total_width, total_height, row, col)
  local session_list = require("luxterm.ui.session_list")
  local cfg = config.get()
  local ui_config = cfg.ui or {}

  local split_ratio = ui_config.split_ratio or 0.35
  local left_width = math.floor(total_width * split_ratio)
  local left_width_ratio = left_width / total_width

  local base_config = {
    width = total_width,
    height = total_height,
    row = row,
    col = col,
    border = "single"
  }

  local left_config = {
    title = " Sessions ",
    width_ratio = left_width_ratio,
    enter = true,
    buffer_options = {filetype = "luxterm_main"},
    auto_hide = get_config("auto_hide"),
    auto_hide_callback = create_auto_hide_callback()
  }

  local right_config = {
    title = " Preview ",
    enter = false,
    buffer_options = {filetype = "luxterm_preview"},
    auto_hide = get_config("auto_hide"),
    auto_hide_callback = create_auto_hide_callback()
  }

  local windows = floating_window.create_split_layout(base_config, left_config, right_config)

  M.manager_layout = {
    type = "split",
    windows = windows
  }

  session_list.window_id = windows.left.winid
  session_list.buffer_id = windows.left.bufnr
  session_list.setup_keymaps()

  preview_pane.create_window(windows.right.winid, windows.right.bufnr)
end
```

**Step 3: Verify new layout renders correctly**

Run: `lux` then toggle manager
Expected: Manager uses new split ratio and single borders

**Step 4: Commit**

```bash
git add lua/luxterm/core.lua
git commit -m "feat(core): integrate new UI configuration options"
```

---

### Task 9: Add Preview Toggle Keymap

**Files:**
- Modify: `lua/luxterm/ui/session_list.lua`
- Modify: `lua/luxterm/core.lua`

**Step 1: Add toggle_preview action handler in session_list**

In `M.setup_keymaps`, add:

```lua
{"n", "p", function() M.emit_action("toggle_preview") end},
```

**Step 2: Add toggle_preview event handler in core**

In `M.setup_event_handlers`, add:

```lua
session_list.on_action("toggle_preview", function()
  M.toggle_preview()
end)
```

**Step 3: Implement toggle_preview function in core**

Add new function:

```lua
function M.toggle_preview()
  if not M.is_manager_open() then
    return
  end

  local cfg = config.get()
  local new_preview_state = not cfg.preview_enabled
  config.update("preview_enabled", new_preview_state)

  M.close_manager()
  M.open_manager()
end
```

**Step 4: Update status bar to show [p]review hint**

In session_list's `add_shortcuts_content`, update shortcuts string:

```lua
shortcuts = "[n]ew  [d]el  [r]ename  [p]review  [1-9] jump  [Esc]"
```

**Step 5: Verify preview toggle works**

Run: `lux` then toggle manager, press `p`
Expected: Preview panel toggles on/off

**Step 6: Commit**

```bash
git add lua/luxterm/ui/session_list.lua lua/luxterm/core.lua
git commit -m "feat: add preview panel toggle with p key"
```

---

## Phase 6: Final Integration & Polish

### Task 10: Update Window Factory for Single Borders

**Files:**
- Modify: `lua/luxterm/ui/floating_window.lua`

**Step 1: Update window_types to use single borders**

Replace border values:

```lua
M.window_types = {
  session_list = {
    relative = "editor",
    border = "single",
    title = " Sessions ",
    title_pos = "center",
    style = "minimal",
    buffer_options = utils.buffer_presets.luxterm_main,
    protected = true,
    hide_cursor = true
  },

  preview = {
    relative = "editor",
    border = "single",
    title = " Preview ",
    title_pos = "center",
    style = "minimal",
    buffer_options = utils.buffer_presets.luxterm_preview,
    hide_cursor = true
  },

  session_terminal = {
    relative = "editor",
    border = "single",
    title_pos = "center",
    style = "minimal",
    zindex = 100,
    enter = true,
    terminal_keymaps = true
  }
}
```

**Step 2: Verify single borders render**

Run: `lux` then toggle manager
Expected: Windows use thin single-line borders

**Step 3: Commit**

```bash
git add lua/luxterm/ui/floating_window.lua
git commit -m "style: use single-line borders for cleaner appearance"
```

---

### Task 11: Final Verification & Cleanup

**Files:**
- All modified files

**Step 1: Run full manual test**

Open LuxVim:
1. `:LuxtermNew` - create first session
2. Toggle manager - verify row-based layout
3. `:LuxtermNew test` - create named session
4. Navigate with j/k - verify selection highlight
5. Press `p` - verify preview toggle
6. Press `1` - verify quick jump
7. Press `r` - verify rename
8. Press `d` - verify delete
9. Press `Esc` - verify close

**Step 2: Verify theme integration**

Run: `lux` then `:colorscheme <different-theme>` then toggle manager
Expected: Colors adapt to new theme

**Step 3: Clean up any debug code**

Search for and remove any `print()` or debug statements.

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete Luxterm UI redesign

- Row-based session items with status icons
- Structured preview header with CWD, process, last command
- Status bar with contextual keyboard hints
- Theme-aware highlights linked to standard Neovim groups
- New UI configuration options (preview mode, split ratio, timeouts)
- Preview panel toggle with p key
- Single-line borders for cleaner appearance
- Persistence-ready session data structure"
```

---

## Summary

| Phase | Tasks | Files |
|-------|-------|-------|
| 1 | Config, Highlights | config.lua, highlights.lua |
| 2 | Session Metadata | session_manager.lua |
| 3 | Session List | session_list.lua |
| 4 | Preview Pane | preview_pane.lua |
| 5 | Core Integration | core.lua, session_list.lua |
| 6 | Polish | floating_window.lua, all |

**Total commits:** 11
**Estimated manual testing:** After each task
