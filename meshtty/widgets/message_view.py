"""MessageView — scrollable message history container."""

from __future__ import annotations

from datetime import datetime

from textual.app import ComposeResult
from textual.scroll_view import ScrollView
from textual.widget import Widget
from textual.widgets import Label


def _format_message(from_id: str, text: str, rx_time: int, is_mine: bool = False) -> str:
    try:
        dt = datetime.fromtimestamp(rx_time).strftime("%H:%M")
    except (OSError, ValueError, OverflowError):
        dt = "--:--"
    prefix = ">> " if is_mine else "   "
    return f"{prefix}[{dt}] {from_id}: {text}"


class MessageView(Widget):
    """Scrollable list of chat messages."""

    DEFAULT_CSS = """
    MessageView {
        height: 1fr;
        overflow-y: auto;
        padding: 0 1;
        background: $surface;
    }
    MessageView .mine {
        color: $accent;
    }
    MessageView .theirs {
        color: $text;
    }
    """

    def compose(self) -> ComposeResult:
        return
        yield  # make it a generator

    def append_message(
        self,
        from_id: str,
        text: str,
        rx_time: int,
        is_mine: bool = False,
    ) -> None:
        formatted = _format_message(from_id, text, rx_time, is_mine)
        css_class = "mine" if is_mine else "theirs"
        label = Label(formatted, classes=css_class)
        self.mount(label)
        self.scroll_end(animate=False)

    def load_messages(self, rows: list) -> None:
        """Bulk-load historical messages (called from worker result)."""
        for row in rows:
            self.append_message(
                from_id=row["from_id"],
                text=row["text"],
                rx_time=row["rx_time"],
                is_mine=bool(row["is_mine"]),
            )
