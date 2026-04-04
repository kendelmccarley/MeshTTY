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
    variables={"text-muted": "#445566"},
)

# ── VT220-Amber — true amber monochrome on black ───────────────────────────────
THEME_AMBER = Theme(
    name="vt220-amber",
    dark=True,
    background="#000000",
    surface="#080400",
    panel="#100800",
    primary="#ff8100",
    secondary="#cc6600",
    accent="#ffb347",
    success="#ffa040",
    warning="#cc5500",
    error="#ff3300",
    variables={"text-muted": "#7a3c00"},
)

# ── VT220-Green — true green monochrome on black ──────────────────────────────
THEME_PHOSPHOR = Theme(
    name="vt220-green",
    dark=True,
    background="#000000",
    surface="#000a02",
    panel="#001404",
    primary="#0ccc68",
    secondary="#08994e",
    accent="#33ff88",
    success="#00cc55",
    warning="#089940",
    error="#005522",
    variables={"text-muted": "#0a5530"},
)

# ── VT220-White — true grey/white monochrome on black ─────────────────────────
THEME_IBM = Theme(
    name="vt220-white",
    dark=True,
    background="#000000",
    surface="#0a0a0a",
    panel="#141414",
    primary="#c0c0c0",
    secondary="#888888",
    accent="#ffffff",
    success="#aaaaaa",
    warning="#666666",
    error="#444444",
    variables={"text-muted": "#555555"},
)

ALL_THEMES = [THEME_VT340, THEME_AMBER, THEME_PHOSPHOR, THEME_IBM]
