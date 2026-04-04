"""ConnectionStatusBar — single-row status line docked at top of MainScreen."""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Horizontal
from textual.reactive import reactive
from textual.widget import Widget
from textual.widgets import Label


class ConnectionStatusBar(Widget):
    """Shows current page name, connection state, and key hints in one row."""

    DEFAULT_CSS = """
    ConnectionStatusBar {
        dock: top;
        height: 1;
        background: transparent;
        padding: 0 2;
        layer: content;
    }
    ConnectionStatusBar Horizontal {
        height: 1;
        align: left middle;
        background: transparent;
    }
    #page-name {
        width: auto;
        padding: 0 1;
        color: $accent;
        text-style: bold;
    }
    #conn-state {
        width: auto;
        padding: 0 1;
        color: $primary;
        text-style: bold;
    }
    #conn-state.connected {
        color: $primary;
    }
    #conn-state.disconnected {
        color: $error;
    }
    #battery-label {
        width: auto;
        padding: 0 1;
        color: $secondary;
    }
    #key-hints {
        dock: right;
        width: auto;
        padding: 0 2;
        color: $secondary;
    }
    """

    connection_state: reactive[str] = reactive("disconnected")
    battery_level: reactive[int | None] = reactive(None)
    page_name: reactive[str] = reactive("MESSAGES")

    def compose(self) -> ComposeResult:
        with Horizontal():
            yield Label("MESSAGES", id="page-name")
            yield Label("▮ OFFLINE", id="conn-state")
            yield Label("", id="battery-label")
            yield Label("^Q Quit  ^D Disc  ^T Next", id="key-hints")

    # ------------------------------------------------------------------
    # Watchers
    # ------------------------------------------------------------------

    def watch_page_name(self, name: str) -> None:
        self.query_one("#page-name", Label).update(name)

    def watch_connection_state(self, state: str) -> None:
        label = self.query_one("#conn-state", Label)
        if state == "connected":
            transport = getattr(self.app, "transport", None)
            transport_str = f" {transport.transport_type.upper()}" if transport else ""
            label.update(f"▶ ONLINE{transport_str}")
            label.add_class("connected")
            label.remove_class("disconnected")
        else:
            label.update("▮ OFFLINE")
            label.remove_class("connected")
            label.add_class("disconnected")

    def watch_battery_level(self, level: int | None) -> None:
        label = self.query_one("#battery-label", Label)
        label.update(f"BAT: {level}%" if level is not None else "")
