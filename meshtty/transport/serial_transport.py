import logging

import meshtastic.serial_interface

from .base import TransportManager

log = logging.getLogger(__name__)

_CONNECT_TIMEOUT = 120.0  # seconds; default 30s is too short for large node DBs


class _SerialInterface(meshtastic.serial_interface.SerialInterface):
    """SerialInterface with an extended _waitConnected timeout."""

    def _waitConnected(self, timeout: float = _CONNECT_TIMEOUT) -> None:
        super()._waitConnected(timeout=timeout)


class SerialTransport(TransportManager):
    def __init__(self, dev_path: str) -> None:
        super().__init__()
        self._dev_path = dev_path

    def connect(self) -> None:
        log.debug("SerialInterface opening %s (timeout=%ss)", self._dev_path, int(_CONNECT_TIMEOUT))
        self._interface = _SerialInterface(self._dev_path)
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
