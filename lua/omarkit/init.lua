local M = {}

-- IS_NVIM OSC sequences (iTerm2 SetUserVar protocol, read by kitty user_vars)
local IS_NVIM_SET   = '\x1b]1337;SetUserVar=IS_NVIM=MQo\007'
local IS_NVIM_UNSET = '\x1b]1337;SetUserVar=IS_NVIM\007'

local function are_we_kitty()
  return vim.env.KITTY_WINDOW_ID ~= nil
end

--- Write IS_NVIM OSC to stdout so kitty registers the user var.
local function set_is_nvim(value)
  if not are_we_kitty() then return end
  io.write(value and IS_NVIM_SET or IS_NVIM_UNSET)
  io.flush()
end

local SOCK_PATH = (os.getenv('XDG_RUNTIME_DIR') or ('/run/user/' .. vim.fn.getuid())) .. '/omarchy-nav.sock'

--- Write direction to daemon socket (async, fire-and-forget).
--- Falls back to hyprctl if socket is unavailable.
local function dispatch_edge(direction)
  local pipe = vim.uv.new_pipe(false)
  pipe:connect(SOCK_PATH, function(err)
    if err then
      vim.fn.jobstart({ 'hyprctl', 'dispatch', 'movefocus', direction })
    else
      pipe:write(direction .. '\n', function() pipe:close() end)
    end
  end)
end

--- Navigate in direction via wincmd; dispatch to daemon at nvim split edge.
local function nav(wincmd_dir, hypr_dir)
  return function()
    local win = vim.api.nvim_get_current_win()
    vim.cmd('wincmd ' .. wincmd_dir)
    if vim.api.nvim_get_current_win() == win then
      dispatch_edge(hypr_dir)
    end
  end
end

--- Called automatically from plugin/omarkit.lua on load.
function M.startup()
  set_is_nvim(true)

  local group = vim.api.nvim_create_augroup('omarkit', { clear = true })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function() set_is_nvim(false) end,
  })
end

--- Called by the user's lazy.nvim spec opts/config to set keys and options.
function M.setup(opts)
  require('omarkit.config').setup(opts)

  local keys = require('omarkit.config').keys
  local nav_map = {
    [keys.nav_left]  = { 'h', 'left',  'Window left' },
    [keys.nav_down]  = { 'j', 'down',  'Window down' },
    [keys.nav_up]    = { 'k', 'up',    'Window up' },
    [keys.nav_right] = { 'l', 'right', 'Window right' },
  }
  for lhs, spec in pairs(nav_map) do
    if lhs then
      vim.keymap.set('n', lhs, nav(spec[1], spec[2]), { noremap = true, desc = spec[3] })
    end
  end

  local resize_map = {
    [keys.resize_left]  = { '5 wincmd <', 'Shrink window width' },
    [keys.resize_down]  = { '5 wincmd +', 'Grow window height' },
    [keys.resize_up]    = { '5 wincmd -', 'Shrink window height' },
    [keys.resize_right] = { '5 wincmd >', 'Grow window width' },
  }
  for lhs, spec in pairs(resize_map) do
    if lhs then
      vim.keymap.set('n', lhs, function() vim.cmd(spec[1]) end, { noremap = true, desc = spec[2] })
    end
  end
end

return M
