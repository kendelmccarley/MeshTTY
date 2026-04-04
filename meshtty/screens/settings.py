"""SettingsScreen — configure transport defaults and app preferences."""

from __future__ import annotations

from textual.app import ComposeResult
from textual.widget import Widget
from textual.widgets import Button, Input, Label

from meshtty.config.settings import save_config
from meshtty.themes import ALL_THEMES
from meshtty.widgets.cycle_select import CycleSelect


_TRANSPORT_OPTIONS = [
    ("Serial / USB", "serial"),
    ("TCP / WiFi", "tcp"),
    ("Bluetooth (BLE)", "ble"),
]

_TOGGLE_OPTIONS = [("Yes", "yes"), ("No", "no")]

_THEME_OPTIONS = [
    ("Amber",          "crt-amber"),
    ("Green Phosphor", "crt-phosphor"),
    ("IBM / Grey",     "crt-ibm"),
]


class SettingsView(Widget):
    """Settings panel rendered inside the MainScreen Settings tab."""

    DEFAULT_CSS = """
    SettingsView {
        height: 1fr;
        overflow-y: auto;
        padding: 0 2;
        layout: grid;
        grid-size: 2;
        grid-rows: 1;
        grid-columns: 28 1fr;
        grid-gutter: 0;
    }
    .full-width {
        column-span: 2;
        height: 1;
        margin: 0;
        padding: 0;
    }
    .section-header {
        column-span: 2;
        height: 1;
        color: $primary;
        text-style: bold;
        margin: 0;
        padding: 0;
    }
    .setting-label {
        height: 1;
        margin: 0;
        padding: 0;
    }
    .setting-value {
        height: 1;
        margin: 0;
        padding: 0;
        border: none;
    }
    #save-btn {
        height: 1;
        width: 10;
        margin: 0;
    }
    #save-status {
        color: $success;
    }
    #disconnect-btn {
        height: 1;
        width: 14;
        margin: 0;
    }
    """

    def compose(self) -> ComposeResult:
        cfg = self.app.config

        yield Label("Disconnected", id="conn-status-label", classes="full-width")
        yield Button("Disconnect", id="disconnect-btn", variant="error",
                     disabled=True, classes="full-width")

        yield Label("Default transport", classes="setting-label")
        yield CycleSelect(_TRANSPORT_OPTIONS, value=cfg.default_transport,
                          id="sel-transport", classes="setting-value")

        yield Label("Serial port", classes="setting-label")
        yield Input(value=cfg.last_serial_port, placeholder="/dev/ttyUSB0",
                    id="inp-serial", classes="setting-value")

        yield Label("TCP hostname", classes="setting-label")
        yield Input(value=cfg.last_tcp_host, placeholder="192.168.1.100",
                    id="inp-tcp-host", classes="setting-value")

        yield Label("TCP port", classes="setting-label")
        yield Input(value=str(cfg.last_tcp_port), placeholder="4403",
                    id="inp-tcp-port", classes="setting-value")

        yield Label("BLE address", classes="setting-label")
        yield Input(value=cfg.last_ble_address, placeholder="AA:BB:CC:DD:EE:FF",
                    id="inp-ble", classes="setting-value")

        yield Label("Auto-connect on launch", classes="setting-label")
        yield CycleSelect(_TOGGLE_OPTIONS,
                          value="yes" if cfg.auto_connect else "no",
                          id="sw-autoconnect", classes="setting-value")

        yield Label("Display", classes="section-header")

        yield Label("Show short node names", classes="setting-label")
        yield CycleSelect(_TOGGLE_OPTIONS,
                          value="yes" if cfg.node_short_name_display else "no",
                          id="sw-shortnames", classes="setting-value")

        yield Label("Theme", classes="setting-label")
        yield CycleSelect(_THEME_OPTIONS, value=cfg.theme,
                          id="sel-theme", classes="setting-value")

        yield Label("Messaging", classes="section-header")

        yield Label("Default channel", classes="setting-label")
        yield Input(value=str(cfg.default_channel), placeholder="0",
                    id="inp-channel", classes="setting-value")

        yield Button("Save", id="save-btn", variant="primary", classes="full-width")
        yield Label("", id="save-status", classes="full-width")

    def on_mount(self) -> None:
        self._refresh_connection_status()

    def on_show(self) -> None:
        self._refresh_connection_status()

    def _refresh_connection_status(self) -> None:
        try:
            transport = self.app.transport
            label = self.query_one("#conn-status-label", Label)
            btn = self.query_one("#disconnect-btn", Button)
            if transport and transport.is_connected:
                nodes = len(transport.get_nodes())
                my_node = transport.get_my_node()
                bat = (my_node.get("deviceMetrics", {}) or {}).get("batteryLevel") if my_node else None
                bat_str = f" | Bat: {bat}%" if bat is not None else ""
                label.update(f"Connected via {transport} | {nodes} nodes{bat_str}")
                btn.disabled = False
            else:
                label.update("Disconnected")
                btn.disabled = True
        except Exception:
            pass

    def on_connection_established(self, event) -> None:
        try:
            self._refresh_connection_status()
        except Exception:
            pass

    def on_connection_lost(self, event) -> None:
        try:
            self._refresh_connection_status()
        except Exception:
            pass

    def on_node_updated(self, event) -> None:
        try:
            self._refresh_connection_status()
        except Exception:
            pass

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "disconnect-btn":
            event.stop()
            self.app.action_disconnect()
        elif event.button.id == "save-btn":
            event.stop()
            self._save()

    def _save(self) -> None:
        cfg = self.app.config

        cfg.default_transport = self.query_one("#sel-transport", CycleSelect).value or "serial"
        cfg.last_serial_port = self.query_one("#inp-serial", Input).value.strip()
        cfg.last_tcp_host = self.query_one("#inp-tcp-host", Input).value.strip()
        try:
            cfg.last_tcp_port = int(self.query_one("#inp-tcp-port", Input).value) or 4403
        except ValueError:
            cfg.last_tcp_port = 4403
        cfg.last_ble_address = self.query_one("#inp-ble", Input).value.strip()
        cfg.auto_connect = self.query_one("#sw-autoconnect", CycleSelect).value == "yes"
        cfg.node_short_name_display = self.query_one("#sw-shortnames", CycleSelect).value == "yes"
        cfg.theme = self.query_one("#sel-theme", CycleSelect).value or "crt-amber"
        try:
            cfg.default_channel = int(self.query_one("#inp-channel", Input).value)
        except ValueError:
            cfg.default_channel = 0

        save_config(cfg)
        self.app.theme = cfg.theme
        self.query_one("#save-status", Label).update("Settings saved.")
