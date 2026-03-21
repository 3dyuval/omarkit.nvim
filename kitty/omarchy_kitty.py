#!/usr/bin/env python3
import json, os, subprocess, sys

HYPR_DIR = {"left": "l", "right": "r", "up": "u", "down": "d"}
KITTY_DIR = {"left": "left", "right": "right", "up": "top", "down": "bottom"}
KITTY_KEY = {"left": "ctrl+h", "right": "ctrl+i", "up": "ctrl+e", "down": "ctrl+a"}

direction = sys.argv[1]
socket = sys.argv[2]  # e.g. unix:@mykitty-257888


def kitty(*args):
    r = subprocess.run(["kitten", "@", "--to", socket, *args], capture_output=True)
    return r.returncode == 0


def hyprland():
    subprocess.run(["hyprctl", "dispatch", "movefocus", HYPR_DIR[direction]],
                   capture_output=True)


result = subprocess.run(["kitten", "@", "--to", socket, "ls"],
                        capture_output=True, text=True)
if result.returncode != 0:
    hyprland(); sys.exit()

state = json.loads(result.stdout)
os_win = next((w for w in state if w.get("is_focused")), None)
if not os_win:
    hyprland(); sys.exit()

tab = next((t for t in os_win["tabs"] if t.get("is_active")), None)
if not tab:
    hyprland(); sys.exit()

win = next((w for w in tab["windows"] if w.get("is_active") and w.get("is_focused")), None)

# IS_NVIM: send-key goes directly to nvim (bypasses kitty bindings) — smart-splits handles it
# OMARCHY_FROM_NVIM=1 skips this to avoid loop when nvim calls back at edge
if win and win.get("user_vars", {}).get("IS_NVIM") and not os.environ.get("OMARCHY_FROM_NVIM"):
    kitty("send-key", KITTY_KEY[direction])
    sys.exit()

# Neighboring kitty split
if kitty("focus-window", "--match", f"neighbor:{KITTY_DIR[direction]}"):
    sys.exit()

# Adjacent tab (horizontal only)
if direction in ("left", "right"):
    tabs = os_win["tabs"]
    active_idx = next((i for i, t in enumerate(tabs) if t.get("is_active")), None)
    if active_idx is not None:
        target_idx = active_idx - 1 if direction == "left" else active_idx + 1
        if 0 <= target_idx < len(tabs):
            kitty("focus-tab", "--match", f"index:{target_idx}")
            sys.exit()

hyprland()
