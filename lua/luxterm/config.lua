-- Configuration management module
local utils = require("luxterm.utils")

local M = {}

-- Default configuration
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

-- Configuration schema for validation
M.schema = {
  manager_width = "number",
  manager_height = "number",
  preview_enabled = "boolean",
  focus_on_create = "boolean",
  auto_hide = "boolean",
  keymaps = "table",
  ui = "table"
}

-- Current configuration
M.current = {}

function M.validate(config)
  return utils.validate_config(config, M.schema)
end

function M.merge(user_config)
  return utils.merge_config(M.defaults, user_config)
end

function M.setup(user_config)
  local merged = M.merge(user_config)
  
  local valid, error_msg = M.validate(merged)
  if not valid then
    vim.notify("Luxterm config validation failed: " .. error_msg, vim.log.levels.ERROR)
    M.current = M.defaults
    return M.current
  end
  
  M.current = merged
  return M.current
end

function M.get(key)
  if key then
    return M.current[key]
  end
  return M.current
end

function M.update(key, value)
  if M.current[key] ~= nil then
    M.current[key] = value
    return true
  end
  return false
end

-- Configuration presets
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

function M.apply_preset(preset_name)
  local preset = M.presets[preset_name]
  if preset then
    M.current = M.merge(preset)
    return true
  end
  return false
end

return M