import meshtastic.ble_interface

from .base import TransportManager


class BLETransport(TransportManager):
    def __init__(self, address: str) -> None:
        super().__init__()
        self._address = address

    def connect(self) -> None:
        self._interface = meshtastic.ble_interface.BLEInterface(self._address)

    def disconnect(self) -> None:
        if self._interface is not None:
            self._interface.close()
            self._interface = None

    @property
    def transport_type(self) -> str:
        return "ble"

    def __str__(self) -> str:
        return f"BLE ({self._address})"
