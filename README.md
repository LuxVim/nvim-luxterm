<h1 align="left">
  <img src="https://github.com/user-attachments/assets/546ee0e5-30fd-4e37-b219-e390be8b1c6e"
       alt="LuxVim Logo"
       style="width: 40px; height: 40px; position: relative; top: 6px; margin-right: 10px;" />
  nvim-luxterm
</h1>

A floating-window terminal session manager, offering elegant multi-terminal organization, live previews, and intuitive navigation with modern UI design. Manage, switch, and customize multiple terminals effortlessly.

---

## ✨ Features

- **Terminal Session Management**
  - Create, delete, rename, and switch between multiple terminal sessions
  - Automatic cleanup of invalid sessions during Neovim session
  - Quick session switching and organization
  - Session navigation with next/previous cycling functionality

- **Modern Floating UI**
  - Floating window manager with split-pane layout
  - Live preview pane showing terminal content with intelligent truncation
  - Session list with intuitive navigation and keyboard shortcuts
  - Customizable window dimensions and border styles

- **Intuitive Keybindings**
  - Global toggle accessible from any mode (normal/terminal)
  - Quick actions for create, delete, rename operations
  - Vim-style navigation within the session manager
  - Direct session navigation with customizable keybindings

- **Compatibility**
  - Neovim 0.8.0+ required
  - Cross-platform support (Linux, macOS, Windows)
  - No external dependencies

---

## 📦 Installation

### **using lazy.nvim**
```lua
{
  "luxvim/nvim-luxterm",
  config = function()
    require("luxterm").setup({
      -- Optional configuration
      manager_width = 0.8,
      manager_height = 0.8,
      preview_enabled = true,
      auto_hide = true,
      keymaps = {
        toggle_manager = "<C-/>",
      }
    })
  end
}
```

### **using packer.nvim**
```lua
use {
  "luxvim/nvim-luxterm",
  config = function()
    require("luxterm").setup()
  end
}
```

### **Using vim-plug**
```vim
Plug 'luxvim/nvim-luxterm'
```

Then in your `init.lua`:
```lua
require("luxterm").setup({
  -- Your configuration here
})
```

---

## 🛠️ Configuration

```lua
require("luxterm").setup({
  -- Manager window dimensions (0.1 to 1.0)
  manager_width = 0.8,          -- 80% of screen width
  manager_height = 0.8,         -- 80% of screen height
  
  -- Enable live preview pane
  preview_enabled = true,
  
  -- Focus new sessions when created via :LuxtermNew
  focus_on_create = false,
  
  -- Auto-hide floating windows when cursor leaves
  auto_hide = true,
  
  -- Keybinding configuration
  keymaps = {
    toggle_manager = "<C-/>",     -- Toggle session manager
    next_session = "<C-k>",       -- Next session keybinding
    prev_session = "<C-j>",       -- Previous session keybinding
    global_session_nav = false,   -- Enable global session navigation
  }
})
```

---

## 🎮 Commands

| Command | Description | Example |
|---------|-------------|---------|
| `:LuxtermToggle` | Toggle the session manager UI | `:LuxtermToggle` |
| `:LuxtermNew [name]` | Create new terminal session | `:LuxtermNew` or `:LuxtermNew work` |
| `:LuxtermNext` | Switch to next terminal session | `:LuxtermNext` |
| `:LuxtermPrev` | Switch to previous terminal session | `:LuxtermPrev` |
| `:LuxtermKill [pattern]` | Delete session(s) by pattern | `:LuxtermKill` or `:LuxtermKill work` |
| `:LuxtermList` | List all active sessions | `:LuxtermList` |
| `:LuxtermStats` | Show performance statistics | `:LuxtermStats` |

### Session Manager Keybindings

When the session manager is open:

| Key | Action |
|-----|--------|
| `<Enter>` | Open selected session |
| `n` | Create new session |
| `d` | Delete selected session |
| `r` | Rename selected session |
| `j/k` or `↓/↑` | Navigate session list |
| `1-9` | Quick select session by number |
| `q` or `<Esc>` | Close manager |

---

## 🔧 Lua API

```lua
local luxterm = require("luxterm")

-- Create and manage sessions
local session = luxterm.create_session({ name = "work", activate = true })
luxterm.delete_session(session.id)
luxterm.switch_session(session.id)

-- Session navigation
-- Use :LuxtermNext and :LuxtermPrev commands

-- Manager control
luxterm.toggle_manager()
local is_open = luxterm.is_manager_open()

-- Information retrieval
local sessions = luxterm.get_sessions()
local active = luxterm.get_active_session()
local stats = luxterm.get_stats()
local config = luxterm.get_config()
```

### Session Object Methods

```lua
-- Session validation and status
session:is_valid()           -- Returns true if session buffer is valid
session:get_status()         -- Returns "running" or "stopped"
session:activate()           -- Make this session the active one

-- Content preview
local preview = session:get_content_preview()  -- Returns array of preview lines
```

---

## 🎨 Customization Examples

### Minimal Configuration
```lua
require("luxterm").setup({
  preview_enabled = false,      -- Disable preview pane
  manager_width = 0.6,         -- Smaller window
  auto_hide = false,           -- Keep windows open
  keymaps = {
    toggle_manager = "<C-t>",   -- Use Ctrl+T instead
  }
})
```

### Session Navigation
nvim-luxterm provides powerful session navigation features that work in both normal and terminal modes:

```lua
require("luxterm").setup({
  keymaps = {
    next_session = "<C-k>",         -- Next session
    prev_session = "<C-j>",         -- Previous session
    global_session_nav = true,      -- Enable global navigation (works everywhere)
  }
})
```

When `global_session_nav` is enabled, you can cycle through terminal sessions from anywhere in Neovim. The navigation automatically opens the selected session in a floating window and closes any previously opened session windows.

### Custom Keybindings
```lua
-- Additional custom keybindings after setup
vim.keymap.set("n", "<leader>tn", ":LuxtermNew<CR>", { desc = "New terminal" })
vim.keymap.set("n", "<leader>tl", ":LuxtermList<CR>", { desc = "List terminals" })
vim.keymap.set("n", "<leader>tk", ":LuxtermKill<CR>", { desc = "Kill terminal" })
vim.keymap.set("n", "<leader>tj", ":LuxtermNext<CR>", { desc = "Next terminal session" })
vim.keymap.set("n", "<leader>th", ":LuxtermPrev<CR>", { desc = "Previous terminal session" })
```

---

## 🐛 Troubleshooting

### Common Issues

**Session manager doesn't open**
- Ensure Neovim version is 0.8.0 or higher
- Check for conflicting keybindings with `:verbose map <C-/>`
- Verify plugin was properly loaded with `:LuxtermStats`

**Terminal sessions appear empty**
- Sessions auto-cleanup when terminal buffers are deleted
- Use `:LuxtermStats` to check session count and creation stats
- Ensure shell is properly configured (`echo $SHELL`)

**Performance issues**
- Disable preview pane if experiencing lag: `preview_enabled = false`
- Check stats with `:LuxtermStats` to monitor resource usage
- Large terminal histories may affect preview rendering

### Debug Information

```lua
-- Check plugin status
:LuxtermStats

-- List all sessions
:LuxtermList

-- Verify configuration
:lua print(vim.inspect(require("luxterm").get_config()))
```

---

## 🙏 Acknowledgments

nvim-luxterm is part of the [LuxVim](https://github.com/luxvim/LuxVim) ecosystem - a high-performance Neovim distribution focused on modern UI design and developer productivity.

---

## 📄 License

MIT License – see [LICENSE](LICENSE) for details.
