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

--- Navigate in direction via wincmd; stay put at nvim split edge (Ctrl never leaves nvim).
local function nav(wincmd_dir)
  return function()
    if vim.api.nvim_win_get_config(vim.api.nvim_get_current_win()).relative ~= '' then
      return
    end
    vim.cmd('wincmd ' .. wincmd_dir)
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

--- Normalize a key config value to a flat list of lhs strings.
local function to_list(v)
  if not v then return {} end
  return type(v) == 'table' and v or { v }
end

--- Register all keymaps. Exposed on M so it can be called manually: lua require('omarkit').register_keymaps()
function M.register_keymaps()
  local keys = require('omarkit.config').keys
  local nav_specs = {
    { keys.nav_left,  'h', 'Window left' },
    { keys.nav_down,  'j', 'Window down' },
    { keys.nav_up,    'k', 'Window up' },
    { keys.nav_right, 'l', 'Window right' },
  }

  -- Apply nav keymaps to a buffer (nil = global). Re-applied on BufEnter so
  -- buffer-local keymaps set by plugins (snacks, avante, etc.) don't shadow them.
  local function apply_nav(buf)
    for _, spec in ipairs(nav_specs) do
      local fn = nav(spec[2])
      for _, lhs in ipairs(to_list(spec[1])) do
        vim.keymap.set('n', lhs, fn, { noremap = true, desc = spec[3], buffer = buf })
        if not buf then
          vim.keymap.set('t', lhs, '<C-\\><C-n>' .. lhs, { noremap = true, desc = spec[3] })
        end
      end
    end
  end

  apply_nav(nil)
  vim.api.nvim_create_autocmd('BufEnter', {
    group = vim.api.nvim_create_augroup('omarkit_nav', { clear = true }),
    callback = function(ev) apply_nav(ev.buf) end,
  })

  -- winnr_dir: direction to check for a neighbor before resizing
  -- wincmd:    resize command when neighbor exists
  -- Resizes nvim splits only; stays put at the nvim edge (no neighbor).
  local resize_specs = {
    { keys.resize_left,  'h', '<', 'Resize left' },
    { keys.resize_down,  'j', '+', 'Resize down' },
    { keys.resize_up,    'k', '-', 'Resize up' },
    { keys.resize_right, 'l', '>', 'Resize right' },
  }
  for _, spec in ipairs(resize_specs) do
    local winnr_dir, wincmd, desc = spec[2], spec[3], spec[4]
    for _, lhs in ipairs(to_list(spec[1])) do
      vim.keymap.set('n', lhs, function()
        if vim.fn.winnr(winnr_dir) ~= vim.fn.winnr() then
          vim.cmd('5 wincmd ' .. wincmd)
        end
      end, { noremap = true, desc = desc })
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
