#!/usr/bin/env bash
# install.sh — MeshTTY installer
#
# Supports:
#   - Raspberry Pi OS (Lite or Desktop, Bullseye / Bookworm)
#   - Ubuntu 22.04 / 24.04 (and derivatives: Mint, Pop!_OS, etc.)
#   - macOS 12+ (Monterey and later, Intel and Apple Silicon)
#
# Usage:
#   bash install.sh
#
# Run as your normal user (not root). sudo is invoked only where needed.
#
# After installation:
#   ./meshtty.sh       — launch in any terminal
#   ./meshtty-crt.sh   — launch inside cool-retro-term (if installed)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$HOME/.venv/meshtty"
START_SCRIPT="$SCRIPT_DIR/meshtty.sh"
CRT_SCRIPT="$SCRIPT_DIR/meshtty-crt.sh"

# ── Helpers ───────────────────────────────────────────────────────────────────

_ask() {
    # _ask "prompt" → returns 0 for yes, 1 for no
    local prompt="$1"
    local answer
    read -r -p "$prompt [y/N] " answer
    [[ "${answer,,}" == "y" ]]
}

# ── Detect platform ───────────────────────────────────────────────────────────

IS_PI=false
IS_MAC=false

if [[ "$(uname -s)" == "Darwin" ]]; then
    IS_MAC=true
elif grep -qi "raspberry" /proc/device-tree/model 2>/dev/null \
   || grep -qi "raspbian\|raspberry" /etc/os-release 2>/dev/null; then
    IS_PI=true
fi

if $IS_MAC; then
    PLATFORM="macOS"
elif $IS_PI; then
    PLATFORM="Raspberry Pi OS"
else
    PLATFORM="Ubuntu / Debian"
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         MeshTTY Installer                ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Platform : $PLATFORM"
echo "  App dir  : $SCRIPT_DIR"
echo "  Venv     : $VENV_DIR"
echo ""

# ── 1. System dependencies ────────────────────────────────────────────────────

echo ">>> [1/7] Installing system dependencies..."

if $IS_MAC; then
    if ! command -v brew >/dev/null 2>&1; then
        echo ""
        echo "ERROR: Homebrew is not installed. Install it first:"
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo "Then re-run install.sh."
        exit 1
    fi
    echo "    Homebrew found: $(brew --version | head -1)"
    brew install python@3.11 || true
else
    sudo apt-get update -qq
    sudo apt-get install -y \
        python3-pip \
        python3-venv \
        libglib2.0-dev \
        bluetooth \
        libbluetooth-dev \
        bluez

    sudo systemctl enable bluetooth --quiet 2>/dev/null || true
    sudo systemctl start  bluetooth         2>/dev/null || true
fi

# ── 2. cool-retro-term (optional) ─────────────────────────────────────────────

echo ""
echo ">>> [2/7] cool-retro-term (retro CRT terminal, optional)"

_crt_installed() {
    command -v cool-retro-term &>/dev/null \
    || [ -d "/Applications/cool-retro-term.app" ] \
    || [ -d "$HOME/Applications/cool-retro-term.app" ]
}

if _crt_installed; then
    echo "    Already installed — skipping."
elif _ask "    Install cool-retro-term for retro CRT effects?"; then
    if $IS_MAC; then
        echo "    Installing via Homebrew Cask..."
        brew install --cask cool-retro-term
    else
        # Try apt first (available in Ubuntu universe and Pi OS repos)
        if apt-cache show cool-retro-term &>/dev/null 2>&1; then
            echo "    Installing via apt..."
            sudo apt-get install -y cool-retro-term
        else
            # Flatpak fallback
            echo "    cool-retro-term not found in apt — trying Flatpak..."
            if ! command -v flatpak &>/dev/null; then
                sudo apt-get install -y flatpak
                sudo flatpak remote-add --if-not-exists flathub \
                    https://flathub.org/repo/flathub.flatpakrepo
                echo "    Flatpak installed. A reboot may be needed before the first run."
            fi
            flatpak install -y flathub io.github.swordfishslabs.cool-retro-term
            # Wrap the flatpak command as 'cool-retro-term' in ~/.local/bin
            mkdir -p "$HOME/.local/bin"
            cat > "$HOME/.local/bin/cool-retro-term" << 'WRAPPER'
#!/usr/bin/env bash
exec flatpak run io.github.swordfishslabs.cool-retro-term "$@"
WRAPPER
            chmod +x "$HOME/.local/bin/cool-retro-term"
            echo "    Wrapper created at ~/.local/bin/cool-retro-term"
            echo "    Make sure ~/.local/bin is in your PATH."
        fi
    fi

    echo ""
    echo "    Profile import (do this once after install):"
    echo "      Open cool-retro-term → Settings → Profiles → Import"
    echo "      $SCRIPT_DIR/assets/crt-profiles/meshtty-amber.json     (warm amber)"
    echo "      $SCRIPT_DIR/assets/crt-profiles/meshtty-phosphor.json  (green glow)"
else
    echo "    Skipped. You can install it later and use ./meshtty-crt.sh"
fi

# ── 3. Python virtual environment ─────────────────────────────────────────────

echo ""
echo ">>> [3/7] Creating Python virtualenv at $VENV_DIR..."

# On macOS use the Homebrew python@3.11 binary explicitly, because
# /usr/bin/python3 is the system stub (3.9) which is too old for some deps.
if $IS_MAC; then
    BREW_PY=""
    for ver in python@3.12 python@3.11; do
        prefix="$(brew --prefix "$ver" 2>/dev/null)" || continue
        candidate="$prefix/bin/$(basename "$ver")"
        if [ -x "$candidate" ]; then
            BREW_PY="$candidate"
            break
        fi
    done
    if [ -z "$BREW_PY" ]; then
        echo "ERROR: No Homebrew Python 3.11+ found. Run: brew install python@3.11"
        exit 1
    fi
    PYTHON_BIN="$BREW_PY"
    echo "    Using Python: $PYTHON_BIN ($($PYTHON_BIN --version))"
else
    PYTHON_BIN="python3"
    echo "    Using Python: $($PYTHON_BIN --version)"
fi

"$PYTHON_BIN" -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# ── 4. Python packages ────────────────────────────────────────────────────────

echo ""
echo ">>> [4/7] Installing Python dependencies..."
pip install --upgrade pip --quiet
pip install -r "$SCRIPT_DIR/requirements.txt" --quiet
pip install -e "$SCRIPT_DIR" --quiet

# ── 5. Verify ─────────────────────────────────────────────────────────────────

echo ""
echo ">>> [5/7] Verifying installation..."

if python -c "import meshtastic" 2>/dev/null; then
    MESH_VER=$(python -c "import meshtastic; print(meshtastic.__version__)" 2>/dev/null || echo "unknown")
    echo "    OK: meshtastic $MESH_VER"
else
    echo ""
    echo "ERROR: The meshtastic Python library did not install correctly."
    echo "Check pip output above, then re-run install.sh."
    exit 1
fi

if python -c "import textual" 2>/dev/null; then
    TUI_VER=$(python -c "import textual; print(textual.__version__)" 2>/dev/null || echo "unknown")
    echo "    OK: textual $TUI_VER"
else
    echo ""
    echo "ERROR: Textual did not install correctly."
    exit 1
fi

if command -v meshtastic >/dev/null 2>&1; then
    echo "    OK: meshtastic CLI at $(command -v meshtastic)"
else
    echo ""
    echo "ERROR: meshtastic CLI not found in virtualenv."
    exit 1
fi

# ── 6. Serial port and Bluetooth access ───────────────────────────────────────

echo ""
echo ">>> [6/7] Hardware access permissions..."

if $IS_MAC; then
    echo "    macOS: no group changes needed."
    echo "    Serial devices: /dev/cu.usbserial-* or /dev/cu.SLAB_*"
    echo "    Bluetooth: grant terminal Bluetooth permission when prompted"
    echo "    (System Settings → Privacy & Security → Bluetooth)"
else
    echo "    Adding $USER to dialout (serial/USB) and bluetooth groups..."
    sudo usermod -aG dialout  "$USER"
    sudo usermod -aG bluetooth "$USER"
    echo "    NOTE: Log out and back in for group membership to take effect."
fi

# ── 7. Generate start scripts ─────────────────────────────────────────────────

echo ""
echo ">>> [7/7] Generating start scripts..."

# meshtty.sh — plain terminal launcher
cat > "$START_SCRIPT" << STARTSCRIPT
#!/usr/bin/env bash
# meshtty.sh — launch MeshTTY
# Works on Raspberry Pi OS, Ubuntu, and macOS.
# Generated by install.sh — safe to re-run install.sh to regenerate.

VENV="$VENV_DIR"
APP_DIR="$SCRIPT_DIR"

# Require an interactive terminal — Textual cannot run without one
if ! [[ -t 0 && -t 1 ]]; then
    echo "ERROR: MeshTTY requires an interactive terminal (stdin/stdout must be a TTY)." >&2
    exit 1
fi

# Ensure a capable TERM for Textual rendering
if [[ "\$TERM" == "dumb" || -z "\$TERM" ]]; then
    export TERM=xterm-256color
fi

if [[ ! -f "\$VENV/bin/activate" ]]; then
    echo "ERROR: virtualenv not found at \$VENV"
    echo "Please re-run install.sh"
    exit 1
fi

source "\$VENV/bin/activate"
cd "\$APP_DIR"

# At boot, wait up to 10 s for a USB serial device to enumerate if serial
# is the configured transport.  Harmless no-op once the device is present.
CONFIG="\$HOME/.config/meshtty/config.json"
if grep -q '"default_transport".*"serial"' "\$CONFIG" 2>/dev/null; then
    _serial_ready() {
        if [[ "\$(uname -s)" == "Darwin" ]]; then
            ls /dev/cu.usbserial* /dev/cu.SLAB_* /dev/cu.wchusbserial* /dev/cu.usbmodem* >/dev/null 2>&1
        else
            ls /dev/ttyUSB* /dev/ttyACM* >/dev/null 2>&1
        fi
    }
    if ! _serial_ready; then
        echo "Waiting for USB serial device..."
        for _i in \$(seq 1 10); do
            _serial_ready && break
            sleep 1
        done
    fi
fi

# Replay saved startup flags if none were passed explicitly
FLAGS_FILE="\$HOME/.config/meshtty/last_flags"
SAVED_FLAGS=""
if [[ \$# -eq 0 && -f "\$FLAGS_FILE" ]]; then
    SAVED_FLAGS=\$(cat "\$FLAGS_FILE")
fi

# shellcheck disable=SC2086
exec python -m meshtty.main \$SAVED_FLAGS "\$@"
STARTSCRIPT
chmod +x "$START_SCRIPT"
echo "    Created: $START_SCRIPT"

# meshtty-crt.sh is already in the repo — just ensure it's executable
chmod +x "$CRT_SCRIPT" 2>/dev/null || true
echo "    Ready:   $CRT_SCRIPT"

# ── Pi-only: optional auto-launch on tty1 ────────────────────────────────────

if $IS_PI; then
    echo ""
    if _ask ">>> Auto-launch MeshTTY on tty1 login (physical Pi screen)?"; then
        BASH_PROFILE="$HOME/.bash_profile"
        LAUNCH_BLOCK="
# MeshTTY auto-launch on tty1 (physical Pi screen)
if [[ \"\$(tty)\" == \"/dev/tty1\" ]]; then
    export TERM=xterm-256color
    while true; do
        $START_SCRIPT
        sleep 2
    done
fi"
        if ! grep -q "meshtty auto-launch" "$BASH_PROFILE" 2>/dev/null \
           && ! grep -q "meshtty auto-launch" "$HOME/.bashrc" 2>/dev/null; then
            echo "$LAUNCH_BLOCK" >> "$BASH_PROFILE"
            echo ">>> Auto-launch block added to $BASH_PROFILE"
        else
            echo ">>> Auto-launch already present in shell profile — skipping."
        fi
    fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         Installation complete            ║"
echo "╚══════════════════════════════════════════╝"
echo ""

if ! $IS_MAC; then
    echo "  IMPORTANT: Log out and back in for serial/Bluetooth group"
    echo "  membership to take effect."
    echo ""
fi

echo "  Test your radio connection first:"
echo "    source $VENV_DIR/bin/activate"
if $IS_MAC; then
    echo "    meshtastic --port /dev/cu.usbserial-XXXX --info"
else
    echo "    meshtastic --port /dev/ttyUSB0 --info"
fi
echo "    deactivate"
echo ""
echo "  Launch MeshTTY:"
echo "    $START_SCRIPT            (any terminal)"

if _crt_installed; then
    echo "    $CRT_SCRIPT        (cool-retro-term)"
    echo ""
    echo "  Import a CRT profile into cool-retro-term once:"
    echo "    Settings → Profiles → Import"
    echo "    $SCRIPT_DIR/assets/crt-profiles/meshtty-amber.json"
    echo "    $SCRIPT_DIR/assets/crt-profiles/meshtty-phosphor.json"
fi

echo ""
echo "  Logs: /tmp/meshtty.log"
echo ""
