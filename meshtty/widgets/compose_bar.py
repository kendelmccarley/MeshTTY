"""ComposeBar — prefix selector + message input."""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Horizontal
from textual.message import Message
from textual.widget import Widget
from textual.widgets import Button, Input, Static


class PrefixSelector(Static):
    """Focusable channel/node name display. Up/Down cycles; Enter advances to compose."""

    can_focus = True

    class CycleRequest(Message):
        """Posted when the user presses Up or Down to cycle conversations."""
        def __init__(self, delta: int) -> None:
            self.delta = delta
            super().__init__()

    DEFAULT_CSS = """
    PrefixSelector {
        width: 12;
        height: 1;
        background: transparent;
        color: $text-disabled;
        padding: 0 1;
        content-align: left middle;
    }
    PrefixSelector:focus {
        color: $primary;
        text-style: bold;
    }
    """

    def __init__(self, **kwargs) -> None:
        super().__init__("", **kwargs)
        self._prefix = ""

    def set_value(self, prefix: str) -> None:
        self._prefix = prefix
        self.update(prefix[:10].ljust(10))

    # Key handling (up/down/enter) is done in MessagesView.on_key so that
    # events from all focusable widgets are handled in one place reliably.


class ComposeBar(Widget):
    """Prefix selector (12 chars) + message text input, one row tall."""

    class SendRequested(Message):
        """Posted when the user submits a message."""
        def __init__(self, prefix: str, text: str) -> None:
            self.prefix = prefix
            self.text = text
            super().__init__()

    DEFAULT_CSS = """
    ComposeBar {
        dock: bottom;
        height: 1;
        background: transparent;
        padding: 0 1;
    }
    ComposeBar Horizontal {
        height: 1;
        align: left middle;
        background: transparent;
    }
    ComposeBar Input {
        width: 1fr;
        height: 1;
        background: transparent;
        color: $primary;
        border: none;
        padding: 0;
    }
    ComposeBar Button {
        width: 8;
        height: 1;
        min-height: 1;
        margin: 0 0 0 1;
        background: transparent;
        border: none;
        color: $accent;
        text-style: bold;
    }
    """

    def compose(self) -> ComposeResult:
        with Horizontal():
            yield PrefixSelector(id="prefix-selector")
            yield Input(placeholder="type a message…", id="compose-input")
            yield Button("SEND", id="send-btn", variant="primary")

    def on_mount(self) -> None:
        self.query_one("#compose-input", Input).focus()

    def set_prefix(self, prefix: str) -> None:
        try:
            self.query_one("#prefix-selector", PrefixSelector).set_value(prefix)
        except Exception:
            pass

    def on_input_submitted(self, event: Input.Submitted) -> None:
        self._do_send()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "send-btn":
            event.stop()
            self._do_send()

    def _do_send(self) -> None:
        inp = self.query_one("#compose-input", Input)
        text = inp.value.strip()
        if not text:
            inp.focus()
            return
        try:
            prefix = self.query_one("#prefix-selector", PrefixSelector)._prefix
        except Exception:
            prefix = ""
        self.post_message(self.SendRequested(prefix=prefix, text=text))
        inp.value = ""
        inp.focus()
