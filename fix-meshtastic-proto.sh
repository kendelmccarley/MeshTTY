#!/usr/bin/env bash
# fix-meshtastic-proto.sh — Fix protobuf DecodeError when connecting to radio
#
# Symptoms:
#   google.protobuf.message.DecodeError: Error parsing message with type
#   'meshtastic.protobuf.FromRadio'
#   MeshInterfaceError: Timed out waiting for connection completion
#
# Cause:
#   The released meshtastic Python library (2.7.8) has proto definitions that
#   lag behind newer firmware (2.7.15+).  Installing from the git main branch
#   picks up the latest generated protobuf files.
#
# Usage:
#   bash fix-meshtastic-proto.sh [/dev/ttyUSB0]
#   bash fix-meshtastic-proto.sh              # skips radio test

set -euo pipefail

VENV_DIR="$HOME/.venv/meshtty"
RADIO_PORT="${1:-}"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     MeshTTY — Fix Meshtastic Proto       ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Preflight ─────────────────────────────────────────────────────────────────

if [ ! -f "$VENV_DIR/bin/activate" ]; then
    echo "ERROR: Virtualenv not found at $VENV_DIR"
    echo "Run install-pi.sh first."
    exit 1
fi

if ! command -v git &>/dev/null; then
    echo ">>> Installing git..."
    sudo apt-get install -y git
fi

source "$VENV_DIR/bin/activate"

echo ">>> Current versions:"
echo "    Python:     $(python --version)"
echo "    meshtastic: $(pip show meshtastic | grep ^Version | awk '{print $2}')"
echo "    protobuf:   $(pip show protobuf  | grep ^Version | awk '{print $2}')"
echo ""

# ── Step 1: Install meshtastic from git main (latest proto definitions) ───────

echo ">>> Installing meshtastic from GitHub main branch..."
pip install --quiet \
    "git+https://github.com/meshtastic/python.git" \
    --force-reinstall

echo "    meshtastic: $(pip show meshtastic | grep ^Version | awk '{print $2}')"

# ── Step 2: Pin protobuf to a compatible range ────────────────────────────────

echo ""
echo ">>> Pinning protobuf to <6.0..."
pip install --quiet "protobuf>=4.21.12,<6.0"
echo "    protobuf:   $(pip show protobuf | grep ^Version | awk '{print $2}')"

# ── Step 3: Verify imports ────────────────────────────────────────────────────

echo ""
echo ">>> Verifying imports..."
python -c "import meshtastic; print('    OK: meshtastic', meshtastic.__version__)"
python -c "import google.protobuf; print('    OK: protobuf', google.protobuf.__version__)"

# ── Step 4: Optional radio connection test ────────────────────────────────────

if [ -n "$RADIO_PORT" ]; then
    echo ""
    echo ">>> Testing radio connection on $RADIO_PORT..."
    if meshtastic --port "$RADIO_PORT" --info; then
        echo ""
        echo "    Radio connection OK."
    else
        echo ""
        echo "    Radio test failed — see output above."
        echo "    If you still see DecodeError, the firmware may need downgrading"
        echo "    to align with the Python library, or wait for a library update."
    fi
else
    echo ""
    echo "    Skipping radio test (no port given)."
    echo "    To test:  meshtastic --port /dev/ttyUSB0 --info"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║               Fix complete               ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  If the radio test passed, launch MeshTTY:"
echo "    ~/MeshTTY/launch-pi.sh"
echo ""
