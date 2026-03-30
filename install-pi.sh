#!/usr/bin/env bash
# install-pi.sh — MeshTTY installer for Raspberry Pi
#
# Supports:
#   - Raspberry Pi OS Lite / Desktop (Bullseye / Bookworm / Trixie)
#   - DietPi 32-bit (Bullseye / Bookworm base)
#   - Pi Zero W (ARMv6), Pi Zero 2 W (ARMv7), Pi 3/4/5
#
# Run as your normal user — sudo is invoked only where needed.
#
# Usage:
#   bash install-pi.sh
#
# After installation:
#   ./launch-pi.sh        — launch MeshTTY (auto-scales font on physical screen)
#   ./meshtty.sh          — launch in current terminal as-is

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$HOME/.venv/meshtty"
START_SCRIPT="$SCRIPT_DIR/meshtty.sh"
LAUNCH_SCRIPT="$SCRIPT_DIR/launch-pi.sh"

# ── Helpers ───────────────────────────────────────────────────────────────────

_ask() {
    local prompt="$1" answer
    read -r -p "$prompt [y/N] " answer
    [[ "${answer,,}" == "y" ]]
}

_section() {
    echo ""
    echo ">>> $*"
}

# ── Detect platform and model ─────────────────────────────────────────────────

PI_MODEL="$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "")"

# Accept Raspberry Pi hardware regardless of OS branding.
# DietPi reports ID=debian in /etc/os-release, so check hardware first.
IS_PI=false
if echo "$PI_MODEL" | grep -qi "raspberry"; then
    IS_PI=true
elif grep -qi "raspbian\|raspberry" /etc/os-release 2>/dev/null; then
    IS_PI=true
fi

if ! $IS_PI; then
    echo ""
    echo "ERROR: Raspberry Pi hardware not detected."
    echo "       For macOS or Ubuntu, use install.sh instead."
    exit 1
fi

# Specific model flags
IS_ZERO_W=false       # Pi Zero W — ARMv6, single core 1 GHz
IS_ZERO2_W=false      # Pi Zero 2 W — ARMv7 quad core
IS_PI45=false         # Pi 4 or Pi 5

if echo "$PI_MODEL" | grep -q "Zero 2"; then
    IS_ZERO2_W=true
elif echo "$PI_MODEL" | grep -qE "Zero W|Zero Rev"; then
    IS_ZERO_W=true
elif echo "$PI_MODEL" | grep -qE "Pi [45]"; then
    IS_PI45=true
fi

# DietPi detection
IS_DIETPI=false
if [ -f /boot/dietpi.txt ] || command -v dietpi-software &>/dev/null; then
    IS_DIETPI=true
fi

OS_NAME="Raspberry Pi OS"
$IS_DIETPI && OS_NAME="DietPi"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║      MeshTTY Pi Installer                ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Model  : $PI_MODEL"
echo "  OS     : $OS_NAME"
echo "  App    : $SCRIPT_DIR"
echo "  Venv   : $VENV_DIR"
echo ""

# ── Pi Zero W — early warnings ────────────────────────────────────────────────

if $IS_ZERO_W; then
    cat << 'WARN'
  ┌─────────────────────────────────────────────────────────────────┐
  │  Pi Zero W (ARMv6) detected                                     │
  │                                                                 │
  │  • Python package install may take 30–90 minutes — be patient  │
  │  • Do NOT interrupt pip once it starts                          │
  └─────────────────────────────────────────────────────────────────┘
WARN
    echo ""
fi

# ── 1. Base system packages ───────────────────────────────────────────────────

_section "[1/6] Installing base system packages..."

_pkg_installed() { dpkg -l "$1" 2>/dev/null | grep -q "^ii"; }

MISSING_PKGS=()
for _pkg in python3-pip python3-venv python3-full libglib2.0-dev bluetooth libbluetooth-dev bluez git fonts-terminus; do
    _pkg_installed "$_pkg" || MISSING_PKGS+=("$_pkg")
done

if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
    echo "    All packages already installed."
else
    # Warn if bluez is missing and a Bluetooth keyboard is active — install
    # may briefly restart the BT service and drop the keyboard connection.
    if [[ " ${MISSING_PKGS[*]} " == *" bluez "* ]]; then
        if ls /dev/input/event* 2>/dev/null | xargs -I{} udevadm info {} 2>/dev/null \
                | grep -qi "bluetooth" 2>/dev/null \
           || systemctl is-active bluetooth &>/dev/null; then
            echo ""
            echo "  ⚠  Bluetooth keyboard detected."
            echo "     Installing bluez may briefly drop your BT keyboard connection."
            echo "     If you lose input, wait 10 seconds — it should reconnect."
            echo "     Using a wired keyboard for install is recommended."
            echo ""
        fi
    fi

    echo "    Installing: ${MISSING_PKGS[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y "${MISSING_PKGS[@]}"
fi

sudo systemctl enable bluetooth --quiet 2>/dev/null || true
# Only start if not already running — avoids dropping active BT connections
systemctl is-active --quiet bluetooth \
    || sudo systemctl start bluetooth 2>/dev/null || true

# ── 2. Swap check ─────────────────────────────────────────────────────────────

_section "[2/6] Checking available memory..."

TOTAL_MEM_KB=$(grep MemTotal  /proc/meminfo | awk '{print $2}')
SWAP_TOTAL_KB=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
TOTAL_MB=$(( (TOTAL_MEM_KB + SWAP_TOTAL_KB) / 1024 ))

echo "    RAM: $(( TOTAL_MEM_KB / 1024 )) MB   Swap: $(( SWAP_TOTAL_KB / 1024 )) MB   Total: ${TOTAL_MB} MB"

if [ "$TOTAL_MB" -lt 512 ]; then
    echo ""
    echo "    WARNING: Less than 512 MB RAM+swap available."
    echo "    pip install may fail with out-of-memory on Pi Zero W."
    echo ""
    if $IS_DIETPI; then
        echo "    To increase swap on DietPi:"
        echo "      dietpi-config → Performance Options → Swap"
        echo "    Recommended: 1024 MB for install, reduce back to 256 MB after."
    else
        echo "    To increase swap:"
        echo "      sudo dphys-swapfile swapoff"
        echo "      sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile"
        echo "      sudo dphys-swapfile setup && sudo dphys-swapfile swapon"
    fi
    echo ""
    _ask "    Continue anyway?" || { echo "Aborted. Increase swap and re-run."; exit 0; }
fi

# ── 3. Python virtual environment ─────────────────────────────────────────────

_section "[3/6] Creating Python virtualenv at $VENV_DIR..."
# --copies ensures the venv gets its own pip binary, avoiding the
# "externally-managed-environment" error on Bookworm / Trixie (PEP 668).
python3 -m venv --copies "$VENV_DIR"
source "$VENV_DIR/bin/activate"
echo "    Python: $(python --version)  Arch: $(uname -m)"

# ── 4. Python packages ────────────────────────────────────────────────────────

_section "[4/6] Installing Python dependencies..."
$IS_ZERO_W && echo "    Pi Zero W: this step takes 30–90 minutes. Please wait..."

pip install --upgrade pip --quiet

PIP_LOG="/tmp/meshtty-pip-install.log"

# Install deps; on ARMv6 grpcio may fail to install from a binary wheel —
# if it does, skip it (meshtastic ≥2.5 no longer requires it).
if ! pip install -r "$SCRIPT_DIR/requirements.txt" --quiet 2>"$PIP_LOG"; then
    if grep -qi "grpcio\|illegal instruction\|ERROR.*build wheel" "$PIP_LOG" 2>/dev/null; then
        echo ""
        echo "    A compiled package failed on ARMv6 — retrying without it..."
        grep -v "^grpcio" "$SCRIPT_DIR/requirements.txt" > /tmp/meshtty-reqs-nogrpcio.txt
        pip install -r /tmp/meshtty-reqs-nogrpcio.txt --quiet \
            || { echo "ERROR: pip install failed. See $PIP_LOG"; cat "$PIP_LOG"; exit 1; }
    else
        echo "ERROR: pip install failed. See $PIP_LOG"
        cat "$PIP_LOG"
        exit 1
    fi
fi

pip install -e "$SCRIPT_DIR" --quiet

# ── 5. Verify ─────────────────────────────────────────────────────────────────

_section "[5/6] Verifying installation..."

python -c "import meshtastic" 2>/dev/null \
    && echo "    OK: meshtastic $(python -c 'import meshtastic; print(meshtastic.__version__)')" \
    || { echo "ERROR: meshtastic failed to import — check $PIP_LOG"; exit 1; }

python -c "import textual" 2>/dev/null \
    && echo "    OK: textual $(python -c 'import textual; print(textual.__version__)')" \
    || { echo "ERROR: textual failed to import."; exit 1; }

command -v meshtastic &>/dev/null \
    && echo "    OK: meshtastic CLI at $(command -v meshtastic)" \
    || { echo "ERROR: meshtastic CLI not found."; exit 1; }

# ── 6. Hardware permissions + start scripts ───────────────────────────────────

_section "[6/6] Hardware permissions and start scripts..."

sudo usermod -aG dialout   "$USER"
sudo usermod -aG bluetooth "$USER"
sudo usermod -aG video     "$USER"
echo "    Added $USER to: dialout, bluetooth, video"
echo "    NOTE: Log out and back in for these to take effect."

# Generate meshtty.sh
cat > "$START_SCRIPT" << 'STARTSCRIPT'
#!/usr/bin/env bash
# meshtty.sh — launch MeshTTY in the current terminal
# Generated by install-pi.sh — safe to re-run to regenerate.

VENV="$HOME/.venv/meshtty"
APP_DIR="$(cd "$(dirname "$0")" && pwd)"

if ! [[ -t 0 && -t 1 ]]; then
    echo "ERROR: MeshTTY requires an interactive terminal." >&2
    exit 1
fi

[[ "$TERM" == "dumb" || -z "$TERM" ]] && export TERM=xterm-256color

if [[ ! -f "$VENV/bin/activate" ]]; then
    echo "ERROR: virtualenv not found at $VENV — re-run install-pi.sh" >&2
    exit 1
fi

source "$VENV/bin/activate"
cd "$APP_DIR"

# Wait up to 10 s for USB serial device to enumerate at boot
CONFIG="$HOME/.config/meshtty/config.json"
if grep -q '"default_transport".*"serial"' "$CONFIG" 2>/dev/null; then
    _serial_ready() { ls /dev/ttyUSB* /dev/ttyACM* >/dev/null 2>&1; }
    if ! _serial_ready; then
        echo "Waiting for USB serial device..."
        for _i in $(seq 1 10); do _serial_ready && break; sleep 1; done
    fi
fi

FLAGS_FILE="$HOME/.config/meshtty/last_flags"
SAVED_FLAGS=""
[[ $# -eq 0 && -f "$FLAGS_FILE" ]] && SAVED_FLAGS=$(cat "$FLAGS_FILE")

# shellcheck disable=SC2086
exec python -m meshtty.main $SAVED_FLAGS "$@"
STARTSCRIPT
chmod +x "$START_SCRIPT"
echo "    Created: $START_SCRIPT"

chmod +x "$LAUNCH_SCRIPT" 2>/dev/null || true
echo "    Ready:   $LAUNCH_SCRIPT"

# ── Auto-launch on tty1 ───────────────────────────────────────────────────────

echo ""
if _ask ">>> Auto-launch MeshTTY on tty1 login (physical Pi screen)?"; then
    BASH_PROFILE="$HOME/.bash_profile"
    LAUNCH_BLOCK="
# MeshTTY auto-launch on tty1 (physical Pi screen)
if [[ \"\$(tty)\" == \"/dev/tty1\" ]]; then
    while true; do
        $LAUNCH_SCRIPT
        sleep 2
    done
fi"
    if ! grep -q "MeshTTY auto-launch" "$BASH_PROFILE" 2>/dev/null \
       && ! grep -q "MeshTTY auto-launch" "$HOME/.bashrc" 2>/dev/null; then
        echo "$LAUNCH_BLOCK" >> "$BASH_PROFILE"
        echo "    Block added to $BASH_PROFILE"
        if $IS_DIETPI; then
            echo ""
            echo "    On DietPi, also enable console auto-login:"
            echo "      dietpi-config → AutoStart Options → set to 0 (console autologin)"
            echo "    Or via dietpi-autostart:"
            echo "      sudo dietpi-autostart"
        else
            echo ""
            echo "    Enable console auto-login:"
            echo "      sudo raspi-config → System Options → Boot / Auto Login → Console Autologin"
        fi
    else
        echo "    Auto-launch already present — skipping."
    fi
fi

# ── loginctl / session options ────────────────────────────────────────────────

echo ""
echo ">>> loginctl options"
echo ""

# enable-linger: keep the user session alive after logout so user-level
# systemd services (e.g. a future meshtty.service) can start at boot.
if loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
    echo "    Linger already enabled for $USER."
else
    echo "  enable-linger lets user services survive logout and start at boot."
    echo "  Recommended if you plan to run MeshTTY as a background service."
    echo ""
    if _ask "  Enable linger for $USER?"; then
        loginctl enable-linger "$USER"
        echo "    Done: loginctl enable-linger $USER"
    else
        echo "    Skipped. To enable later:"
        echo "      loginctl enable-linger $USER"
    fi
fi

echo ""
echo "  Other useful loginctl commands:"
echo "    loginctl show-user $USER          — show session properties"
echo "    loginctl terminate-session \$XDG_SESSION_ID  — kill current session"
echo "    loginctl list-sessions             — show all active sessions"

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         Installation complete            ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  IMPORTANT: Log out and back in for group membership to take effect."
echo ""
echo "  Test your radio connection:"
echo "    source $VENV_DIR/bin/activate"
echo "    meshtastic --port /dev/ttyUSB0 --info"
echo "    deactivate"
echo ""
echo "  Launch MeshTTY:"
echo "    $LAUNCH_SCRIPT"
echo ""
echo "  Logs: /tmp/meshtty.log"
echo ""
