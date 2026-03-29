#!/usr/bin/env bash
# launch-pi.sh — MeshTTY launcher for Raspberry Pi
#
# Detects the runtime context and chooses the right launch method:
#
#   SSH session          → plain terminal (meshtty.sh)
#   X already running    → cool-retro-term fullscreen (if installed)
#                          falls back to plain terminal
#   tty, X available     → start X → openbox → cool-retro-term fullscreen
#   tty, no X            → plain terminal (meshtty.sh)
#
# Usage: ./launch-pi.sh [meshtty flags, e.g. --bot --log]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
START_SCRIPT="$SCRIPT_DIR/meshtty.sh"

if [ ! -f "$START_SCRIPT" ]; then
    echo "ERROR: meshtty.sh not found. Run install-pi.sh first." >&2
    exit 1
fi

# ── Detection helpers ─────────────────────────────────────────────────────────

_in_ssh()  { [ -n "${SSH_CLIENT:-}" ] || [ -n "${SSH_TTY:-}" ]; }
_in_x()    { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }
_has_x()   { command -v Xorg &>/dev/null || command -v X &>/dev/null; }
_has_crt() {
    command -v cool-retro-term &>/dev/null \
    || [ -x "$HOME/.local/bin/cool-retro-term" ]
}
_has_openbox() { command -v openbox &>/dev/null; }

# ── SSH: always plain terminal ────────────────────────────────────────────────

if _in_ssh; then
    exec "$START_SCRIPT" "$@"
fi

# ── Already inside an X session ───────────────────────────────────────────────

if _in_x; then
    if _has_crt; then
        # cool-retro-term handles fullscreen via openbox rc.xml rule installed
        # by install-pi.sh.  Pass meshtty.sh as the inner command.
        exec cool-retro-term -e "$START_SCRIPT"
    else
        exec "$START_SCRIPT" "$@"
    fi
fi

# ── On a tty: start X with cool-retro-term kiosk ─────────────────────────────

if _has_crt && _has_x && _has_openbox; then
    # Sanity-check that install-pi.sh configured the kiosk properly
    if [ ! -f "$HOME/.config/openbox/autostart" ]; then
        echo "WARNING: openbox autostart not found." >&2
        echo "         Re-run install-pi.sh to configure the X kiosk." >&2
        echo "         Falling back to plain terminal." >&2
        exec "$START_SCRIPT" "$@"
    fi

    # Ensure TERM is set for the inner meshtty process
    export TERM=xterm-256color

    # startx launches openbox-session (via ~/.xinitrc), which runs the
    # autostart that opens cool-retro-term fullscreen with meshtty.sh inside.
    # When cool-retro-term exits the autostart calls 'openbox --exit',
    # which causes startx to return here.
    exec startx -- :0 -nolisten tcp 2>/tmp/meshtty-x.log

fi

# ── Fallback: plain terminal ──────────────────────────────────────────────────

exec "$START_SCRIPT" "$@"
