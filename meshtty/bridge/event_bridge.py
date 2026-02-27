"""PyPubSub → Textual thread-safe event bridge.

meshtastic-python fires PyPubSub callbacks on its own internal thread.
Textual's event loop runs on the main asyncio thread.

The ONLY safe crossing point is app.call_from_thread(), which queues a
callable into Textual's event loop from any non-async thread.

Never touch widgets or reactive attributes directly from a callback here.
"""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

from pubsub import pub

from meshtty.messages.app_messages import (
    ConnectionEstablished,
    ConnectionLost,
    NodeUpdated,
    TextMessageReceived,
)

if TYPE_CHECKING:
    from textual.app import App

log = logging.getLogger(__name__)


def _extract_node_info(node: dict) -> dict:
    """Flatten a meshtastic node dict into our canonical node_info shape."""
    user = node.get("user", {})
    pos = node.get("position", {})
    metrics = node.get("deviceMetrics", {})
    return {
        "short_name": user.get("shortName", ""),
        "long_name": user.get("longName", ""),
        "hw_model": user.get("hwModel", ""),
        "last_snr": node.get("snr"),
        "last_lat": pos.get("latitude"),
        "last_lon": pos.get("longitude"),
        "last_alt": pos.get("altitude"),
        "battery": metrics.get("batteryLevel"),
        "last_heard": node.get("lastHeard"),
    }


class EventBridge:
    """Subscribes to meshtastic PyPubSub topics and bridges into Textual."""

    def __init__(self, app: "App") -> None:
        self._app = app
        self._subscribed = False

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def subscribe(self) -> None:
        if self._subscribed:
            return
        pub.subscribe(self._on_text, "meshtastic.receive.text")
        pub.subscribe(self._on_position, "meshtastic.receive.position")
        pub.subscribe(self._on_telemetry, "meshtastic.receive.telemetry")
        pub.subscribe(self._on_node_updated, "meshtastic.node.updated")
        pub.subscribe(self._on_connected, "meshtastic.connection.established")
        pub.subscribe(self._on_lost, "meshtastic.connection.lost")
        self._subscribed = True
        log.debug("EventBridge subscribed")

    def unsubscribe(self) -> None:
        if not self._subscribed:
            return
        pairs = [
            ("meshtastic.receive.text", self._on_text),
            ("meshtastic.receive.position", self._on_position),
            ("meshtastic.receive.telemetry", self._on_telemetry),
            ("meshtastic.node.updated", self._on_node_updated),
            ("meshtastic.connection.established", self._on_connected),
            ("meshtastic.connection.lost", self._on_lost),
        ]
        for topic, handler in pairs:
            try:
                pub.unsubscribe(handler, topic)
            except Exception:
                pass
        self._subscribed = False
        log.debug("EventBridge unsubscribed")

    # ------------------------------------------------------------------
    # PyPubSub callbacks (run on meshtastic's internal thread)
    # ------------------------------------------------------------------

    def _on_text(self, packet: dict, interface) -> None:  # noqa: ANN001
        try:
            self._app.call_from_thread(
                self._app.post_message, TextMessageReceived(packet)
            )
        except Exception as exc:
            log.error("_on_text bridge error: %s", exc)

    def _on_position(self, packet: dict, interface) -> None:  # noqa: ANN001
        try:
            node_id = packet.get("fromId", "")
            if node_id and interface and interface.nodes:
                node = interface.nodes.get(node_id, {})
                info = _extract_node_info(node)
                self._app.call_from_thread(
                    self._app.post_message, NodeUpdated(node_id, info)
                )
        except Exception as exc:
            log.error("_on_position bridge error: %s", exc)

    def _on_telemetry(self, packet: dict, interface) -> None:  # noqa: ANN001
        try:
            node_id = packet.get("fromId", "")
            if node_id and interface and interface.nodes:
                node = interface.nodes.get(node_id, {})
                info = _extract_node_info(node)
                self._app.call_from_thread(
                    self._app.post_message, NodeUpdated(node_id, info)
                )
        except Exception as exc:
            log.error("_on_telemetry bridge error: %s", exc)

    def _on_node_updated(self, node: dict, interface) -> None:  # noqa: ANN001
        try:
            node_id = node.get("id") or node.get("num", "")
            if node_id:
                info = _extract_node_info(node)
                self._app.call_from_thread(
                    self._app.post_message, NodeUpdated(str(node_id), info)
                )
        except Exception as exc:
            log.error("_on_node_updated bridge error: %s", exc)

    def _on_connected(self, interface, topic=pub.AUTO_TOPIC) -> None:  # noqa: ANN001
        # NOTE: self._app.transport is not yet set when this fires — the worker
        # sets it after SerialInterface() returns.  The connection screen's
        # _on_connect_success handles posting ConnectionEstablished with the
        # real transport once the worker finishes.
        log.debug("meshtastic.connection.established received")

    def _on_lost(self, interface, topic=pub.AUTO_TOPIC) -> None:  # noqa: ANN001
        try:
            self._app.call_from_thread(
                self._app.post_message, ConnectionLost("Connection lost")
            )
        except Exception as exc:
            log.error("_on_lost bridge error: %s", exc)
