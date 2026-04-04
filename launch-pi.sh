#!/usr/bin/env bash
# launch-pi.sh — MeshTTY launcher for Raspberry Pi
#
# On the framebuffer console (physical screen, not SSH) this script detects
# the display resolution and loads the largest Terminus font that still fits
# at least 80 columns, so the UI fills the screen at a readable size.
#
# Font selection (Terminus naming: {height}x{width} in pixels):
#   screen ≥ 1280 px wide → Terminus32x16  (80 cols at 1280, ~85 at 1366)
#   screen ≥ 1120 px wide → Terminus28x14
#   screen ≥  960 px wide → Terminus24x12
#   screen ≥  880 px wide → Terminus22x11
#   screen ≥  800 px wide → Terminus20x10  (Pi 7" official touchscreen)
#   screen ≥  640 px wide → Terminus16     (640×480 and similar)
#   screen ≥  480 px wide → Terminus12x6   (small 3.5" TFT displays)
#   smaller / unknown     → no font change
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

_in_ssh()  { [ -n "${SSH_CLIENT:-}" ] || [ -n "${SSH_TTY:-}" ]; }
_in_gui()  { [ -n "${DISPLAY:-}" ]    || [ -n "${WAYLAND_DISPLAY:-}" ]; }

if ! _in_ssh && ! _in_gui && [ "${TERM:-}" = "linux" ]; then

    # ── Detect framebuffer width ──────────────────────────────────────────────
    FB_WIDTH=0

    # sysfs: /sys/class/graphics/fb0/virtual_size → "WIDTHxHEIGHT" or "WIDTH,HEIGHT"
    if [ -r /sys/class/graphics/fb0/virtual_size ]; then
        _vsz=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null || true)
        # Strip everything from the first separator onward
        FB_WIDTH="${_vsz%%[x,]*}"
    fi

    # Fall back to fbset if sysfs gave nothing useful
    if [ "${FB_WIDTH:-0}" -lt 100 ] && command -v fbset >/dev/null 2>&1; then
        FB_WIDTH=$(fbset -s 2>/dev/null | awk '/geometry/ {print $2; exit}') || FB_WIDTH=0
    fi

    # ── Select font: largest Terminus that still gives ≥ 80 columns ──────────
    # char_width = screen_width / 80; pick the largest font ≤ that width
    FONT_NAME=""
    if   [ "${FB_WIDTH:-0}" -ge 1280 ]; then FONT_NAME="Terminus32x16"
    elif [ "${FB_WIDTH:-0}" -ge 1120 ]; then FONT_NAME="Terminus28x14"
    elif [ "${FB_WIDTH:-0}" -ge  960 ]; then FONT_NAME="Terminus24x12"
    elif [ "${FB_WIDTH:-0}" -ge  880 ]; then FONT_NAME="Terminus22x11"
    elif [ "${FB_WIDTH:-0}" -ge  800 ]; then FONT_NAME="Terminus20x10"
    elif [ "${FB_WIDTH:-0}" -ge  640 ]; then FONT_NAME="Terminus16"
    elif [ "${FB_WIDTH:-0}" -ge  480 ]; then FONT_NAME="Terminus12x6"
    fi

    if [ -n "$FONT_NAME" ]; then
        # Each size ships as Uni3 (fullest coverage), Uni2, or bare variant
        for f in \
            "/usr/share/consolefonts/Uni3-${FONT_NAME}.psf.gz" \
            "/usr/share/consolefonts/Uni2-${FONT_NAME}.psf.gz" \
            "/usr/share/consolefonts/${FONT_NAME}.psf.gz"; \
        do
            if [ -f "$f" ]; then
                setfont "$f" 2>/dev/null && break || true
            fi
        done
    fi
fi

# ── Ensure a capable TERM ─────────────────────────────────────────────────────

if [ "${TERM:-}" = "linux" ] || [ "${TERM:-}" = "dumb" ] || [ -z "${TERM:-}" ]; then
    export TERM=xterm-256color
fi

# ── Launch ────────────────────────────────────────────────────────────────────

exec "$START_SCRIPT" "$@"
