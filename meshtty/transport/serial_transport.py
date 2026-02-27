import logging

import meshtastic.serial_interface

from .base import TransportManager

log = logging.getLogger(__name__)


class SerialTransport(TransportManager):
    def __init__(self, dev_path: str) -> None:
        super().__init__()
        self._dev_path = dev_path

    def connect(self) -> None:
        log.debug("SerialInterface opening %s", self._dev_path)
        self._interface = meshtastic.serial_interface.SerialInterface(self._dev_path)
        log.debug("SerialInterface opened successfully")

    def disconnect(self) -> None:
        if self._interface is not None:
            self._interface.close()
            self._interface = None

    @property
    def transport_type(self) -> str:
        return "serial"

    def __str__(self) -> str:
        return f"Serial ({self._dev_path})"
