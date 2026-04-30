# Omarkit Specification

## Overview

Unified hierarchical navigation and resize system across Neovim, Kitty, and Hyprland using directional keybindings. Both operations share the same layer architecture but perform different actions at each layer.

## Navigation Layers

Navigation proceeds through layers in order until a move succeeds:

### Layer 1: Neovim Splits
**Scope:** Within a single Neovim instance
**Keys:** `ctrl+h/a/e/i`
**Behavior:** Move between vim windows using wincmd

### Layer 2: Kitty Splits
**Scope:** Within a single Kitty OS window
**Keys:** `ctrl+h/a/e/i` (from nvim edge) OR `super+h/a/e/i`
**Behavior:**
- Spatial neighbor detection (geometry-based, 2px tolerance)
- Fallback to window list order if no spatial neighbor

### Layer 3: Hyprland Groups
**Scope:** Within a grouped set of Hyprland windows
**Keys:** `ctrl+h/a/e/i` (continues from Layer 2)
**Behavior:**
- If window is in a group: `changegroupactive`
- Direction mapping: left/up → backward, right/down → forward
- Skipped if window not in group

### Layer 4: Hyprland Windows
**Scope:** Between independent Hyprland windows
**Keys:** `ctrl+h/a/e/i` (final fallback)
**Behavior:** `hyprctl dispatch movefocus`

## Bypass Mode

**Keys:** `ctrl+shift+h/a/e/i`
**Behavior:** Skip Layer 3 (groups), go directly from kitty splits to Hyprland windows

## Direction Mapping

**Cardinal directions:**
- `h` → left
- `a` → down
- `e` → up
- `i` → right

**Group navigation:**
- left/up → previous (backward)
- right/down → next (forward)

## Entry Points

### From Neovim
**Keys:** `ctrl+h/a/e/i`
**Path:** nvim lua → socket message → daemon

### From Kitty (non-nvim)
**Question:** Use `ctrl+h/a/e/i` or `super+h/a/e/i`?
**Path:** kitty binding → daemon OR hyprland binding → daemon

### From Hyprland
**Keys:** `super+h/a/e/i`
**Path:** hyprland binding → script → daemon

## Components

### omarchy-nav-daemon
Persistent daemon listening on Unix socket
Implements all navigation and resize layers
Receives:
- `"{direction} {pid} [--bypass-groups]"` - navigation
- `"resize {direction} {pid}"` - resize from Hyprland
- `"resize_edge {direction} {pid}"` - resize from nvim edge

### omarchy-movefocus-hypr
Entry script from Hyprland bindings
Sends navigation or resize message to daemon socket
Accepts: `--resize` flag

### nvim omarkit plugin
Lua plugin implementing Layer 1 for both navigation and resize
- Navigation: `ctrl+h/a/e/i`
- Resize: `ctrl+alt+h/a/e/i`
Sends edge messages to daemon socket

### kitty omarchy_kitty.py
Fallback when daemon unavailable
Implements Layers 2-4 (simplified, no groups)

## Resize Layers

Resize proceeds through layers in order until a resize succeeds:

### Layer 1: Neovim Splits
**Scope:** Within a single Neovim instance
**Keys:** `ctrl+alt+h/a/e/i`
**Behavior:**
- Check for neighbor in key direction using `winnr()`
- If neighbor exists: execute `wincmd </>/-/+`
- If no neighbor: proceed to Layer 2

**Resize semantics:** "Pressing direction `d` = contracting to the `d` direction"

| Key | Neighbor exists? | Action |
|-----|-----------------|--------|
| h (left) | yes | `wincmd <` - contract left (right border moves left) |
| h (left) | no | → Layer 2 |
| i (right) | yes | `wincmd >` - contract right (right border moves right) |
| i (right) | no | → Layer 2 |
| e (up) | yes | `wincmd -` - contract up (bottom border moves up) |
| e (up) | no | → Layer 2 |
| a (down) | yes | `wincmd +` - contract down (bottom border moves down) |
| a (down) | no | → Layer 2 |

**Limitation:** Nvim's `wincmd` only moves RIGHT/BOTTOM borders. Cannot directly pull LEFT/TOP borders.

### Layer 2: Kitty Splits
**Scope:** Within a single Kitty OS window
**Keys:** `ctrl+alt+h/a/e/i` (from nvim edge) OR `super+alt+h/a/e/i`
**Behavior:**
- Detect neighbor in key direction using geometry (2px tolerance)
- If neighbor exists: `kitten @ resize-window --increment +5` (always grow)
- If no neighbor: proceed to Layer 3

**Key insight:** Always `+5` increment. Kitty's API moves the correct border based on which neighbor exists, contracting towards that direction.

| Key | Neighbor exists? | Action |
|-----|-----------------|--------|
| h (left) | yes (pane to left) | `resize-window --axis horizontal --increment +5` (contract left) |
| h (left) | no (leftmost pane) | → Layer 3 |
| i (right) | yes (pane to right) | `resize-window --axis horizontal --increment +5` (contract right) |
| i (right) | no (rightmost pane) | → Layer 3 |
| e (up) | yes | `resize-window --axis vertical --increment +5` (contract up) |
| e (up) | no | → Layer 3 |
| a (down) | yes | `resize-window --axis vertical --increment +5` (contract down) |
| a (down) | no | → Layer 3 |

### Layer 3: Hyprland Windows
**Scope:** Active Hyprland window
**Keys:** `ctrl+alt+h/a/e/i` (final fallback)
**Behavior:** `hyprctl resizeactive`

**Limitation:** `resizeactive` only controls bottom-right corner. Cannot move left/top borders directly.

| Key | Meaning | Command |
|-----|---------|---------|
| h (left) | contract left (right border moves left) | `resizeactive -50 0` |
| i (right) | contract right (right border moves right) | `resizeactive 50 0` |
| e (up) | contract up (bottom border moves up) | `resizeactive 0 -50` |
| a (down) | contract down (bottom border moves down) | `resizeactive 0 50` |

## Passive Elements

**ctrl+y, ctrl+k:** Currently passthrough in kitty, reserved for future use

## Changes from Current

**Removed:**
- Kitty tab switching (horizontal only, app-specific)

**Added:**
- Hyprland group navigation (all directions, universal)
- Bypass modifier for skipping groups

**Simplified:**
- One navigation model across all apps (via groups)
- Consistent direction handling (all four directions)

## Keybinding Summary

| Operation | Keys | Scope | Layers |
|-----------|------|-------|--------|
| Navigation | `ctrl+h/a/e/i` | nvim → kitty → groups → hyprland | 1-4 |
| Navigation | `super+h/a/e/i` | kitty → groups → hyprland | 2-4 |
| Navigation (bypass) | `ctrl+shift+h/a/e/i` | nvim → kitty → hyprland (skip groups) | 1,2,4 |
| Resize | `ctrl+alt+h/a/e/i` | nvim → kitty → hyprland | 1-3 |
| Resize | `super+alt+h/a/e/i` | kitty → hyprland | 2-3 |

**Direction mapping:**
- `h` = left
- `a` = down
- `e` = up
- `i` = right

**Reserved (passthrough):**
- `ctrl+y` / `ctrl+k` - available for future use

## Open Design Questions

1. Should kitty non-nvim navigation use `ctrl+h/a/e/i` or `super+h/a/e/i`?
2. Should vertical directions (up/down) navigate groups, or only horizontal?
3. What modifier for bypass: shift, alt, or configurable?
