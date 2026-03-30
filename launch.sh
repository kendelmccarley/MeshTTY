#!/usr/bin/env bash
# launch.sh — Launch MeshTTY
#
# Usage: ./launch.sh [meshtty flags]
#   ./launch.sh
#   ./launch.sh --bot

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$SCRIPT_DIR/meshtty.sh" ]; then
    echo "ERROR: meshtty.sh not found. Run install.sh first." >&2
    exit 1
fi

exec "$SCRIPT_DIR/meshtty.sh" "$@"
