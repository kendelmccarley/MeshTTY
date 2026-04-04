"""CycleSelect — compact single-line option cycler for settings rows."""

from __future__ import annotations

from textual.events import Key
from textual.message import Message
from textual.widget import Widget


class CycleSelect(Widget):
    """Displays the current option as  < Label >  and cycles left/right on arrow keys or click.

    Intended as a 1-line replacement for Textual's Select in compact layouts.
    """

    can_focus = True

    class Changed(Message):
        """Posted whenever the selected value changes."""
        def __init__(self, widget: "CycleSelect", value: str) -> None:
            self.cycle_select = widget
            self.value = value
            super().__init__()

    DEFAULT_CSS = """
    CycleSelect {
        height: 1;
        width: 1fr;
        color: $text;
        padding: 0;
    }
    CycleSelect:focus {
        color: $background;
        background: $primary;
    }
    """

    def __init__(
        self,
        options: list[tuple[str, str]],
        value: str = "",
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._options = options  # [(label, value), ...]
        values = [v for _, v in options]
        self._idx = values.index(value) if value in values else 0

    @property
    def value(self) -> str:
        return self._options[self._idx][1] if self._options else ""

    def render(self) -> str:
        if not self._options:
            return ""
        label = self._options[self._idx][0]
        return f"< {label} >"

    def _cycle(self, delta: int) -> None:
        self._idx = (self._idx + delta) % len(self._options)
        self.refresh()
        self.post_message(self.Changed(self, self.value))

    def on_key(self, event: Key) -> None:
        if event.key == "left":
            self._cycle(-1)
            event.stop()
        elif event.key in ("right", "space", "enter"):
            self._cycle(1)
            event.stop()

    def on_click(self) -> None:
        self._cycle(1)
