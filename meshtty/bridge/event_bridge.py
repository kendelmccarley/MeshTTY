"""PyPubSub → Textual thread-safe event bridge.

meshtastic-python fires PyPubSub callbacks on its own internal thread.
Textual's event loop runs on the main asyncio thread.

post_message() is already thread-safe in Textual 8: when called from a
non-asyncio thread it uses call_soon_threadsafe() internally, which is
non-blocking and returns False gracefully if the app is closing.

Never use call_from_thread() here — it blocks the meshtastic thread until
the main loop processes the coroutine, causing a deadlock if the event loop
is shutting down.
"""

from __future__ import annotations

import json
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
_diag = logging.getLogger("meshtty.diag")  # always-on diagnostic logger


def _scan_for(obj, needle: str, path: str = "") -> list[str]:
    """Recursively walk obj and return every path where needle appears."""
    hits = []
    needle_low = needle.lower()
    if isinstance(obj, dict):
        for k, v in obj.items():
            hits.extend(_scan_for(v, needle, f"{path}.{k}" if path else str(k)))
    elif isinstance(obj, (list, tuple)):
        for i, v in enumerate(obj):
            hits.extend(_scan_for(v, needle, f"{path}[{i}]"))
    else:
        try:
            if needle_low in str(obj).lower():
                hits.append(f"{path} = {obj!r}")
        except Exception:
            pass
    return hits


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
    #
    # Use post_message() directly — it is thread-safe in Textual 8 and
    # non-blocking.  Never use call_from_thread() here.
    # ------------------------------------------------------------------

    def _on_text(self, packet: dict, interface) -> None:  # noqa: ANN001
        try:
            # --- Diagnostic: dump full packet + node entry for every DM ---
            try:
                from_id = packet.get("fromId") or f"!{packet.get('from', 0):08x}"
                _diag.warning("=== INCOMING TEXT PACKET ===")
                _diag.warning("packet: %s", json.dumps(packet, default=str))
                # Scan entire packet for "T22M"
                hits = _scan_for(packet, "T22M")
                _diag.warning("T22M in packet: %s", hits if hits else "NOT FOUND")
                # Dump the nodes dict entry for this sender
                nodes = getattr(interface, "nodes", {}) or {}
                _diag.warning("nodes keys sample: %s", list(nodes.keys())[:10])
                # Try every possible key form
                node_direct = nodes.get(from_id)
                _diag.warning("nodes[%r] direct: %s", from_id, json.dumps(node_direct, default=str) if node_direct else "NOT FOUND")
                # Also scan all nodes for T22M
                node_hits = _scan_for(nodes, "T22M")
                _diag.warning("T22M in nodes: %s", node_hits if node_hits else "NOT FOUND")
            except Exception as diag_exc:
                _diag.warning("diagnostic dump failed: %s", diag_exc)
            # --- End diagnostic ---
            self._app.post_message(TextMessageReceived(packet))
        except Exception as exc:
            log.error("_on_text bridge error: %s", exc)

    def _on_position(self, packet: dict, interface) -> None:  # noqa: ANN001
        try:
            node_id = packet.get("fromId", "")
            if node_id and interface and interface.nodes:
                node = interface.nodes.get(node_id, {})
                info = _extract_node_info(node)
                self._app.post_message(NodeUpdated(node_id, info))
        except Exception as exc:
            log.error("_on_position bridge error: %s", exc)

    def _on_telemetry(self, packet: dict, interface) -> None:  # noqa: ANN001
        try:
            node_id = packet.get("fromId", "")
            if node_id and interface and interface.nodes:
                node = interface.nodes.get(node_id, {})
                info = _extract_node_info(node)
                self._app.post_message(NodeUpdated(node_id, info))
        except Exception as exc:
            log.error("_on_telemetry bridge error: %s", exc)

    def _on_node_updated(self, node: dict, interface) -> None:  # noqa: ANN001
        try:
            node_id = node.get("id") or node.get("num", "")
            if node_id:
                info = _extract_node_info(node)
                self._app.post_message(NodeUpdated(str(node_id), info))
        except Exception as exc:
            log.error("_on_node_updated bridge error: %s", exc)

    def _on_connected(self, interface, topic=pub.AUTO_TOPIC) -> None:  # noqa: ANN001
        # _pending_transport is stored on the app by _connect_worker before the
        # blocking transport.connect() call.  Posting ConnectionEstablished here
        # (when _waitConnected completes) lets the connection screen transition
        # immediately without waiting for waitForConfig, which can take 5+ min
        # on a busy 100-node network.
        try:
            log.debug("meshtastic.connection.established received")
            pending = getattr(self._app, "_pending_transport", None)
            if pending is not None:
                self._app.post_message(ConnectionEstablished(pending))
        except Exception as exc:
            log.error("_on_connected bridge error: %s", exc)

    def _on_lost(self, interface, topic=pub.AUTO_TOPIC) -> None:  # noqa: ANN001
        try:
            self._app.post_message(ConnectionLost("Connection lost"))
        except Exception as exc:
            log.error("_on_lost bridge error: %s", exc)
