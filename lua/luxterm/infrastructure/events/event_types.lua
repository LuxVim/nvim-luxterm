local M = {}

M.SESSION_CREATED = "session_created"
M.SESSION_DELETED = "session_deleted"
M.SESSION_SWITCHED = "session_switched"
M.SESSION_RENAMED = "session_renamed"
M.SESSION_CONTENT_CHANGED = "session_content_changed"

M.MANAGER_OPENED = "manager_opened"
M.MANAGER_CLOSED = "manager_closed"
M.MANAGER_FOCUS_CHANGED = "manager_focus_changed"

M.UI_REFRESH_REQUESTED = "ui_refresh_requested"
M.CACHE_INVALIDATE_REQUESTED = "cache_invalidate_requested"

M.TERMINAL_OPENED = "terminal_opened"
M.TERMINAL_CLOSED = "terminal_closed"
M.TERMINAL_CONTENT_UPDATED = "terminal_content_updated"

M.UI_ACTION_NEW_SESSION = "ui_action_new_session"
M.UI_ACTION_DELETE_SESSION = "ui_action_delete_session"
M.UI_ACTION_RENAME_SESSION = "ui_action_rename_session"
M.UI_ACTION_SELECT_SESSION = "ui_action_select_session"
M.UI_ACTION_OPEN_SESSION = "ui_action_open_session"
M.UI_ACTION_CLOSE_MANAGER = "ui_action_close_manager"
M.UI_ACTION_NAVIGATE_UP = "ui_action_navigate_up"
M.UI_ACTION_NAVIGATE_DOWN = "ui_action_navigate_down"

return M