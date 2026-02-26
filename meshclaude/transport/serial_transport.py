import meshtastic.serial_interface

from .base import TransportManager


class SerialTransport(TransportManager):
    def __init__(self, dev_path: str) -> None:
        super().__init__()
        self._dev_path = dev_path

    def connect(self) -> None:
        self._interface = meshtastic.serial_interface.SerialInterface(self._dev_path)

    def disconnect(self) -> None:
        if self._interface is not None:
            self._interface.close()
            self._interface = None

    @property
    def transport_type(self) -> str:
        return "serial"

    def __str__(self) -> str:
        return f"Serial ({self._dev_path})"
