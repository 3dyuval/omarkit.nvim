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

--- Kitty OS-window PID from $KITTY_LISTEN_ON (e.g. "unix:@mykitty-12345"), or nil.
local KITTY_PID = (os.getenv('KITTY_LISTEN_ON') or ''):match('%-(%d+)$')

--- Send a message to the daemon socket (async, fire-and-forget).
local function dispatch_msg(msg, hypr_fallback_args)
  local pipe = vim.uv.new_pipe(false)
  pipe:connect(SOCK_PATH, function(err)
    if err then
      vim.fn.jobstart(hypr_fallback_args)
    else
      pipe:write(msg .. '\n', function() pipe:close() end)
    end
  end)
end

--- Write direction to daemon socket (async, fire-and-forget).
--- Sends "direction pid" so daemon runs full dispatch() including kitty layer.
--- Falls back to hyprctl if socket is unavailable.
local function dispatch_edge(direction)
  local msg = KITTY_PID and ('edge ' .. direction .. ' ' .. KITTY_PID) or direction
  dispatch_msg(msg, { 'hyprctl', 'dispatch', 'movefocus', direction })
end

local function dispatch_resize_edge(direction)
  local msg = KITTY_PID and ('resize_edge ' .. direction .. ' ' .. KITTY_PID) or ('resize ' .. direction)
  dispatch_msg(msg, { 'hyprctl', 'dispatch', 'resizeactive',
    direction == 'left' and '-50' or direction == 'right' and '50' or '0',
    direction == 'up'   and '-50' or direction == 'down'  and '50' or '0' })
end

--- Navigate in direction via wincmd; dispatch to daemon at nvim split edge.
local function nav(wincmd_dir, hypr_dir)
  return function()
    local win = vim.api.nvim_get_current_win()
    local config = vim.api.nvim_win_get_config(win)
    if config.relative ~= '' then
      dispatch_edge(hypr_dir)
      return
    end
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

--- Register all keymaps. Exposed on M so it can be called manually: lua require('omarkit').register_keymaps()
function M.register_keymaps()
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
      vim.keymap.set('t', lhs, '<C-\\><C-n>' .. lhs, { noremap = true, desc = spec[3] })
    end
  end

  -- winnr_dir: direction to check for a neighbor before resizing
  -- wincmd:    resize command when neighbor exists
  -- hypr_dir:  direction sent to daemon when at nvim edge
  local resize_map = {
    [keys.resize_left]  = { 'h', '<', 'left',  'Resize left' },
    [keys.resize_down]  = { 'j', '+', 'down',  'Resize down' },
    [keys.resize_up]    = { 'k', '-', 'up',    'Resize up' },
    [keys.resize_right] = { 'l', '>', 'right', 'Resize right' },
  }
  for lhs, spec in pairs(resize_map) do
    if lhs then
      vim.keymap.set('n', lhs, function()
        if vim.fn.winnr(spec[1]) == vim.fn.winnr() then
          dispatch_resize_edge(spec[3])
        else
          vim.cmd('5 wincmd ' .. spec[2])
        end
      end, { noremap = true, desc = spec[4] })
    end
  end
end

--- Called by the user's lazy.nvim spec opts/config to set keys and options.
function M.setup(opts)
  require('omarkit.config').setup(opts)

  -- Defer keymap registration to VeryLazy so we run after LazyVim's default keymaps.
  vim.api.nvim_create_autocmd('User', {
    pattern = 'VeryLazy',
    once = true,
    callback = M.register_keymaps,
  })
end

return M
