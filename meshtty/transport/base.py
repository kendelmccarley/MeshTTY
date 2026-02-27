from abc import ABC, abstractmethod


class TransportManager(ABC):
    def __init__(self) -> None:
        self._interface = None

    @abstractmethod
    def connect(self) -> None:
        """Blocking connect. Call from a worker thread, not the event loop."""

    @abstractmethod
    def disconnect(self) -> None:
        """Close the radio connection and release resources."""

    @property
    def is_connected(self) -> bool:
        return self._interface is not None

    def send_text(
        self,
        text: str,
        destination: str = "^all",
        channel: int = 0,
    ) -> None:
        if self._interface is None:
            raise RuntimeError("Not connected")
        self._interface.sendText(text, destinationId=destination, channelIndex=channel)

    def get_nodes(self) -> dict:
        if self._interface is None:
            return {}
        return self._interface.nodes or {}

    def get_my_node(self) -> dict:
        if self._interface is None:
            return {}
        return self._interface.getMyNodeInfo() or {}

    @property
    def transport_type(self) -> str:
        """Return a human-readable transport type name."""
        return self.__class__.__name__.replace("Transport", "").lower()
