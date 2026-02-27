"""Custom Textual Message subclasses for inter-component communication.

All messages originate in the EventBridge (posted via app.call_from_thread)
and are dispatched by Textual to registered handlers across the widget tree.
"""

from textual.message import Message


class TextMessageReceived(Message):
    """A text message arrived from the mesh network."""

    def __init__(self, packet: dict) -> None:
        self.packet = packet
        decoded = packet.get("decoded", {})
        self.from_id: str = packet.get("fromId", "!unknown")
        self.to_id: str = packet.get("toId", "^all")
        self.channel: int = packet.get("channel", 0)
        self.text: str = decoded.get("text", "")
        self.rx_time: int = packet.get("rxTime", 0)
        self.packet_id: str | None = str(packet.get("id")) if packet.get("id") else None
        super().__init__()


class NodeUpdated(Message):
    """A node's information has changed (position, telemetry, first seen, etc.)."""

    def __init__(self, node_id: str, node_info: dict) -> None:
        self.node_id = node_id
        self.node_info = node_info
        super().__init__()


class ConnectionEstablished(Message):
    """Radio connection was successfully established."""

    def __init__(self, transport) -> None:
        self.transport = transport
        super().__init__()


class ConnectionLost(Message):
    """Radio connection was lost or failed to connect."""

    def __init__(self, reason: str = "") -> None:
        self.reason = reason
        super().__init__()


class TransportChanged(Message):
    """User switched to a different transport type."""

    def __init__(self, transport_type: str) -> None:
        self.transport_type = transport_type
        super().__init__()
