import glob as _glob
import os
import signal
import subprocess

from kitty.options.utils import parse_key_action


def main(args):
    pass


SHELLS = {'zsh', 'bash', 'fish', 'sh', 'dash'}
IMMEDIATE_CLOSE = {'nvim', 'vim', 'vi', 'yazi'}

_BUSY_DIR = os.path.join(
    os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}'),
    'claude-busy'
)


def _claude_is_busy():
    if not os.path.isdir(_BUSY_DIR):
        return False
    for pid_file in _glob.glob(os.path.join(_BUSY_DIR, '*')):
        try:
            pid = int(os.path.basename(pid_file))
            os.kill(pid, 0)  # raises OSError if process is dead
            return True
        except ValueError:
            # Non-PID filename — stale file with wid/sock metadata
            try:
                with open(pid_file) as fh:
                    lines = fh.read().splitlines()
                wid = lines[0] if lines else ''
                sock = lines[1] if len(lines) > 1 else ''
                if wid and sock:
                    subprocess.Popen(
                        ['kitty', '@', '--to', sock, 'set-tab-color',
                         '--match', f'id:{wid}',
                         'active_bg=NONE', 'active_fg=NONE',
                         'inactive_bg=NONE'],
                        stderr=subprocess.DEVNULL,
                    )
                os.unlink(pid_file)
            except OSError:
                pass
        except OSError:
            # Process is dead — clean up stale PID file
            try:
                os.unlink(pid_file)
            except OSError:
                pass
    return False


def _foreground_non_shell(window):
    """Return list of non-shell foreground process names."""
    if window is None:
        return []
    fp = window.child.foreground_processes
    if not fp:
        return []
    return [
        p['cmdline'][0].rsplit('/', 1)[-1]
        for p in fp
        if p['cmdline'] and p['cmdline'][0].rsplit('/', 1)[-1] not in SHELLS
    ]


def _is_ai_agent_window(window):
    """Check if window is running an AI agent (set via kitten @ set-user-vars AI_AGENT=...)."""
    if window is None:
        return False
    return bool(getattr(window, 'user_vars', {}).get('AI_AGENT'))


def _needs_confirm(window, claude_busy):
    """Return True only if a process requires confirmation before closing."""
    if _is_ai_agent_window(window):
        return claude_busy
    procs = _foreground_non_shell(window)
    if not procs:
        return False
    if claude_busy:
        return True
    return not all(p in IMMEDIATE_CLOSE for p in procs)


def _sigterm_processes(window):
    """Send SIGTERM to foreground processes in a window."""
    if window is None:
        return
    fp = window.child.foreground_processes
    if not fp:
        return
    for p in fp:
        if p['cmdline'] and p['cmdline'][0].rsplit('/', 1)[-1] not in SHELLS:
            try:
                os.kill(p['pid'], signal.SIGTERM)
            except OSError:
                pass


def _sigterm_all_windows(boss):
    """Send SIGTERM to foreground processes in all windows across all tabs."""
    tm = boss.active_tab_manager
    if tm is None:
        return
    for tab in tm.tabs:
        for window in tab.windows:
            _sigterm_processes(window)


def _close_or_confirm(boss, action, message, window):
    """Close immediately if idle or IMMEDIATE_CLOSE process; confirm otherwise."""
    busy = _claude_is_busy()
    if _needs_confirm(window, busy):
        if busy:
            message = f'Claude is busy! {message}'
        def on_confirm(confirmed, b=boss, a=action, w=window):
            if confirmed:
                _sigterm_processes(w)
                b.dispatch_action(parse_key_action(a))
        boss.confirm(message, on_confirm, window=window)
    else:
        _sigterm_processes(window)
        boss.dispatch_action(parse_key_action(action))


def handle_result(args, answer, target_window_id, boss):
    close_all = '--all' in args[1:]

    if close_all:
        def on_confirm(confirmed, b=boss):
            if confirmed:
                _sigterm_all_windows(b)
                b.dispatch_action(parse_key_action('close_os_window'))
        boss.confirm('Close entire kitty window?', on_confirm, window=boss.active_window)
        return

    tm = boss.active_tab_manager
    if tm is None:
        return

    tab = tm.active_tab
    if tab is not None and len(tab.windows) > 1:
        _close_or_confirm(boss, 'close_window', 'Process running, close pane?', boss.active_window)
    elif len(tm.tabs) > 1:
        _close_or_confirm(boss, 'close_tab', 'Process running, close tab?', boss.active_window)
    else:
        _close_or_confirm(boss, 'close_os_window', 'Process running, close kitty?', boss.active_window)


handle_result.no_ui = True
