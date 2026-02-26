import meshtastic.tcp_interface

from .base import TransportManager


class TCPTransport(TransportManager):
    def __init__(self, hostname: str, port: int = 4403) -> None:
        super().__init__()
        self._hostname = hostname
        self._port = port

    def connect(self) -> None:
        self._interface = meshtastic.tcp_interface.TCPInterface(
            self._hostname, portNumber=self._port
        )

    def disconnect(self) -> None:
        if self._interface is not None:
            self._interface.close()
            self._interface = None

    @property
    def transport_type(self) -> str:
        return "tcp"

    def __str__(self) -> str:
        return f"TCP ({self._hostname}:{self._port})"
