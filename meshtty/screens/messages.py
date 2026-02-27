"""MessagesView — channel sidebar + message history + compose bar."""

from __future__ import annotations

import time

from textual import work
from textual.app import ComposeResult
from textual.containers import Horizontal
from textual.widget import Widget

from meshtty.messages.app_messages import TextMessageReceived
from meshtty.widgets.channel_list import ChannelList
from meshtty.widgets.compose_bar import ComposeBar
from meshtty.widgets.message_view import MessageView


class MessagesView(Widget):
    """Full messages panel: channel list + message history + compose."""

    DEFAULT_CSS = """
    MessagesView {
        height: 1fr;
        layout: horizontal;
    }
    #messages-right {
        width: 1fr;
        height: 1fr;
        layout: vertical;
    }
    """

    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs)
        self._current_channel = 0  # updated in on_mount once app is available

    def compose(self) -> ComposeResult:
        yield ChannelList()
        with Horizontal(id="messages-right"):
            yield MessageView(id="message-view")
            yield ComposeBar()

    def on_mount(self) -> None:
        self._current_channel = self.app.config.default_channel
        self._load_history(self._current_channel)

    def on_show(self) -> None:
        """Re-focus compose input whenever the Messages tab becomes active."""
        try:
            self.query_one("#compose-input").focus()
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Event handlers
    # ------------------------------------------------------------------

    def on_channel_list_channel_selected(self, event: ChannelList.ChannelSelected) -> None:
        self._current_channel = event.channel_index
        view = self.query_one("#message-view", MessageView)
        # Clear and reload
        view.remove_children()
        self._load_history(self._current_channel)

    def on_compose_bar_send_requested(self, event: ComposeBar.SendRequested) -> None:
        event.stop()
        text = event.text
        transport = self.app.transport
        if transport is None or not transport.is_connected:
            return
        try:
            transport.send_text(text, channel=self._current_channel)
        except Exception:
            return
        # Show immediately in the UI
        now = int(time.time())
        my_node = transport.get_my_node()
        my_id = my_node.get("num", "me") if my_node else "me"
        my_id_str = f"!{my_id:08x}" if isinstance(my_id, int) else str(my_id)
        view = self.query_one("#message-view", MessageView)
        view.append_message(my_id_str, text, now, is_mine=True)
        # Persist to DB in background
        self._write_message(my_id_str, "^all", self._current_channel, text, now, True)

    def on_text_message_received(self, event: TextMessageReceived) -> None:
        if event.channel != self._current_channel:
            return
        view = self.query_one("#message-view", MessageView)
        view.append_message(event.from_id, event.text, event.rx_time)
        self._write_message(
            event.from_id,
            event.to_id,
            event.channel,
            event.text,
            event.rx_time,
            False,
            event.packet_id,
        )

    # ------------------------------------------------------------------
    # Workers
    # ------------------------------------------------------------------

    @work(thread=True, name="load-history")
    def _load_history(self, channel: int) -> None:
        rows = self.app.db.get_messages(channel=channel, limit=200)
        self.app.call_from_thread(self._apply_history, rows)

    def _apply_history(self, rows: list) -> None:
        view = self.query_one("#message-view", MessageView)
        view.load_messages(rows)

    @work(thread=True, name="write-message")
    def _write_message(
        self,
        from_id: str,
        to_id: str,
        channel: int,
        text: str,
        rx_time: int,
        is_mine: bool,
        packet_id: str | None = None,
    ) -> None:
        self.app.db.insert_message(from_id, to_id, channel, text, rx_time, is_mine, packet_id)
