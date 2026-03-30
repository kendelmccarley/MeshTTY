"""ConnectionStatusBar — single-row status line docked at top of MainScreen."""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Horizontal
from textual.reactive import reactive
from textual.widget import Widget
from textual.widgets import Label


class ConnectionStatusBar(Widget):
    """Shows connection state, channel, node count, and battery in one row."""

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
    #conn-state {
        width: auto;
        padding: 0 1;
        color: $primary;
        text-style: bold;
    }
    #conn-state.connected {
        color: $accent;
    }
    #conn-state.disconnected {
        color: $error;
    }
    #channel-label {
        width: auto;
        padding: 0 1;
        color: $secondary;
    }
    #node-count {
        width: auto;
        padding: 0 1;
        color: $secondary;
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
    channel_name: reactive[str] = reactive("—")
    node_count: reactive[int] = reactive(0)
    battery_level: reactive[int | None] = reactive(None)

    def compose(self) -> ComposeResult:
        with Horizontal():
            yield Label("▮ OFFLINE", id="conn-state")
            yield Label("CH: —", id="channel-label")
            yield Label("NODES: 0", id="node-count")
            yield Label("", id="battery-label")
            yield Label("^Q Quit  ^D Disc  ^T/L/N/S Tabs", id="key-hints")

    # ------------------------------------------------------------------
    # Watchers
    # ------------------------------------------------------------------

    def watch_connection_state(self, state: str) -> None:
        label = self.query_one("#conn-state", Label)
        if state == "connected":
            transport = getattr(self.app, "transport", None)
            transport_str = f" {transport}" if transport else ""
            label.update(f"▶ ONLINE{transport_str}")
            label.add_class("connected")
            label.remove_class("disconnected")
        else:
            label.update("▮ OFFLINE")
            label.remove_class("connected")
            label.add_class("disconnected")

    def watch_channel_name(self, name: str) -> None:
        self.query_one("#channel-label", Label).update(f"CH: {name}")

    def watch_node_count(self, count: int) -> None:
        self.query_one("#node-count", Label).update(f"NODES: {count}")

    def watch_battery_level(self, level: int | None) -> None:
        label = self.query_one("#battery-label", Label)
        label.update(f"BAT: {level}%" if level is not None else "")
