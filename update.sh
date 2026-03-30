#!/usr/bin/env bash
# update.sh — Pull the latest MeshTTY from GitHub and refresh dependencies
#
# Usage: bash update.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$HOME/.venv/meshtty"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║           MeshTTY Updater                ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Preflight checks ──────────────────────────────────────────────────────────

if ! command -v git &>/dev/null; then
    echo "ERROR: git is not installed."
    echo "  macOS:  brew install git"
    echo "  Linux:  sudo apt install git"
    exit 1
fi

if [ ! -d "$SCRIPT_DIR/.git" ]; then
    echo "ERROR: $SCRIPT_DIR is not a git repository."
    echo "If you installed MeshTTY by downloading a zip, re-install via git:"
    echo "  git clone https://github.com/kendelmccarley/MeshTTY.git"
    exit 1
fi

if [ ! -f "$VENV_DIR/bin/activate" ]; then
    echo "ERROR: Virtualenv not found at $VENV_DIR"
    echo "Run install.sh first."
    exit 1
fi

cd "$SCRIPT_DIR"

# ── Snapshot current HEAD so we can show a changelog ──────────────────────────

PREV_HEAD="$(git rev-parse HEAD)"

# ── Fetch and hard-reset to remote (flushes local changes and cached state) ───

echo ">>> Fetching updates from GitHub..."
git fetch origin 2>&1 \
    || { echo "ERROR: git fetch failed — check your network."; exit 1; }

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git reset --hard "origin/$BRANCH"
git clean -fd

NEW_HEAD="$(git rev-parse HEAD)"

# ── Show what changed ─────────────────────────────────────────────────────────

if [ "$PREV_HEAD" = "$NEW_HEAD" ]; then
    echo "    Already up to date."
else
    echo ""
    echo ">>> Changes since last update:"
    git log --oneline --no-decorate "${PREV_HEAD}..${NEW_HEAD}"
fi

# ── Refresh Python dependencies if requirements.txt changed ───────────────────

source "$VENV_DIR/bin/activate"

REQS_CHANGED=false
if ! git diff --quiet "${PREV_HEAD}" "${NEW_HEAD}" -- requirements.txt 2>/dev/null; then
    REQS_CHANGED=true
fi

if [ "$REQS_CHANGED" = true ] || [ "$PREV_HEAD" = "$NEW_HEAD" ]; then
    echo ""
    if [ "$REQS_CHANGED" = true ]; then
        echo ">>> requirements.txt changed — refreshing Python packages..."
    else
        echo ">>> Refreshing Python packages..."
    fi
    pip install --upgrade pip --quiet
    pip install -r "$SCRIPT_DIR/requirements.txt" --quiet
fi

# Always re-install the local package to pick up any source changes
pip install -e "$SCRIPT_DIR" --quiet

# ── Regenerate meshtty.sh if the template section of install.sh changed ───────

INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
[ -f "$SCRIPT_DIR/install-pi.sh" ] && grep -qi "raspberry\|dietpi" /etc/os-release 2>/dev/null \
    && INSTALL_SCRIPT="$SCRIPT_DIR/install-pi.sh"

if ! git diff --quiet "${PREV_HEAD}" "${NEW_HEAD}" -- "$INSTALL_SCRIPT" 2>/dev/null; then
    echo ""
    echo ">>> $(basename "$INSTALL_SCRIPT") changed — regenerating meshtty.sh..."
    bash "$INSTALL_SCRIPT" --regen-scripts-only 2>/dev/null \
        || echo "    (Re-run $(basename "$INSTALL_SCRIPT") manually if the launch script needs updating)"
fi

# Ensure meshtty-crt.sh is still executable after a pull
chmod +x "$SCRIPT_DIR/meshtty-crt.sh" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/meshtty.sh"      2>/dev/null || true
chmod +x "$SCRIPT_DIR/launch.sh"       2>/dev/null || true

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║             Update complete              ║"
echo "╚══════════════════════════════════════════╝"
echo ""
if [ "$PREV_HEAD" != "$NEW_HEAD" ]; then
    echo "  Updated: $PREV_HEAD"
    echo "       →   $NEW_HEAD"
    echo ""
fi
echo "  Launch MeshTTY:"
echo "    ./launch.sh"
echo ""
