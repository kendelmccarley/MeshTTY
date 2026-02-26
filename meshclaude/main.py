"""MeshClaude — Meshtastic TUI client for Raspberry Pi.

Entry point: python -m meshclaude.main
"""

from __future__ import annotations

import logging
import sys

from textual.app import App, ComposeResult
from textual.widgets import Label

from meshclaude.bridge.event_bridge import EventBridge
from meshclaude.config.settings import AppConfig, load_config
from meshclaude.db.database import Database
from meshclaude.messages.app_messages import (
    ConnectionEstablished,
    ConnectionLost,
    NodeUpdated,
    TextMessageReceived,
)
from meshclaude.screens.connection import ConnectionScreen
from meshclaude.screens.main_screen import MainScreen
from meshclaude.transport.base import TransportManager


def _setup_logging(level: str) -> None:
    logging.basicConfig(
        level=getattr(logging, level.upper(), logging.WARNING),
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
        handlers=[logging.FileHandler("/tmp/meshclaude.log")],
    )


class MeshClaudeApp(App):
    """The root Textual application."""

    CSS_PATH = "../assets/meshclaude.tcss"

    TITLE = "MeshClaude"
    SUB_TITLE = "Meshtastic for Raspberry Pi"

    SCREENS = {
        "connection": ConnectionScreen,
        "main": MainScreen,
    }

    # App-level state — accessible from all screens via self.app.*
    transport: TransportManager | None = None
    config: AppConfig = None  # type: ignore[assignment]
    db: Database = None       # type: ignore[assignment]
    bridge: EventBridge = None  # type: ignore[assignment]

    def on_mount(self) -> None:
        self.config = load_config()
        _setup_logging(self.config.log_level)
        self.db = Database(self.config.db_path)
        self.bridge = EventBridge(self)

        if self.config.auto_connect and self._has_saved_transport():
            # Try to auto-connect using saved settings, then go straight to main
            self.push_screen("connection")
        else:
            self.push_screen("connection")

    def _has_saved_transport(self) -> bool:
        cfg = self.config
        return bool(
            (cfg.default_transport == "serial" and cfg.last_serial_port)
            or (cfg.default_transport == "tcp" and cfg.last_tcp_host)
            or (cfg.default_transport == "ble" and cfg.last_ble_address)
        )

    # ------------------------------------------------------------------
    # App-level message handlers — bubble up from any screen/widget
    # ------------------------------------------------------------------

    def on_connection_established(self, event: ConnectionEstablished) -> None:
        logging.getLogger(__name__).info(
            "Connection established via %s", self.transport
        )

    def on_connection_lost(self, event: ConnectionLost) -> None:
        logging.getLogger(__name__).warning("Connection lost: %s", event.reason)
        if self.transport:
            try:
                self.transport.disconnect()
            except Exception:
                pass
            self.transport = None

    def on_text_message_received(self, event: TextMessageReceived) -> None:
        # Bubble down into the active screen
        if self.screen:
            self.screen.post_message(event)

    def on_node_updated(self, event: NodeUpdated) -> None:
        if self.screen:
            self.screen.post_message(event)

    # ------------------------------------------------------------------
    # Actions
    # ------------------------------------------------------------------

    def action_disconnect(self) -> None:
        self.bridge.unsubscribe()
        if self.transport:
            try:
                self.transport.disconnect()
            except Exception:
                pass
            self.transport = None
        self.post_message(ConnectionLost("Disconnected by user"))
        # Return to connection screen
        self.switch_screen("connection")

    def on_unmount(self) -> None:
        if self.bridge:
            self.bridge.unsubscribe()
        if self.transport:
            try:
                self.transport.disconnect()
            except Exception:
                pass
        if self.db:
            self.db.close()


def main() -> None:
    app = MeshClaudeApp()
    app.run()


if __name__ == "__main__":
    main()
