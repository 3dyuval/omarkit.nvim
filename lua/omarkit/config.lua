---@class OmarkittyConfig
---@field daemon_socket string  Path to omarkit daemon socket
---@field keys OmarkittyKeys

---@class OmarkittyKeys
---@field nav_left string|string[]|false
---@field nav_down string|string[]|false
---@field nav_up string|string[]|false
---@field nav_right string|string[]|false
---@field resize_left string|string[]|false
---@field resize_down string|string[]|false
---@field resize_up string|string[]|false
---@field resize_right string|string[]|false

---@type OmarkittyConfig
local defaults = {
  daemon_socket = (os.getenv('XDG_RUNTIME_DIR') or ('/run/user/' .. vim.fn.getuid())) .. '/omarchy-nav.sock',
  keys = {
    nav_left     = { '<C-h>', '<M-Left>' },
    nav_down     = { '<C-a>', '<M-Down>' },
    nav_up       = { '<C-e>', '<M-Up>' },
    nav_right    = { '<C-i>', '<M-Right>' },
    resize_left  = '<M-C-h>',
    resize_down  = '<M-C-a>',
    resize_up    = '<M-C-e>',
    resize_right = '<M-C-i>',
  },
}

---@type OmarkittyConfig
local M = setmetatable({}, {
  __index = function(_, k) return defaults[k] end,
  __newindex = function(_, k, v) defaults[k] = v end,
})

function M.setup(opts)
  defaults = vim.tbl_deep_extend('force', defaults, opts or {})
end

return M
