"""MessagesView — unified message history + compose bar."""

from __future__ import annotations

import time

from textual import work
from textual.app import ComposeResult
from textual.events import Key
from textual.widget import Widget

from meshtty.messages.app_messages import TextMessageReceived
from meshtty.widgets.compose_bar import ComposeBar
from meshtty.widgets.message_view import MessageView


class MessagesView(Widget):
    """Full messages panel: unified message history + compose."""

    DEFAULT_CSS = """
    MessagesView {
        height: 1fr;
        layout: vertical;
    }
    """

    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs)
        self._last_prefix: str = ""

    def compose(self) -> ComposeResult:
        yield MessageView(id="message-view")
        yield ComposeBar()

    def on_mount(self) -> None:
        transport = self.app.transport
        channels = transport.get_channels() if transport else []
        first_name = channels[0][1] if channels else "Primary"
        self._last_prefix = first_name
        try:
            self.query_one(ComposeBar).set_prefix(first_name)
        except Exception:
            pass
        self._load_history()

    def on_show(self) -> None:
        """Re-focus compose input whenever the Messages tab becomes active."""
        try:
            self.query_one("#compose-input").focus()
        except Exception:
            pass

    def on_key(self, event: Key) -> None:
        """Arrow keys scroll the message view regardless of focus."""
        try:
            view = self.query_one("#message-view", MessageView)
            if event.key == "up":
                view.scroll_up(animate=False)
                event.stop()
            elif event.key == "down":
                view.scroll_down(animate=False)
                event.stop()
            elif event.key == "pageup":
                view.scroll_page_up(animate=False)
                event.stop()
            elif event.key == "pagedown":
                view.scroll_page_down(animate=False)
                event.stop()
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Prefix resolution helpers
    # ------------------------------------------------------------------

    def _resolve_incoming_prefix(self, event: TextMessageReceived) -> str:
        """Determine a human-readable prefix for an incoming message."""
        transport = self.app.transport
        if event.to_id == "^all":
            if transport:
                for idx, name in transport.get_channels():
                    if idx == event.channel:
                        return name
            return f"Ch {event.channel}"
        else:
            if transport:
                nodes = transport.get_nodes()
                node = nodes.get(event.from_id, {})
                user = node.get("user", {}) if node else {}
                short = user.get("shortName", "").strip()
                if short:
                    return short
            return event.from_id

    def _resolve_send_destination(self, prefix: str) -> tuple[int | None, str]:
        """Return (channel_idx, dest_id) from a prefix string."""
        transport = self.app.transport
        if transport:
            for idx, name in transport.get_channels():
                if name.lower() == prefix.lower():
                    return (idx, "^all")
            for node_id, node in transport.get_nodes().items():
                user = node.get("user", {}) if node else {}
                short = user.get("shortName", "").strip()
                if short and short.lower() == prefix.lower():
                    return (None, node_id)
        return (0, "^all")

    # ------------------------------------------------------------------
    # Event handlers
    # ------------------------------------------------------------------

    def on_text_message_received(self, event: TextMessageReceived) -> None:
        try:
            event.stop()
            prefix = self._resolve_incoming_prefix(event)
            self._last_prefix = prefix
            view = self.query_one("#message-view", MessageView)
            view.append_message(prefix=prefix, text=event.text, rx_time=event.rx_time)
            try:
                self.query_one(ComposeBar).set_prefix(prefix)
            except Exception:
                pass
            self._write_message(
                event.from_id,
                event.to_id,
                event.channel,
                event.text,
                event.rx_time,
                False,
                event.packet_id,
                prefix,
            )
        except Exception:
            pass

    def on_compose_bar_send_requested(self, event: ComposeBar.SendRequested) -> None:
        try:
            event.stop()
            transport = self.app.transport
            if transport is None or not transport.is_connected:
                return
            channel_idx, dest_id = self._resolve_send_destination(event.prefix)
            try:
                if dest_id == "^all":
                    transport.send_text(event.text, channel=channel_idx or 0)
                else:
                    transport.send_text(event.text, destination=dest_id, channel=0)
            except Exception:
                return
            now = int(time.time())
            view = self.query_one("#message-view", MessageView)
            view.append_message(prefix=event.prefix, text=event.text, rx_time=now, is_mine=True)
            self._write_message(
                "me",
                dest_id,
                channel_idx if channel_idx is not None else 0,
                event.text,
                now,
                True,
                None,
                event.prefix,
            )
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Workers
    # ------------------------------------------------------------------

    @work(thread=True, name="load-history", exit_on_error=False)
    def _load_history(self) -> None:
        rows = self.app.db.get_messages(limit=200)
        self.app.call_from_thread(self._apply_history, rows)

    def _apply_history(self, rows: list) -> None:
        view = self.query_one("#message-view", MessageView)
        view.load_messages(rows)

    @work(thread=True, name="write-message", exit_on_error=False)
    def _write_message(
        self,
        from_id: str,
        to_id: str,
        channel: int,
        text: str,
        rx_time: int,
        is_mine: bool,
        packet_id: str | None = None,
        display_prefix: str = "",
    ) -> None:
        self.app.db.insert_message(
            from_id, to_id, channel, text, rx_time, is_mine, packet_id, display_prefix
        )
