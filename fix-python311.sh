#!/usr/bin/env bash
# fix-python311.sh — Fix protobuf DecodeError on Python 3.13 (Pi Zero W / DietPi)
#
# Symptoms:
#   google.protobuf.message.DecodeError: Error parsing message with type
#   'meshtastic.protobuf.FromRadio'
#   MeshInterfaceError: Timed out waiting for connection completion
#
# Root cause:
#   meshtastic 2.7.x has compatibility issues with Python 3.13's protobuf runtime.
#   The same firmware and library work fine on Python 3.11.
#
# What this script does:
#   Step 1 — Try protobuf 4.x in the existing venv (quick fix)
#   Step 2 — If that fails, rebuild the venv with Python 3.11 (full fix)
#
# Usage:
#   bash fix-python311.sh [/dev/ttyUSB0]
#   bash fix-python311.sh              # auto-detects radio port

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$HOME/.venv/meshtty"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     MeshTTY — Fix Python 3.13 Proto      ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Helpers ───────────────────────────────────────────────────────────────────

_radio_test() {
    local port="$1"
    echo "    Testing radio on $port..."
    if timeout 30 meshtastic --port "$port" --info &>/tmp/meshtty-radio-test.log; then
        echo "    PASS: radio responded."
        return 0
    else
        if grep -q "DecodeError\|Timed out" /tmp/meshtty-radio-test.log 2>/dev/null; then
            echo "    FAIL: still getting protobuf errors."
        else
            echo "    FAIL: see /tmp/meshtty-radio-test.log"
        fi
        return 1
    fi
}

_find_port() {
    for p in /dev/ttyUSB0 /dev/ttyUSB1 /dev/ttyACM0 /dev/ttyACM1; do
        [ -e "$p" ] && echo "$p" && return 0
    done
    echo ""
}

# ── Detect radio port ─────────────────────────────────────────────────────────

RADIO_PORT="${1:-}"
if [ -z "$RADIO_PORT" ]; then
    RADIO_PORT="$(_find_port)"
fi

if [ -n "$RADIO_PORT" ]; then
    echo "    Radio port: $RADIO_PORT"
else
    echo "    No radio port found — will skip radio tests."
    echo "    Plug in the radio or pass the port as an argument."
fi
echo ""

# ── Preflight ─────────────────────────────────────────────────────────────────

if [ ! -f "$VENV_DIR/bin/activate" ]; then
    echo "ERROR: Virtualenv not found at $VENV_DIR"
    echo "Run install-pi.sh first."
    exit 1
fi

source "$VENV_DIR/bin/activate"

echo ">>> Current environment:"
echo "    Python:     $(python --version)"
echo "    meshtastic: $(pip show meshtastic 2>/dev/null | grep ^Version | awk '{print $2}' || echo 'unknown')"
echo "    protobuf:   $(pip show protobuf  2>/dev/null | grep ^Version | awk '{print $2}' || echo 'unknown')"
echo ""

# ── Step 1: Try protobuf 4.x ──────────────────────────────────────────────────

echo ">>> [1/2] Trying protobuf 4.x in existing venv..."
pip install --quiet "protobuf==4.25.3"
echo "    protobuf: $(pip show protobuf | grep ^Version | awk '{print $2}')"

STEP1_OK=false
if [ -n "$RADIO_PORT" ]; then
    if _radio_test "$RADIO_PORT"; then
        STEP1_OK=true
    fi
else
    echo "    Skipping radio test (no port)."
    STEP1_OK=false
fi

if $STEP1_OK; then
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║    Fixed with protobuf 4.x — done!       ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "  Launch MeshTTY:  $SCRIPT_DIR/launch-pi.sh"
    echo ""
    exit 0
fi

# ── Step 2: Rebuild venv with Python 3.11 ────────────────────────────────────

echo ""
echo ">>> [2/2] Rebuilding venv with Python 3.11..."

if ! command -v python3.11 &>/dev/null; then
    echo "    python3.11 not found — installing..."
    sudo apt-get install -y python3.11 python3.11-venv python3.11-dev
fi

echo "    Python 3.11: $(python3.11 --version)"
echo "    Rebuilding $VENV_DIR ..."

deactivate 2>/dev/null || true
python3.11 -m venv "$VENV_DIR" --clear
source "$VENV_DIR/bin/activate"

echo "    Active Python: $(python --version)"

pip install --upgrade pip --quiet

echo "    Installing dependencies (this may take a while on Pi Zero W)..."
PIP_LOG="/tmp/meshtty-pip-fix.log"

if ! pip install -r "$SCRIPT_DIR/requirements.txt" --quiet 2>"$PIP_LOG"; then
    if grep -qi "grpcio\|illegal instruction\|build wheel" "$PIP_LOG" 2>/dev/null; then
        echo "    ARMv6: retrying without grpcio..."
        grep -v "^grpcio" "$SCRIPT_DIR/requirements.txt" > /tmp/reqs-fix.txt
        pip install -r /tmp/reqs-fix.txt --quiet \
            || { echo "ERROR: pip install failed. See $PIP_LOG"; cat "$PIP_LOG"; exit 1; }
    else
        echo "ERROR: pip install failed."
        cat "$PIP_LOG"
        exit 1
    fi
fi

pip install -e "$SCRIPT_DIR" --quiet

echo ""
echo "    New environment:"
echo "    Python:     $(python --version)"
echo "    meshtastic: $(pip show meshtastic 2>/dev/null | grep ^Version | awk '{print $2}' || echo 'unknown')"
echo "    protobuf:   $(pip show protobuf  2>/dev/null | grep ^Version | awk '{print $2}' || echo 'unknown')"

# ── Final radio test ──────────────────────────────────────────────────────────

STEP2_OK=false
if [ -n "$RADIO_PORT" ]; then
    echo ""
    if _radio_test "$RADIO_PORT"; then
        STEP2_OK=true
    fi
fi

echo ""
if $STEP2_OK; then
    echo "╔══════════════════════════════════════════╗"
    echo "║    Fixed with Python 3.11 — done!        ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "  Launch MeshTTY:  $SCRIPT_DIR/launch-pi.sh"
else
    echo "╔══════════════════════════════════════════╗"
    echo "║    Venv rebuilt — radio test inconclusive ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    if [ -z "$RADIO_PORT" ]; then
        echo "  Test manually:"
        echo "    source $VENV_DIR/bin/activate"
        echo "    meshtastic --port /dev/ttyUSB0 --info"
    else
        echo "  Radio still failing — check /tmp/meshtty-radio-test.log"
        echo "  The Pi 2B environment that worked may have had a different"
        echo "  meshtastic or protobuf version. Check: pip show meshtastic protobuf"
    fi
fi
echo ""
