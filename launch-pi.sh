#!/usr/bin/env bash
# launch-pi.sh — MeshTTY launcher for Raspberry Pi
#
# On the framebuffer console (physical screen, not SSH) this script tries to
# load a large Terminus font so the 80×24 terminal grid fills the display.
# On 1366×768 a 16×32 font gives roughly 85×24 characters.
#
# Usage: ./launch-pi.sh [meshtty flags, e.g. --bot --log]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
START_SCRIPT="$SCRIPT_DIR/meshtty.sh"

if [ ! -f "$START_SCRIPT" ]; then
    echo "ERROR: meshtty.sh not found. Run install-pi.sh first." >&2
    exit 1
fi

# ── Framebuffer font scaling ──────────────────────────────────────────────────
# Only attempt on the Linux framebuffer console (not SSH, not X/Wayland).
# A large font makes each character cell bigger so 80 columns fills the screen.

_in_ssh()  { [ -n "${SSH_CLIENT:-}" ] || [ -n "${SSH_TTY:-}" ]; }
_in_gui()  { [ -n "${DISPLAY:-}" ]    || [ -n "${WAYLAND_DISPLAY:-}" ]; }

if ! _in_ssh && ! _in_gui && [ "$TERM" = "linux" ]; then
    # Terminus 16×32 — widest/tallest Terminus variant shipped by console-setup
    FONT_CANDIDATES=(
        /usr/share/consolefonts/Uni3-Terminus32x16.psf.gz
        /usr/share/consolefonts/Uni2-Terminus32x16.psf.gz
        /usr/share/consolefonts/Terminus32x16.psf.gz
    )
    for f in "${FONT_CANDIDATES[@]}"; do
        if [ -f "$f" ]; then
            setfont "$f" 2>/dev/null && break || true
        fi
    done
fi

# ── Ensure a capable TERM ─────────────────────────────────────────────────────

if [ "$TERM" = "linux" ] || [ "$TERM" = "dumb" ] || [ -z "$TERM" ]; then
    export TERM=xterm-256color
fi

# ── Launch ────────────────────────────────────────────────────────────────────

exec "$START_SCRIPT" "$@"
