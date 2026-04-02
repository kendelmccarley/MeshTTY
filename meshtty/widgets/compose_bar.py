"""ComposeBar — prefix selector + message input."""

from __future__ import annotations

from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal
from textual.message import Message
from textual.widget import Widget
from textual.widgets import Button, Input


class PrefixSelector(Input):
    """Editable channel/node name field. Up/Down cycles; Enter/Tab advances to compose."""

    # priority=True ensures these fire before Screen-level Tab/Enter bindings.
    BINDINGS = [
        Binding("tab", "focus_compose", show=False, priority=True),
        Binding("enter", "focus_compose", show=False, priority=True),
        Binding("shift+tab", "focus_view", show=False, priority=True),
    ]

    DEFAULT_CSS = """
    PrefixSelector {
        width: 12;
        height: 1;
        min-height: 1;
        background: transparent;
        color: $text-disabled;
        padding: 0 1;
        border: none;
    }
    PrefixSelector:focus {
        color: $primary;
        border: none;
        text-style: bold;
    }
    """

    def __init__(self, **kwargs) -> None:
        super().__init__(placeholder="dest", **kwargs)

    def set_value(self, prefix: str) -> None:
        self.value = prefix

    def action_focus_compose(self) -> None:
        try:
            self.app.query_one("#compose-input").focus()
        except Exception:
            pass

    def action_focus_view(self) -> None:
        try:
            self.app.query_one("#message-view").focus()
        except Exception:
            pass


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
        if event.input.id == "prefix-selector":
            event.stop()
            try:
                self.query_one("#compose-input", Input).focus()
            except Exception:
                pass
        elif event.input.id == "compose-input":
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
            prefix = self.query_one("#prefix-selector", PrefixSelector).value
        except Exception:
            prefix = ""
        self.post_message(self.SendRequested(prefix=prefix, text=text))
        inp.value = ""
        inp.focus()
