from textual.theme import Theme

# ── cool-retro-term: Default Amber ────────────────────────────────────────────
# fontColor: #ff8100  backgroundColor: #000000
THEME_AMBER = Theme(
    name="crt-amber",
    dark=True,
    background="#000000",
    surface="#080400",
    panel="#100800",
    primary="#ff8100",
    secondary="#cc6600",
    accent="#ffb347",
    success="#ffa040",
    warning="#ff6000",
    error="#ff2200",
    variables={"text-muted": "#7a3c00"},
)

# ── cool-retro-term: Monochrome Green ─────────────────────────────────────────
# fontColor: #0ccc68  backgroundColor: #000000
THEME_PHOSPHOR = Theme(
    name="crt-phosphor",
    dark=True,
    background="#000000",
    surface="#000a02",
    panel="#001404",
    primary="#0ccc68",
    secondary="#08994e",
    accent="#33ff88",
    success="#00ff80",
    warning="#99ff33",
    error="#ff3300",
    variables={"text-muted": "#0a5530"},
)

# ── cool-retro-term: IBM VGA 8×16 ─────────────────────────────────────────────
# fontColor: #c0c0c0  backgroundColor: #000000
THEME_IBM = Theme(
    name="crt-ibm",
    dark=True,
    background="#000000",
    surface="#0a0a0a",
    panel="#141414",
    primary="#c0c0c0",
    secondary="#888888",
    accent="#ffffff",
    success="#aaaaaa",
    warning="#888888",
    error="#ff5555",
    variables={"text-muted": "#555555"},
)

ALL_THEMES = [THEME_AMBER, THEME_PHOSPHOR, THEME_IBM]
