"""Toggle Kitty's OS window decorations without changing window size/state."""

from kitty.fast_data_types import get_options
from kittens.tui.handler import result_handler


def main(args: list[str]) -> str:
    return ""


@result_handler(no_ui=True)
def handle_result(args: list[str], answer: str, target_window_id: int, boss) -> None:
    hidden = bool(get_options().hide_window_decorations & 1)
    value = "no" if hidden else "yes"
    boss.load_config_file(
        apply_overrides=False,
        overrides=(f"hide_window_decorations {value}",),
    )
