# omarkit

## Goal

Unified nav plugin for omarchy: `envs.conf` drives direction keys across Hyprland, kitty, and nvim. A persistent daemon replaces per-keypress Python spawns (~100ms → ~5ms).

## Architecture

```mermaid
flowchart LR
    envs["envs.conf\n$OMARKIT_LEFT=h"] -->|install| kitty_conf["kitty/omarkit.conf"]
    envs -->|install| hypr_bindings["omarkit-bindings.conf"]

    hypr_bindings -->|exec| mfh["omarchy-movefocus-hypr"]
    mfh -->|"direction pid"| sock["omarchy-nav.sock"]
    mfh -->|fallback| opy["omarchy_kitty.py\n(daemon down)"]

    sock --> daemon["omarchy-nav-daemon\n(persistent)"]
    daemon -->|IS_NVIM?| nvim_key["send-key → nvim"]
    daemon -->|neighbor?| kitty_focus["focus-window"]
    daemon -->|tab?| kitty_tab["focus-tab"]
    daemon -->|else| hyprctl["hyprctl movefocus"]

    nvim["nvim omarkit\nnav()"] -->|"direction\n(at edge)"| sock
```

**Protocol:** fire-and-forget, one line per message
- `"<direction> <kitty-pid>"` — from Hyprland binding (full kitty state machine)
- `"<direction>"` — from nvim edge (hyprctl only, kitty already handled by nvim)

**Fallback:** if daemon socket is missing, `omarchy-movefocus-hypr` falls back to `omarchy_kitty.py` directly.

## Modifier layers

```
$OMARKIT_MOD  = CTRL          # layer 1 — base
$OMARKIT_MOD2 = SHIFT         # layer 2 — move
$OMARKIT_MOD3 = ALT           # layer 3 — resize

MOD              + dir  →  focus window
MOD + MOD2       + dir  →  move window
MOD + MOD3       + dir  →  resize window
```

All three layers share `$OMARKIT_LEFT/DOWN/UP/RIGHT` — one set of direction keys drives every action.

## Tasks

- Config
  - [x] `envs.conf`: `$OMARKIT_LEFT/DOWN/UP/RIGHT/MOD/MOD2/MOD3` as Hyprland config vars
  - [x] `install` upserts envs.conf vars, generates `kitty/omarkit.conf`, symlinks bins, writes `omarkit-bindings.conf`
- Plugin (`omarkit.nvim`)
  - [x] Scaffold matching smart-splits structure
  - [x] IS_NVIM lifecycle: `startup()` / `VimLeavePre`
  - [x] `kitty/omarkit.conf.tmpl` with `kitty_mod` + arrow defaults
  - [x] Kittens: `smart_close.py`, `relative_resize.py`, `omarchy_kitty.py` owned by plugin
  - [x] Replace smart-splits `move_cursor_*` with native `wincmd`
  - [x] Replace smart-splits `resize_*` with `wincmd`
  - [x] nvim edge writes direction to daemon socket via `vim.uv`
- Bin
  - [x] `omarchy-kitty` smart launcher (moved into plugin, install symlinks)
  - [x] `omarchy-movefocus-hypr` (writes to daemon socket, falls back to `omarchy_kitty.py`)
  - [x] `omarchy-nav-daemon` (persistent socket state machine)
- Daemon
  - [x] Socket listener → IS_NVIM → split → tab → hyprctl
  - [x] `exec-once = omarchy-nav-daemon` in `autostart.conf`
  - [x] Single-direction protocol for nvim edge
- Cleanup (omarchy repo)
  - [ ] Remove omarkit bindings from `config/hypr/bindings.conf` (owned by `omarkit-bindings.conf`)
  - [ ] Remove omarkit vars from `config/hypr/envs.conf` (written by install, not committed)
