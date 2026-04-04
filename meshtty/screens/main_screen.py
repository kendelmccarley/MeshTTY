"""MainScreen — primary hub screen with TabbedContent."""

from __future__ import annotations

from textual.app import ComposeResult
from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import Rule, TabbedContent, TabPane

from meshtty.messages.app_messages import (
    ConnectionEstablished,
    ConnectionLost,
    NodeUpdated,
    SettingsChanged,
    TextMessageReceived,
)
from meshtty.screens.channels import ChannelView
from meshtty.screens.messages import MessagesView
from meshtty.screens.node_detail import NodeDetailModal
from meshtty.screens.nodes import NodeListView
from meshtty.screens.settings import SettingsView
from meshtty.widgets.status_bar import ConnectionStatusBar
from meshtty.widgets.terminal_frame import TerminalFrame

LAYERS = ("frame", "content")

_TAB_ORDER = ["tab-messages", "tab-channels", "tab-nodes", "tab-settings"]
_TAB_NAMES = {
    "tab-messages": "MESSAGES",
    "tab-channels": "CHANNELS",
    "tab-nodes": "NODES",
    "tab-settings": "SETTINGS",
}


class MainScreen(Screen):
    """Primary application screen."""

    LAYERS = LAYERS

    DEFAULT_CSS = """
    #main-tabs > Tabs {
        display: none;
        height: 0;
    }
    #header-rule {
        height: 1;
        margin: 0;
        color: $primary;
        layer: content;
    }
    """

    BINDINGS = [
        Binding("ctrl+q", "app.quit", "Quit"),
        Binding("ctrl+d", "app.disconnect", "Disconnect"),
        Binding("ctrl+r", "refresh_nodes", "Refresh"),
        Binding("ctrl+t", "next_tab", "Next Tab", priority=True),
    ]

    def compose(self) -> ComposeResult:
        # Frame drawn behind everything else
        yield TerminalFrame(title="MeshTTY")
        # Content layer: status bar pinned to top, tabs fill the rest
        yield ConnectionStatusBar()
        yield Rule(id="header-rule")
        with TabbedContent(id="main-tabs", initial="tab-messages"):
            with TabPane("MESSAGES", id="tab-messages"):
                yield MessagesView(id="messages-view")
            with TabPane("CHANNELS", id="tab-channels"):
                yield ChannelView(id="channels-view")
            with TabPane("NODES", id="tab-nodes"):
                yield NodeListView(id="nodes-view")
            with TabPane("SETTINGS", id="tab-settings"):
                yield SettingsView(id="settings-view")

    def on_mount(self) -> None:
        try:
            self.query_one(ConnectionStatusBar).page_name = "MESSAGES"
        except Exception:
            pass

    # ------------------------------------------------------------------
    # App message handlers (routed from MeshTTYApp)
    # ------------------------------------------------------------------

    def on_connection_established(self, event: ConnectionEstablished) -> None:
        try:
            bar = self.query_one(ConnectionStatusBar)
            bar.connection_state = "connected"
        except Exception:
            pass
        try:
            self.query_one("#settings-view", SettingsView).post_message(event)
        except Exception:
            pass
        try:
            self.query_one("#channels-view", ChannelView).post_message(event)
        except Exception:
            pass

    def on_connection_lost(self, event: ConnectionLost) -> None:
        try:
            bar = self.query_one(ConnectionStatusBar)
            bar.connection_state = "disconnected"
        except Exception:
            pass
        try:
            self.query_one("#settings-view", SettingsView).post_message(event)
        except Exception:
            pass

    def on_text_message_received(self, event: TextMessageReceived) -> None:
        try:
            self.query_one("#messages-view", MessagesView).post_message(event)
        except Exception:
            pass

    def on_tabbed_content_tab_activated(self, event: TabbedContent.TabActivated) -> None:
        try:
            pane_id = event.pane.id if event.pane else None
            name = _TAB_NAMES.get(pane_id, "")
            if name:
                self.query_one(ConnectionStatusBar).page_name = name
        except Exception:
            pass

    def on_node_updated(self, event: NodeUpdated) -> None:
        try:
            self.query_one("#settings-view", SettingsView).post_message(event)
        except Exception:
            pass
        try:
            self.query_one("#nodes-view", NodeListView).post_message(event)
        except Exception:
            pass

    def on_settings_changed(self, event: SettingsChanged) -> None:
        try:
            self.query_one("#nodes-view", NodeListView).post_message(event)
        except Exception:
            pass
        try:
            self.query_one("#messages-view", MessagesView).post_message(event)
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Row selection on the node table → push detail modal
    # ------------------------------------------------------------------

    def on_data_table_row_selected(self, event) -> None:
        try:
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
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Actions
    # ------------------------------------------------------------------

    def action_next_tab(self) -> None:
        tc = self.query_one("#main-tabs", TabbedContent)
        try:
            idx = _TAB_ORDER.index(tc.active)
        except ValueError:
            idx = -1
        next_id = _TAB_ORDER[(idx + 1) % len(_TAB_ORDER)]
        tc.active = next_id
        try:
            if next_id == "tab-messages":
                self.query_one("#compose-input").focus()
            elif next_id == "tab-channels":
                self.query_one("#channel-list").focus()
            elif next_id == "tab-nodes":
                self.query_one("DataTable").focus()
            elif next_id == "tab-settings":
                self.query_one("#sel-transport").focus()
        except Exception:
            pass

    def action_refresh_nodes(self) -> None:
        try:
            nodes_view = self.query_one("#nodes-view", NodeListView)
            nodes_view._load_nodes()
        except Exception:
            pass
