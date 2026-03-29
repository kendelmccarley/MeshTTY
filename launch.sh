#!/usr/bin/env bash
# launch.sh — Launch MeshTTY
#
# Automatically uses cool-retro-term if it is installed, otherwise falls
# back to the plain terminal launcher.
#
# Usage: ./launch.sh [meshtty flags]
#   ./launch.sh
#   ./launch.sh --bot
#   ./launch.sh --plain      # force plain terminal even if CRT is installed
#   ./launch.sh --crt        # force cool-retro-term (errors if not installed)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Parse launch.sh-specific flags (strip before passing to meshtty) ──────────

FORCE_PLAIN=false
FORCE_CRT=false
PASSTHROUGH_ARGS=()

for arg in "$@"; do
    case "$arg" in
        --plain) FORCE_PLAIN=true ;;
        --crt)   FORCE_CRT=true ;;
        *)       PASSTHROUGH_ARGS+=("$arg") ;;
    esac
done

# ── Preflight ─────────────────────────────────────────────────────────────────

if [ ! -f "$SCRIPT_DIR/meshtty.sh" ]; then
    echo "ERROR: meshtty.sh not found. Run install.sh first." >&2
    exit 1
fi

# ── Detect cool-retro-term ────────────────────────────────────────────────────

_crt_available() {
    command -v cool-retro-term &>/dev/null \
    || [ -x "/Applications/cool-retro-term.app/Contents/MacOS/cool-retro-term" ] \
    || [ -x "$HOME/Applications/cool-retro-term.app/Contents/MacOS/cool-retro-term" ]
}

# ── Choose launcher ───────────────────────────────────────────────────────────

if $FORCE_PLAIN; then
    exec "$SCRIPT_DIR/meshtty.sh" "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
fi

if $FORCE_CRT; then
    if ! _crt_available; then
        echo "ERROR: cool-retro-term not found. Install it or run without --crt." >&2
        echo "" >&2
        echo "  macOS:  brew install --cask cool-retro-term" >&2
        echo "  Linux:  sudo apt install cool-retro-term" >&2
        exit 1
    fi
    exec "$SCRIPT_DIR/meshtty-crt.sh" "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
fi

# Auto-detect: prefer cool-retro-term when available
if _crt_available; then
    exec "$SCRIPT_DIR/meshtty-crt.sh" "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
else
    exec "$SCRIPT_DIR/meshtty.sh" "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
fi
