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
#   The same firmware and library work fine on Python 3.11/3.12.
#
# What this script does:
#   Step 1 — Try protobuf 4.x in the existing venv (quick)
#   Step 2 — Rebuild the venv with Python 3.11 or 3.12 (if available)
#   Step 3 — Try older meshtastic 2.5.x (last resort, if no older Python available)
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

_rebuild_venv() {
    local pybin="$1"
    echo "    Rebuilding $VENV_DIR with $($pybin --version)..."
    deactivate 2>/dev/null || true
    "$pybin" -m venv "$VENV_DIR" --clear
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip --quiet

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
    echo "    Python:     $(python --version)"
    echo "    meshtastic: $(pip show meshtastic 2>/dev/null | grep ^Version | awk '{print $2}' || echo 'unknown')"
    echo "    protobuf:   $(pip show protobuf  2>/dev/null | grep ^Version | awk '{print $2}' || echo 'unknown')"
}

_done_ok() {
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║           Fix succeeded — done!          ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "  Launch MeshTTY:  $SCRIPT_DIR/launch-pi.sh"
    echo ""
    exit 0
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

# ── Step 1: Try protobuf 4.x in existing venv ────────────────────────────────

echo ">>> [1/3] Trying protobuf 4.x in existing venv..."
pip install --quiet "protobuf==4.25.3"
echo "    protobuf: $(pip show protobuf | grep ^Version | awk '{print $2}')"

if [ -n "$RADIO_PORT" ]; then
    _radio_test "$RADIO_PORT" && _done_ok
else
    echo "    Skipping radio test (no port)."
fi

# ── Step 2: Rebuild with Python 3.11 or 3.12 ─────────────────────────────────

echo ""
echo ">>> [2/3] Looking for Python 3.11 or 3.12..."

OLDER_PY=""
for pyver in python3.11 python3.12; do
    if command -v "$pyver" &>/dev/null; then
        OLDER_PY="$pyver"
        echo "    Found: $($pyver --version)"
        break
    fi
done

if [ -z "$OLDER_PY" ]; then
    echo "    Not in PATH — trying apt..."
    for pkg in python3.11 python3.12; do
        if sudo apt-get install -y "$pkg" "${pkg}-venv" "${pkg}-dev" 2>/dev/null; then
            OLDER_PY="${pkg/python/python}"   # e.g. python3.11
            # normalise: pkg is already "python3.11"
            OLDER_PY="$pkg"
            command -v "$OLDER_PY" &>/dev/null && break || OLDER_PY=""
        fi
    done
fi

if [ -n "$OLDER_PY" ]; then
    _rebuild_venv "$OLDER_PY"
    if [ -n "$RADIO_PORT" ]; then
        _radio_test "$RADIO_PORT" && _done_ok
    else
        echo ""
        echo "    Venv rebuilt. Test manually:"
        echo "      meshtastic --port /dev/ttyUSB0 --info"
        _done_ok
    fi
else
    echo "    python3.11/3.12 not available via apt on this OS."
fi

# ── Step 3: Try older meshtastic 2.5.x (Python 3.13 last resort) ─────────────

echo ""
echo ">>> [3/3] Trying meshtastic 2.5.x with Python 3.13 (last resort)..."
echo "    (Older library, known stable with protobuf 4.x)"

source "$VENV_DIR/bin/activate"
pip install --quiet "meshtastic==2.5.7" "protobuf==4.25.3"
echo "    meshtastic: $(pip show meshtastic | grep ^Version | awk '{print $2}')"
echo "    protobuf:   $(pip show protobuf  | grep ^Version | awk '{print $2}')"

if [ -n "$RADIO_PORT" ]; then
    if _radio_test "$RADIO_PORT"; then
        echo ""
        echo "  NOTE: MeshTTY is pinned to meshtastic 2.5.7."
        echo "  It will work but may lack features of newer firmware."
        _done_ok
    fi
fi

# ── All steps failed ──────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║        All automatic fixes failed        ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Diagnostics:"
echo "    cat /tmp/meshtty-radio-test.log"
echo ""
echo "  Manual options:"
echo "  A) Downgrade radio firmware to 2.5.x:"
echo "     Use Meshtastic flasher at https://flasher.meshtastic.org"
echo ""
echo "  B) Install Python 3.11 via pyenv (slow on Pi Zero W ~1 hr):"
echo "     curl https://pyenv.run | bash"
echo "     pyenv install 3.11"
echo "     pyenv global 3.11"
echo "     bash $SCRIPT_DIR/install-pi.sh"
echo ""
