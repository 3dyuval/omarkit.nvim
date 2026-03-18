# Based on MIT licensed code at https://github.com/chancez/dotfiles
from kittens.tui.handler import result_handler


def main(args):
    pass


def relative_resize_window(direction, amount, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return

    neighbors = boss.active_tab.current_layout.neighbors_for_window(
        window, boss.active_tab.windows
    )
    left   = neighbors.get('left')
    right  = neighbors.get('right')
    top    = neighbors.get('top')
    bottom = neighbors.get('bottom')

    if direction == 'left':
        boss.active_tab.resize_window('wider' if left and not right else 'narrower', amount)
    elif direction == 'right':
        boss.active_tab.resize_window('narrower' if left and not right else 'wider', amount)
    elif direction == 'up':
        boss.active_tab.resize_window('taller' if top and not bottom else 'shorter', amount)
    elif direction == 'down':
        boss.active_tab.resize_window('shorter' if top and not bottom else 'taller', amount)


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    direction = args[1]
    amount = int(args[2])
    relative_resize_window(direction, amount, target_window_id, boss)
