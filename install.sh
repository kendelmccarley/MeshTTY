#!/usr/bin/env bash
# install.sh — MeshTTY installer
#
# Supports:
#   - Raspberry Pi OS (Lite or Desktop)
#   - Ubuntu 22.04 / 24.04 (and derivatives: Mint, Pop!_OS, etc.)
#   - macOS 12+ (Monterey and later, Intel and Apple Silicon)
#
# Usage:
#   bash install.sh
#
# Run as your normal user (not root). sudo is invoked only where needed
# (not applicable on macOS where no group changes are required).
#
# After installation, use the generated start script to launch the app:
#   ./meshtty.sh          # from this directory
#
# On Raspberry Pi only: you may also opt in to auto-launch on tty1
# (the physical screen), so the app starts automatically on boot login.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$HOME/.venv/meshtty"
START_SCRIPT="$SCRIPT_DIR/meshtty.sh"

# ------------------------------------------------------------------ #
# Detect platform                                                      #
# ------------------------------------------------------------------ #
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
    PLATFORM="Raspberry Pi"
else
    PLATFORM="Ubuntu / Debian"
fi

echo "=== MeshTTY Installer ==="
echo ">>> Detected platform: $PLATFORM"
echo ""

# ------------------------------------------------------------------ #
# 1. System dependencies                                               #
# ------------------------------------------------------------------ #
if $IS_MAC; then
    echo ">>> Checking for Homebrew..."
    if ! command -v brew >/dev/null 2>&1; then
        echo ""
        echo "ERROR: Homebrew is not installed. Install it first:"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo "Then re-run install.sh."
        exit 1
    fi
    echo ">>> Installing system packages via Homebrew..."
    # bleak on macOS uses the native CoreBluetooth framework — no separate
    # BLE packages are needed.  Ensure a recent Python is available.
    brew install python@3.11 || true
else
    echo ">>> Installing system packages..."
    sudo apt-get update -qq
    sudo apt-get install -y \
        python3-pip \
        python3-venv \
        libglib2.0-dev \
        bluetooth \
        libbluetooth-dev \
        bluez

    # Ensure the Bluetooth service is running (important on Ubuntu where
    # it may not start automatically after install)
    sudo systemctl enable bluetooth --quiet 2>/dev/null || true
    sudo systemctl start  bluetooth         2>/dev/null || true
fi

# ------------------------------------------------------------------ #
# 2. Python virtual environment                                        #
# ------------------------------------------------------------------ #
echo ">>> Creating virtualenv at $VENV_DIR..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# ------------------------------------------------------------------ #
# 3. Install Python packages                                           #
# ------------------------------------------------------------------ #
echo ">>> Installing Python dependencies..."
pip install --upgrade pip --quiet
pip install -r "$SCRIPT_DIR/requirements.txt" --quiet
pip install -e "$SCRIPT_DIR" --quiet

# ------------------------------------------------------------------ #
# 4. Verify meshtastic installation                                    #
# ------------------------------------------------------------------ #
echo ">>> Verifying meshtastic Python library..."
if python -c "import meshtastic" 2>/dev/null; then
    MESH_VER=$(python -c "import meshtastic; print(meshtastic.__version__)" 2>/dev/null || echo "unknown")
    echo "    OK: meshtastic $MESH_VER"
else
    echo ""
    echo "ERROR: The meshtastic Python library did not install correctly."
    echo "Check the pip output above for errors, then re-run install.sh."
    exit 1
fi

echo ">>> Verifying meshtastic CLI command..."
if command -v meshtastic >/dev/null 2>&1; then
    echo "    OK: $(command -v meshtastic)"
else
    echo ""
    echo "ERROR: The meshtastic CLI command was not found in the virtualenv."
    echo "Try running: pip install --force-reinstall meshtastic"
    exit 1
fi

# ------------------------------------------------------------------ #
# 5. Serial port and Bluetooth access                                  #
# ------------------------------------------------------------------ #
if $IS_MAC; then
    echo ">>> macOS: serial port and Bluetooth access do not require group membership."
    echo "    Serial devices appear as /dev/cu.usbserial-* or /dev/cu.SLAB_*"
    echo "    For BLE: grant your terminal app Bluetooth permission when prompted"
    echo "    (System Settings → Privacy & Security → Bluetooth)."
else
    echo ">>> Adding $USER to dialout group (serial/USB radio access)..."
    sudo usermod -aG dialout "$USER"
    echo ">>> Adding $USER to bluetooth group..."
    sudo usermod -aG bluetooth "$USER"
fi

# ------------------------------------------------------------------ #
# 6. Generate start script                                             #
# ------------------------------------------------------------------ #
echo ">>> Generating start script at $START_SCRIPT..."
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
# Device paths differ: Linux uses /dev/ttyUSB* and /dev/ttyACM*;
# macOS uses /dev/cu.usbserial-*, /dev/cu.SLAB_*, /dev/cu.wchusbserial*, etc.
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

# Load flags saved by the last manual launch (--debug, --bot, --log, etc.)
FLAGS_FILE="\$HOME/.config/meshtty/last_flags"
SAVED_FLAGS=""
if [[ -f "\$FLAGS_FILE" ]]; then
    SAVED_FLAGS=\$(cat "\$FLAGS_FILE")
fi

# shellcheck disable=SC2086  # word-split intentional for flag list
exec python -m meshtty.main \$SAVED_FLAGS "\$@"
STARTSCRIPT
chmod +x "$START_SCRIPT"
echo ">>> Start script created: $START_SCRIPT"

# ------------------------------------------------------------------ #
# 7. Pi-only: optional auto-launch on tty1                            #
# ------------------------------------------------------------------ #
if $IS_PI; then
    echo ""
    echo ">>> Raspberry Pi detected."
    read -r -p ">>> Auto-launch MeshTTY on tty1 login (physical screen)? [y/N] " answer
    if [[ "${answer,,}" == "y" ]]; then
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
        # Check both .bash_profile and .bashrc to avoid duplicating an older install
        if ! grep -q "meshtty auto-launch" "$BASH_PROFILE" 2>/dev/null \
           && ! grep -q "meshtty auto-launch" "$HOME/.bashrc" 2>/dev/null; then
            echo "$LAUNCH_BLOCK" >> "$BASH_PROFILE"
            echo ">>> Added auto-launch block to $BASH_PROFILE"
        else
            echo ">>> Auto-launch already present in shell profile, skipping."
        fi
    fi
fi

# ------------------------------------------------------------------ #
# Done                                                                 #
# ------------------------------------------------------------------ #
echo ""
echo "=== Installation complete ==="
echo ""
if ! $IS_MAC; then
    echo "IMPORTANT: Log out and back in for group membership to take effect."
    echo "(This is required for serial port and Bluetooth access.)"
    echo ""
fi
echo "To test your radio connection before launching MeshTTY:"
echo "  source $VENV_DIR/bin/activate"
if $IS_MAC; then
    echo "  meshtastic --port /dev/cu.usbserial-XXXX --info   # adjust port as needed"
else
    echo "  meshtastic --port /dev/ttyUSB0 --info   # adjust port as needed"
fi
echo "  deactivate"
echo ""
echo "To launch MeshTTY:"
echo "  $START_SCRIPT"
echo ""
if $IS_MAC; then
    echo "macOS notes:"
    echo "  - Run in any terminal emulator (Terminal.app, iTerm2, Kitty, etc.)"
    echo "  - SSH sessions are also fully supported"
    echo "  - Serial devices appear as /dev/cu.usbserial-* or /dev/cu.SLAB_*"
    echo "  - For Bluetooth: grant your terminal Bluetooth permission when prompted"
    echo "    (System Settings → Privacy & Security → Bluetooth)"
    echo ""
elif ! $IS_PI; then
    echo "Ubuntu notes:"
    echo "  - Run in any terminal emulator (GNOME Terminal, Konsole, Kitty, etc.)"
    echo "  - SSH sessions are also fully supported"
    echo "  - If Bluetooth fails, check: sudo systemctl status bluetooth"
    echo ""
fi
echo "Logs are written to: /tmp/meshtty.log"
