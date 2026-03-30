"""TerminalFrame — draws a classic 80×24-style box-drawing border.

The frame is rendered entirely with Unicode box-drawing characters so it
looks like a classic terminal application regardless of the host terminal's
font or renderer.  Content widgets sit on the "content" layer inside the
frame area with transparent backgrounds.

Divider rows can be registered at specific percentages of the inner height
(e.g. 0.75 for a horizontal rule at 75% down) and are drawn with ╠═╣.
"""

from __future__ import annotations

from textual.app import RenderResult
from textual.strip import Strip
from textual.widget import Widget
from rich.segment import Segment
from rich.style import Style


# Box-drawing character sets
_H  = "═"   # horizontal
_V  = "║"   # vertical
_TL = "╔"   # top-left
_TR = "╗"   # top-right
_BL = "╚"   # bottom-left
_BR = "╝"   # bottom-right
_LT = "╠"   # left T (divider)
_RT = "╣"   # right T (divider)
_SP = " "   # space


class TerminalFrame(Widget):
    """Renders a box-drawing frame around its area.

    Place content widgets (with ``background: transparent``) inside this
    widget using layers so they appear within the frame.

    Parameters
    ----------
    title:
        Short string centred in the top border.
    dividers:
        Sequence of row offsets (0-based, counting from the first inner row)
        at which to draw ╠═╣ horizontal rules.
    """

    DEFAULT_CSS = """
    TerminalFrame {
        width: 100%;
        height: 100%;
        background: $background;
        layer: frame;
    }
    """

    def __init__(
        self,
        title: str = "",
        dividers: list[int] | None = None,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._title = title
        self._dividers: set[int] = set(dividers or [])

    # ------------------------------------------------------------------
    # Rendering
    # ------------------------------------------------------------------

    def render_line(self, y: int) -> Strip:
        width = self.size.width
        height = self.size.height

        # Guard against zero-size renders during startup
        if width < 2 or height < 2:
            return Strip([])

        # Inner width (between the two vertical bars)
        inner_w = width - 2

        color = self.app.get_css_variables().get("primary", "#00ff00")
        style = Style.parse(color)

        def _hbar(left: str, right: str) -> Strip:
            """Full-width horizontal bar with given corner characters."""
            bar = left + _H * inner_w + right
            return Strip([Segment(bar, style)])

        last = height - 1

        if y == 0:
            # Top border: ╔══[ TITLE ]══╗
            if self._title:
                label = f"[ {self._title} ]"
                pad = max(0, inner_w - len(label))
                left_pad = pad // 2
                right_pad = pad - left_pad
                bar = _TL + _H * left_pad + label + _H * right_pad + _TR
            else:
                bar = _TL + _H * inner_w + _TR
            return Strip([Segment(bar, style)])

        if y == last:
            return _hbar(_BL, _BR)

        inner_y = y - 1  # 0-based row inside the frame
        if inner_y in self._dividers:
            return _hbar(_LT, _RT)

        # Normal interior row: ║<spaces>║
        return Strip([Segment(_V + _SP * inner_w + _V, style)])

    def get_content_width(self, container, viewport) -> int:  # noqa: ANN001
        return self.size.width

    def get_content_height(self, container, viewport, width) -> int:  # noqa: ANN001
        return self.size.height
