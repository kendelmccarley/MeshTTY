from textual.theme import Theme

# ── VT340 — DEC VT340 multicolor (default) ────────────────────────────────────
THEME_VT340 = Theme(
    name="vt340",
    dark=True,
    background="#000000",
    surface="#0a0a12",
    panel="#14141e",
    primary="#00aaff",
    secondary="#0077cc",
    accent="#66ccff",
    success="#00cc66",
    warning="#ffaa00",
    error="#ff3333",
    variables={
        "text-muted": "#445566",
        "scrollbar": "#0077cc",
        "scrollbar-hover": "#00aaff",
        "scrollbar-active": "#66ccff",
        "scrollbar-background": "#000000",
        "scrollbar-corner-color": "#000000",
    },
)

# ── VT220-Amber — true amber monochrome on black ───────────────────────────────
# foreground= tells Textual to derive $text / $text-muted / $text-disabled
# from amber rather than its default computed grey.
THEME_AMBER = Theme(
    name="vt220-amber",
    dark=True,
    background="#000000",
    surface="#080400",
    panel="#100800",
    foreground="#ff8100",
    primary="#ff8100",
    secondary="#cc6600",
    accent="#ffb347",
    success="#ffa040",
    warning="#cc5500",
    error="#ff5500",
    variables={
        "text-muted": "#7a3c00",
        "text-disabled": "#995500",
        "scrollbar": "#cc6600",
        "scrollbar-hover": "#ff8100",
        "scrollbar-active": "#ffb347",
        "scrollbar-background": "#000000",
        "scrollbar-corner-color": "#000000",
    },
)

# ── VT220-Green — true green monochrome on black ──────────────────────────────
THEME_PHOSPHOR = Theme(
    name="vt220-green",
    dark=True,
    background="#000000",   # pure black — VT320 bezel/off pixels
    surface="#010801",      # barely-there green tint behind content
    panel="#011001",        # slightly brighter for panels
    foreground="#2EE62E",   # P39 phosphor green (525 nm peak) — drives $text
    primary="#2EE62E",      # P39 phosphor green (525 nm peak)
    secondary="#1DB31D",    # mid-brightness phosphor
    accent="#57FF57",       # highlight / cursor glow
    success="#2EE62E",      # same phosphor for success
    warning="#C8E600",      # yellow-green — phosphor pushed warm
    error="#FF2200",        # red stays red (OSD-style alarm)
    variables={
        "text-muted": "#155915",   # dim phosphor for labels/hints
        "text-disabled": "#0d3d0d",
        "scrollbar": "#1DB31D",
        "scrollbar-hover": "#2EE62E",
        "scrollbar-active": "#57FF57",
        "scrollbar-background": "#000000",
        "scrollbar-corner-color": "#000000",
    },
)

# ── VT220-White — true grey/white monochrome on black ─────────────────────────
THEME_IBM = Theme(
    name="vt220-white",
    dark=True,
    background="#000000",
    surface="#0a0a0a",
    panel="#141414",
    foreground="#c0c0c0",
    primary="#c0c0c0",
    secondary="#888888",
    accent="#ffffff",
    success="#aaaaaa",
    warning="#999999",
    error="#ffffff",
    variables={
        "text-muted": "#555555",
        "text-disabled": "#777777",
        "scrollbar": "#888888",
        "scrollbar-hover": "#c0c0c0",
        "scrollbar-active": "#ffffff",
        "scrollbar-background": "#000000",
        "scrollbar-corner-color": "#000000",
    },
)

ALL_THEMES = [THEME_VT340, THEME_AMBER, THEME_PHOSPHOR, THEME_IBM]
