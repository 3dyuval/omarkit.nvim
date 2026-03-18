-- Auto-sourced on load: announce IS_NVIM to kitty and wire lifecycle autocmds
local ok, omarkit = pcall(require, 'omarkit')
if not ok then return end

omarkit.startup()
