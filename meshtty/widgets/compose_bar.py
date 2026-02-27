"""ComposeBar — message input + send button."""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Horizontal
from textual.message import Message
from textual.widget import Widget
from textual.widgets import Button, Input


class ComposeBar(Widget):
    """Text input area with a Send button."""

    class SendRequested(Message, bubble=False):
        """Posted when the user submits a message."""

        def __init__(self, text: str) -> None:
            self.text = text
            super().__init__()

    DEFAULT_CSS = """
    ComposeBar {
        dock: bottom;
        height: 3;
        background: $surface;
        border-top: solid $primary;
    }
    ComposeBar Horizontal {
        height: 3;
        align: left middle;
    }
    ComposeBar Input {
        width: 1fr;
        height: 3;
    }
    ComposeBar Button {
        width: 10;
        min-height: 3;
        margin: 0 0 0 1;
    }
    """

    def compose(self) -> ComposeResult:
        with Horizontal():
            yield Input(placeholder="Type a message… (Enter to send)", id="compose-input")
            yield Button("Send", id="send-btn", variant="primary")

    def on_mount(self) -> None:
        self.query_one("#compose-input", Input).focus()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        self._do_send()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "send-btn":
            event.stop()
            self._do_send()

    def _do_send(self) -> None:
        inp = self.query_one("#compose-input", Input)
        text = inp.value.strip()
        if text:
            self.post_message(self.SendRequested(text))
            inp.value = ""
        inp.focus()
