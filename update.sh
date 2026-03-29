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

# ── Check for local modifications ─────────────────────────────────────────────

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "  WARNING: You have uncommitted local changes:"
    git status --short
    echo ""
    read -r -p "  Continue anyway? Local changes will be preserved. [y/N] " ans
    [[ "${ans,,}" == "y" ]] || { echo "Aborted."; exit 0; }
    echo ""
fi

# ── Snapshot current HEAD so we can show a changelog ──────────────────────────

PREV_HEAD="$(git rev-parse HEAD)"

# ── Pull from GitHub ──────────────────────────────────────────────────────────

echo ">>> Fetching updates from GitHub..."
git pull --ff-only origin "$(git rev-parse --abbrev-ref HEAD)" 2>&1 \
    || { echo ""; echo "ERROR: git pull failed — check your network or resolve conflicts manually."; exit 1; }

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

if ! git diff --quiet "${PREV_HEAD}" "${NEW_HEAD}" -- install.sh 2>/dev/null; then
    echo ""
    echo ">>> install.sh changed — regenerating meshtty.sh..."
    bash "$SCRIPT_DIR/install.sh" --regen-scripts-only 2>/dev/null \
        || echo "    (Re-run install.sh manually if the launch script needs updating)"
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
