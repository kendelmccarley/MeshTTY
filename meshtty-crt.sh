#!/usr/bin/env bash
# meshtty-crt.sh — launch MeshTTY inside cool-retro-term
#
# Usage: ./meshtty-crt.sh [meshtty flags]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
START_SCRIPT="$SCRIPT_DIR/meshtty.sh"

if [ ! -f "$START_SCRIPT" ]; then
    echo "ERROR: meshtty.sh not found. Run install.sh first." >&2
    exit 1
fi

# ── Find cool-retro-term ──────────────────────────────────────────────────────

CRT_BIN=""

# Linux / PATH
if command -v cool-retro-term &>/dev/null; then
    CRT_BIN="cool-retro-term"
fi

# macOS app bundles
if [ -z "$CRT_BIN" ]; then
    for app_path in \
        "/Applications/cool-retro-term.app/Contents/MacOS/cool-retro-term" \
        "$HOME/Applications/cool-retro-term.app/Contents/MacOS/cool-retro-term"
    do
        if [ -x "$app_path" ]; then
            CRT_BIN="$app_path"
            break
        fi
    done
fi

# Flatpak wrapper
if [ -z "$CRT_BIN" ] && [ -x "$HOME/.local/bin/cool-retro-term" ]; then
    CRT_BIN="$HOME/.local/bin/cool-retro-term"
fi

if [ -z "$CRT_BIN" ]; then
    echo "ERROR: cool-retro-term not found." >&2
    echo "" >&2
    echo "  macOS:  brew install --cask cool-retro-term" >&2
    echo "  Linux:  sudo apt install cool-retro-term" >&2
    exit 1
fi

# ── Launch ────────────────────────────────────────────────────────────────────

exec "$CRT_BIN" -e "$START_SCRIPT" "$@"
