"""ChannelList — sidebar list of mesh channels."""

from __future__ import annotations

from textual.app import ComposeResult
from textual.message import Message
from textual.widget import Widget
from textual.widgets import Label, ListView, ListItem


class ChannelList(Widget):
    """Displays channels 0–7 and fires ChannelSelected on click."""

    class ChannelSelected(Message):
        def __init__(self, channel_index: int) -> None:
            self.channel_index = channel_index
            super().__init__()

    DEFAULT_CSS = """
    ChannelList {
        width: 18;
        height: 1fr;
        border-right: solid $primary;
        background: $panel;
    }
    ChannelList Label {
        padding: 0 1;
        color: $text-muted;
    }
    ChannelList ListView {
        height: 1fr;
    }
    """

    NUM_CHANNELS = 8

    def compose(self) -> ComposeResult:
        yield Label("Channels")
        items = [
            ListItem(Label(f"  Ch {i}"), id=f"ch-{i}")
            for i in range(self.NUM_CHANNELS)
        ]
        yield ListView(*items, id="channel-listview")

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        item_id = event.item.id or ""
        if item_id.startswith("ch-"):
            try:
                ch = int(item_id.split("-")[1])
                self.post_message(self.ChannelSelected(ch))
            except (IndexError, ValueError):
                pass
