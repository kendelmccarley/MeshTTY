"""MeshTTY — Meshtastic TUI client for Raspberry Pi.

Entry point: python -m meshtty.main
"""

from __future__ import annotations

import argparse
import logging
import sys

from textual.app import App, ComposeResult
from textual.widgets import Label

from meshtty.bridge.event_bridge import EventBridge
from meshtty.config.settings import AppConfig, load_config
from meshtty.themes import ALL_THEMES
from meshtty.db.database import Database
from meshtty.messages.app_messages import (
    ConnectionEstablished,
    ConnectionLost,
    NodeUpdated,
    TextMessageReceived,
)
from meshtty.screens.connection import ConnectionScreen
from meshtty.screens.main_screen import MainScreen
from meshtty.transport.base import TransportManager


LOG_FILE = "/tmp/meshtty.log"


def _setup_logging(level: str, debug: bool = False) -> None:
    effective_level = logging.DEBUG if debug else getattr(logging, level.upper(), logging.WARNING)
    # Configure the root logger so the meshtastic library's own loggers are captured too.
    root = logging.getLogger()
    root.setLevel(effective_level)
    handler = logging.FileHandler(LOG_FILE)
    handler.setFormatter(logging.Formatter("%(asctime)s %(name)s %(levelname)s %(message)s"))
    root.addHandler(handler)


class MeshTTYApp(App):
    """The root Textual application."""

    CSS_PATH = "../assets/meshtty.tcss"

    TITLE = "MeshTTY"
    SUB_TITLE = "Meshtastic for Raspberry Pi"

    SCREENS = {
        "connection": ConnectionScreen,
        "main": MainScreen,
    }

    # App-level state — accessible from all screens via self.app.*
    _debug: bool = False  # set by main() before run()
    transport: TransportManager | None = None
    config: AppConfig = None  # type: ignore[assignment]
    db: Database = None       # type: ignore[assignment]
    bridge: EventBridge = None  # type: ignore[assignment]

    def on_mount(self) -> None:
        self.config = load_config()
        _setup_logging(self.config.log_level, debug=self._debug)
        if self._debug:
            logging.getLogger(__name__).debug("Debug logging active → %s", LOG_FILE)
        self.db = Database(self.config.db_path)
        self.bridge = EventBridge(self)

        for t in ALL_THEMES:
            self.register_theme(t)
        valid = {t.name for t in ALL_THEMES}
        if self.config.theme not in valid:
            self.config.theme = "meshtty-multicolor"
        self.theme = self.config.theme

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
        try:
            logging.getLogger(__name__).info(
                "Connection established via %s", self.transport
            )
        except Exception:
            pass

    def on_connection_lost(self, event: ConnectionLost) -> None:
        try:
            logging.getLogger(__name__).warning("Connection lost: %s", event.reason)
            if self.transport:
                try:
                    self.transport.disconnect()
                except Exception:
                    pass
                self.transport = None
        except Exception:
            pass

    def on_text_message_received(self, event: TextMessageReceived) -> None:
        try:
            if self.screen:
                self.screen.post_message(event)
        except Exception:
            pass

    def on_node_updated(self, event: NodeUpdated) -> None:
        try:
            if self.screen:
                self.screen.post_message(event)
        except Exception:
            pass

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
    parser = argparse.ArgumentParser(description="MeshTTY — Meshtastic TUI client")
    parser.add_argument(
        "--debug",
        action="store_true",
        help=f"Enable DEBUG logging (all loggers including meshtastic) → {LOG_FILE}",
    )
    args = parser.parse_args()

    if args.debug:
        print(f"Debug logging enabled → {LOG_FILE}", file=sys.stderr)

    app = MeshTTYApp()
    app._debug = args.debug
    app.run()


if __name__ == "__main__":
    main()
