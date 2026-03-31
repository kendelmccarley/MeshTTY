"""MessagesView — unified message history + compose bar."""

from __future__ import annotations

import time

from textual import work
from textual.app import ComposeResult
from textual.events import Key
from textual.widget import Widget

from meshtty.messages.app_messages import TextMessageReceived
from meshtty.widgets.compose_bar import ComposeBar, PrefixSelector
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
        self._conversations: list[str] = []
        self._conv_index: int = 0

    def compose(self) -> ComposeResult:
        yield MessageView(id="message-view")
        yield ComposeBar()

    def on_mount(self) -> None:
        self._refresh_conversations()
        self._load_history()

    def on_show(self) -> None:
        """Re-focus compose input whenever the Messages tab becomes active."""
        try:
            self.query_one("#compose-input").focus()
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Conversation list helpers
    # ------------------------------------------------------------------

    def _build_conversations(self) -> list[str]:
        """Return conversation prefixes ordered by most recent activity.

        List contains channel names (for broadcast) and node short names (for DMs),
        all sorted by the most recent message time so the most active appears first.
        """
        prefix_times: dict[str, int] = {}
        transport = self.app.transport
        nodes = transport.get_nodes() if transport else {}

        def _short(node_id: str) -> str:
            node = nodes.get(node_id) or {}
            user = (node.get("user") or {})
            short = user.get("shortName", "").strip()
            return short if short else node_id

        # Channels — always included; seed with last message time from DB
        try:
            chan_times = self.app.db.get_channel_last_times()
        except Exception:
            chan_times = {}
        for idx, name in (transport.get_channels() if transport else [(0, "Primary")]):
            prefix_times[name] = chan_times.get(idx, 0)

        # DM nodes — resolved to short names, sorted by last message time
        try:
            dm_nodes = self.app.db.get_dm_nodes()
        except Exception:
            dm_nodes = []
        for node_id, last_time in dm_nodes:
            display = _short(node_id)
            if last_time > prefix_times.get(display, -1):
                prefix_times[display] = last_time

        if not prefix_times:
            return ["Primary"]

        return sorted(prefix_times, key=lambda p: prefix_times[p], reverse=True)

    def _refresh_conversations(self) -> None:
        """Rebuild the conversation list, keeping the current prefix selected."""
        new_list = self._build_conversations()
        self._conversations = new_list
        current = self._last_prefix
        if current in new_list:
            self._conv_index = new_list.index(current)
        else:
            self._conv_index = 0
        if new_list:
            prefix = new_list[self._conv_index]
            self._last_prefix = prefix
            try:
                self.query_one(ComposeBar).set_prefix(prefix)
            except Exception:
                pass

    def _cycle_conversation(self, delta: int) -> None:
        if not self._conversations:
            return
        self._conv_index = (self._conv_index + delta) % len(self._conversations)
        prefix = self._conversations[self._conv_index]
        self._last_prefix = prefix
        try:
            self.query_one(ComposeBar).set_prefix(prefix)
        except Exception:
            pass

    # Focus order: MessageView → PrefixSelector → compose Input → (wraps)
    _FOCUS_IDS = ["message-view", "prefix-selector", "compose-input"]

    def _focus_widgets(self) -> list:
        widgets = []
        for wid in self._FOCUS_IDS:
            try:
                widgets.append(self.query_one(f"#{wid}"))
            except Exception:
                pass
        return widgets

    def _move_focus(self, delta: int) -> None:
        order = self._focus_widgets()
        if not order:
            return
        focused = self.app.focused
        try:
            idx = order.index(focused)
        except ValueError:
            idx = -1 if delta > 0 else 0
        order[(idx + delta) % len(order)].focus()

    def on_key(self, event: Key) -> None:
        """Tab/Shift-Tab cycle focus; PageUp/PageDown always scroll."""
        if event.key == "tab":
            self._move_focus(1)
            event.stop()
            return
        if event.key == "shift+tab":
            self._move_focus(-1)
            event.stop()
            return
        # PageUp/PageDown always scroll regardless of focus
        if event.key in ("pageup", "pagedown"):
            try:
                view = self.query_one("#message-view", MessageView)
                if event.key == "pageup":
                    view.scroll_page_up(animate=False)
                else:
                    view.scroll_page_down(animate=False)
                event.stop()
            except Exception:
                pass

    def on_prefix_selector_cycle_request(self, event: PrefixSelector.CycleRequest) -> None:
        event.stop()
        self._cycle_conversation(event.delta)

    # ------------------------------------------------------------------
    # Prefix resolution helpers
    # ------------------------------------------------------------------

    def _resolve_incoming_prefix(self, event: TextMessageReceived) -> str:
        """Return the sender's short name for display.

        Always shows who sent the message. For channel messages this means
        you see the sender's node name, not the channel name. The channel
        index is preserved in the DB 'channel' column for conversation routing.
        """
        transport = self.app.transport
        if transport:
            nodes = transport.get_nodes()
            node = nodes.get(event.from_id) or {}
            user = (node.get("user") or {})
            short = user.get("shortName", "").strip()
            if short:
                return short
        # Fallback: trim the node ID to something readable
        fid = event.from_id or "?"
        return fid[-8:] if len(fid) > 8 else fid

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

    def _log(self, direction: str, prefix: str, text: str) -> None:
        """Write one entry to the message log if --log is active."""
        ml = getattr(self.app, "message_log", None)
        if ml is not None:
            ml.log(direction, prefix, text)

    # ------------------------------------------------------------------
    # Event handlers
    # ------------------------------------------------------------------

    def on_text_message_received(self, event: TextMessageReceived) -> None:
        try:
            event.stop()
            text = event.text or ""
            is_dm = event.to_id != "^all"

            # Slash-command handling: only for DMs starting with "/"
            if is_dm and text.strip().startswith("/"):
                handler = getattr(self.app, "command_handler", None)
                if handler is not None:
                    reply = handler.handle(text.strip())
                    if reply is None:
                        # Unknown command — silently drop
                        return
                    # Valid command: display the incoming command message
                    prefix = self._resolve_incoming_prefix(event)
                    view = self.query_one("#message-view", MessageView)
                    view.append_message(prefix=prefix, text=text, rx_time=event.rx_time)
                    self._write_message(
                        event.from_id, event.to_id, event.channel,
                        text, event.rx_time, False, event.packet_id, prefix,
                    )
                    self._log("RX", prefix, text)
                    # Send reply back to sender and display it
                    transport = self.app.transport
                    if transport and transport.is_connected:
                        try:
                            transport.send_text(reply, destination=event.from_id, channel=0)
                        except Exception:
                            pass
                    now = int(time.time())
                    view.append_message(prefix=prefix, text=reply, rx_time=now, is_mine=True)
                    self._write_message(
                        "me", event.from_id, 0,
                        reply, now, True, None, prefix,
                    )
                    self._log("TX", prefix, reply)
                    return

            # Normal message handling
            prefix = self._resolve_incoming_prefix(event)
            self._last_prefix = prefix
            view = self.query_one("#message-view", MessageView)
            view.append_message(prefix=prefix, text=event.text, rx_time=event.rx_time)
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
            self._log("RX", prefix, event.text)
            # Rebuild conversation list so new sender appears at the top
            self._refresh_conversations()
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
            self._log("TX", event.prefix, event.text)
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
