"""MainScreen — primary hub screen with TabbedContent."""

from __future__ import annotations

from textual import work
from textual.app import ComposeResult
from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import Footer, Header, TabbedContent, TabPane

from meshclaude.messages.app_messages import (
    ConnectionEstablished,
    ConnectionLost,
    NodeUpdated,
    TextMessageReceived,
)
from meshclaude.screens.messages import MessagesView
from meshclaude.screens.node_detail import NodeDetailModal
from meshclaude.screens.nodes import NodeListView
from meshclaude.screens.settings import SettingsView
from meshclaude.widgets.node_table import NodeTable
from meshclaude.widgets.status_bar import ConnectionStatusBar


class MainScreen(Screen):
    """Primary application screen."""

    BINDINGS = [
        Binding("ctrl+q", "app.quit", "Quit"),
        Binding("ctrl+d", "app.disconnect", "Disconnect"),
        Binding("ctrl+r", "refresh_nodes", "Refresh"),
        Binding("1", "switch_tab('tab-messages')", "Messages"),
        Binding("2", "switch_tab('tab-nodes')", "Nodes"),
        Binding("3", "switch_tab('tab-settings')", "Settings"),
    ]

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        yield ConnectionStatusBar(id="status-bar")
        with TabbedContent(id="main-tabs", initial="tab-messages"):
            with TabPane("Messages [1]", id="tab-messages"):
                yield MessagesView(id="messages-view")
            with TabPane("Nodes [2]", id="tab-nodes"):
                yield NodeListView(id="nodes-view")
            with TabPane("Settings [3]", id="tab-settings"):
                yield SettingsView(id="settings-view")
        yield Footer()

    def on_mount(self) -> None:
        # If already connected when screen mounts, reflect that state
        transport = self.app.transport
        if transport and transport.is_connected:
            self._update_status_connected()

    # ------------------------------------------------------------------
    # App message handlers (routed from MeshClaudeApp)
    # ------------------------------------------------------------------

    def on_connection_established(self, event: ConnectionEstablished) -> None:
        self._update_status_connected()

    def on_connection_lost(self, event: ConnectionLost) -> None:
        bar = self.query_one("#status-bar", ConnectionStatusBar)
        bar.connection_state = "disconnected"
        bar.channel_name = "—"
        bar.battery_level = None

    def on_text_message_received(self, event: TextMessageReceived) -> None:
        # Route to the MessagesView
        try:
            self.query_one("#messages-view", MessagesView).post_message(event)
        except Exception:
            pass

    def on_node_updated(self, event: NodeUpdated) -> None:
        # Update node count on status bar
        transport = self.app.transport
        if transport:
            bar = self.query_one("#status-bar", ConnectionStatusBar)
            bar.node_count = len(transport.get_nodes())
        # Route to NodeListView
        try:
            self.query_one("#nodes-view", NodeListView).post_message(event)
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Row selection on the node table → push detail modal
    # ------------------------------------------------------------------

    def on_data_table_row_selected(self, event) -> None:
        node_id = str(event.row_key.value) if event.row_key else None
        if not node_id:
            return
        transport = self.app.transport
        if transport is None:
            return
        nodes = transport.get_nodes()
        node = nodes.get(node_id, {})
        user = node.get("user", {})
        pos = node.get("position", {})
        metrics = node.get("deviceMetrics", {})
        info = {
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
        self.app.push_screen(NodeDetailModal(node_id, info))

    # ------------------------------------------------------------------
    # Actions
    # ------------------------------------------------------------------

    def action_switch_tab(self, tab_id: str) -> None:
        self.query_one("#main-tabs", TabbedContent).active = tab_id

    def action_refresh_nodes(self) -> None:
        try:
            nodes_view = self.query_one("#nodes-view", NodeListView)
            nodes_view._load_nodes()
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _update_status_connected(self) -> None:
        transport = self.app.transport
        if not transport:
            return
        bar = self.query_one("#status-bar", ConnectionStatusBar)
        bar.connection_state = "connected"
        # Try to get local node info for battery
        try:
            my_node = transport.get_my_node()
            metrics = my_node.get("deviceMetrics", {}) if my_node else {}
            bat = metrics.get("batteryLevel")
            bar.battery_level = bat
        except Exception:
            pass
        bar.node_count = len(transport.get_nodes())
