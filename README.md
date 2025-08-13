# nvim-luxterm

A Neovim plugin for a floating-window terminal multiplexer.

## Overview
nvim-luxterm allows you to:
- Manage multiple terminal sessions with ease
- View sessions in a floating window with live preview
- Switch between sessions using intuitive keymaps
- Multiplexing capabilities similar to tmux but integrated into Neovim

---

## Features to Implement
See `TASKS.md` for detailed implementation tickets.

## Architecture
```
lua/
  luxterm/
    init.lua          -- Entry point; setup, commands
    config.lua        -- User config and defaults
    state.lua         -- Central state
    sessions.lua      -- Session creation, deletion, switching
    ui.lua            -- Floating window and rendering
    keymaps.lua       -- Keymaps for manager and terminal
    cache.lua         -- Cache handling
    utils.lua         -- Utility functions
```

## Getting Started
1. Place this plugin folder in your Neovim `runtimepath` or package manager directory.
2. Require and set it up in your `init.lua`:
```lua
require("luxterm").setup({})
```
3. Use `:LuxtermToggle` to open/close the manager.

## Notes
- The code is structured to be modular and performant.
- All blocking calls should be avoided to ensure smooth performance on low-end machines.
