#!/usr/bin/env bash
# install-pi.sh — MeshTTY installer for Raspberry Pi
#
# Supports:
#   - Raspberry Pi OS Lite / Desktop (Bullseye / Bookworm)
#   - DietPi 32-bit (Bullseye / Bookworm base)
#   - Pi Zero W (ARMv6), Pi Zero 2 W (ARMv7), Pi 3/4/5
#
# Run as your normal user — sudo is invoked only where needed.
#
# Usage:
#   bash install-pi.sh
#
# After installation:
#   ./launch-pi.sh        — smart launcher (auto-selects CRT or plain terminal)
#   ./meshtty.sh          — plain terminal only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$HOME/.venv/meshtty"
START_SCRIPT="$SCRIPT_DIR/meshtty.sh"
LAUNCH_SCRIPT="$SCRIPT_DIR/launch-pi.sh"
REBOOT_NEEDED=false

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
  │  • cool-retro-term will work but GPU effects should be minimal  │
  │    — use the meshtty-zero.json profile (lowest GPU load)        │
  └─────────────────────────────────────────────────────────────────┘
WARN
    echo ""
fi

# ── 1. Base system packages ───────────────────────────────────────────────────

_section "[1/8] Installing base system packages..."
sudo apt-get update -qq
sudo apt-get install -y \
    python3-pip \
    python3-venv \
    libglib2.0-dev \
    bluetooth \
    libbluetooth-dev \
    bluez \
    git

sudo systemctl enable bluetooth --quiet 2>/dev/null || true
sudo systemctl start  bluetooth         2>/dev/null || true

# ── 2. cool-retro-term + X server ─────────────────────────────────────────────

_section "[2/8] cool-retro-term / display setup"

_x_installed()      { command -v Xorg &>/dev/null || command -v X &>/dev/null; }
_crt_installed()    { command -v cool-retro-term &>/dev/null; }
_openbox_installed(){ command -v openbox &>/dev/null; }

INSTALL_CRT=false
INSTALL_X=false

if _crt_installed; then
    echo "    cool-retro-term already installed — skipping."
    INSTALL_CRT=true
elif _ask "    Install cool-retro-term for retro CRT effects?"; then
    INSTALL_CRT=true

    if _x_installed; then
        echo "    X server found."
    else
        echo ""
        echo "    cool-retro-term needs an X server."
        echo "    A minimal install (xorg + openbox, ~60 MB) is all that's needed."
        echo "    MeshTTY will be the only application — no desktop environment."
        if _ask "    Install minimal X server (xorg + openbox)?"; then
            INSTALL_X=true
        else
            echo "    Skipping X install.  Re-run this installer to add it later."
            INSTALL_CRT=false
        fi
    fi
fi

if $INSTALL_X; then
    _section "    Installing minimal X server..."
    sudo apt-get install -y xorg openbox x11-xserver-utils
    echo "    Installed: xorg + openbox"
fi

if $INSTALL_CRT; then
    echo "    Installing cool-retro-term..."
    if apt-cache show cool-retro-term &>/dev/null 2>&1; then
        sudo apt-get install -y cool-retro-term
    else
        echo "    cool-retro-term not in apt — trying Flatpak..."
        if ! command -v flatpak &>/dev/null; then
            sudo apt-get install -y flatpak
            sudo flatpak remote-add --if-not-exists flathub \
                https://flathub.org/repo/flathub.flatpakrepo
        fi
        flatpak install -y flathub io.github.swordfishslabs.cool-retro-term
        mkdir -p "$HOME/.local/bin"
        cat > "$HOME/.local/bin/cool-retro-term" << 'WRAPPER'
#!/usr/bin/env bash
exec flatpak run io.github.swordfishslabs.cool-retro-term "$@"
WRAPPER
        chmod +x "$HOME/.local/bin/cool-retro-term"
    fi
    echo "    cool-retro-term installed."
fi

# ── 3. OpenGL driver + GPU memory (required for cool-retro-term) ──────────────

if $INSTALL_CRT; then
    _section "[3a/8] Checking OpenGL driver for cool-retro-term..."

    BOOT_CONFIG=""
    for f in /boot/firmware/config.txt /boot/config.txt; do
        [ -f "$f" ] && { BOOT_CONFIG="$f"; break; }
    done

    if [ -z "$BOOT_CONFIG" ]; then
        echo "    WARNING: Could not find /boot/config.txt — skipping GPU config."
    else
        # vc4-kms-v3d is required on ALL Pi models for cool-retro-term's OpenGL shaders.
        # vc4-fkms-v3d (fake KMS) also works on Bullseye but is deprecated on Bookworm.
        if grep -q "vc4-kms-v3d\|vc4-fkms-v3d" "$BOOT_CONFIG"; then
            echo "    OpenGL driver already configured — OK."
        else
            echo ""
            echo "    cool-retro-term requires the vc4-kms-v3d OpenGL driver."
            echo "    Without it cool-retro-term will fail to open."
            if _ask "    Add dtoverlay=vc4-kms-v3d to $BOOT_CONFIG?"; then
                printf "\n# MeshTTY: OpenGL driver for cool-retro-term\ndtoverlay=vc4-kms-v3d\n" \
                    | sudo tee -a "$BOOT_CONFIG" > /dev/null
                REBOOT_NEEDED=true
                echo "    Added. Reboot required before cool-retro-term will work."
            else
                echo "    Skipped — cool-retro-term will likely fail to start."
            fi
        fi

        # gpu_mem must be ≥64 MB for cool-retro-term's OpenGL renderer.
        # DietPi defaults to gpu_mem=16 which is too low.
        GPU_MEM="$(grep "^gpu_mem" "$BOOT_CONFIG" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d ' ')"
        if [ -n "$GPU_MEM" ] && [ "$GPU_MEM" -lt 64 ] 2>/dev/null; then
            echo ""
            echo "    gpu_mem=${GPU_MEM} MB is too low for cool-retro-term (needs ≥64 MB)."
            if _ask "    Set gpu_mem=64 in $BOOT_CONFIG?"; then
                sudo sed -i "s/^gpu_mem=.*/gpu_mem=64/" "$BOOT_CONFIG"
                REBOOT_NEEDED=true
                echo "    Updated to gpu_mem=64."
            fi
        fi
    fi

    if $IS_ZERO_W; then
        echo ""
        echo "    Pi Zero W: use the meshtty-zero.json CRT profile for best performance."
        echo "    It disables GPU-heavy effects (scanlines, curvature, noise, burnin)."
        echo "    Import it via: cool-retro-term → Settings → Profiles → Import"
        echo "    File: $SCRIPT_DIR/assets/crt-profiles/meshtty-zero.json"
    fi
fi

# ── 3b. Configure X kiosk (openbox + cool-retro-term fullscreen) ──────────────

if $INSTALL_CRT && ( _x_installed || $INSTALL_X ) && _openbox_installed; then

    _section "[3b/8] Configuring X kiosk (openbox, cool-retro-term fullscreen)..."

    cat > "$HOME/.xinitrc" << 'XINITRC'
#!/usr/bin/env bash
exec openbox-session
XINITRC
    chmod +x "$HOME/.xinitrc"
    echo "    Created: ~/.xinitrc"

    mkdir -p "$HOME/.config/openbox"
    cat > "$HOME/.config/openbox/autostart" << AUTOSTART
#!/bin/sh
# MeshTTY kiosk: launch cool-retro-term fullscreen; shut X down when it exits
(cool-retro-term -e "$START_SCRIPT"; openbox --exit) &
AUTOSTART
    echo "    Created: ~/.config/openbox/autostart"

    cat > "$HOME/.config/openbox/rc.xml" << 'RCXML'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc"
                xmlns:xi="http://www.w3.org/2001/XInclude">

  <resistance><strength>10</strength><screen_edge_strength>20</screen_edge_strength></resistance>
  <focus><focusNew>yes</focusNew><followMouse>no</followMouse><focusLast>yes</focusLast></focus>
  <placement><policy>Smart</policy></placement>

  <!-- Force cool-retro-term to fill the screen with no chrome -->
  <applications>
    <application class="cool-retro-term">
      <fullscreen>yes</fullscreen>
      <decor>no</decor>
      <skip_taskbar>yes</skip_taskbar>
      <skip_pager>yes</skip_pager>
      <layer>above</layer>
    </application>
  </applications>

  <!-- Disable right-click desktop menu to prevent accidental exits -->
  <mouse>
    <dragThreshold>8</dragThreshold>
    <doubleClickTime>200</doubleClickTime>
    <screenEdgeWarpTime>400</screenEdgeWarpTime>
    <context name="Desktop"></context>
    <context name="Client"></context>
    <context name="Titlebar"></context>
  </mouse>

  <keyboard>
    <!-- Ctrl+Alt+Backspace kills X — emergency exit -->
    <keybind key="C-A-BackSpace">
      <action name="Execute"><command>openbox --exit</command></action>
    </keybind>
  </keyboard>

  <theme><name>Clearlooks</name><titleLayout>NLIMC</titleLayout></theme>
  <desktops><number>1</number></desktops>

</openbox_config>
RCXML
    echo "    Created: ~/.config/openbox/rc.xml"

else
    _section "[3b/8] X kiosk config — skipped."
fi

# ── 4. Swap check ─────────────────────────────────────────────────────────────

_section "[4/8] Checking available memory..."

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

# ── 5. Python virtual environment ─────────────────────────────────────────────

_section "[5/8] Creating Python virtualenv at $VENV_DIR..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
echo "    Python: $(python --version)  Arch: $(uname -m)"

# ── 6. Python packages ────────────────────────────────────────────────────────

_section "[6/8] Installing Python dependencies..."
$IS_ZERO_W && echo "    Pi Zero W: this step takes 30–90 minutes. Please wait..."

pip install --upgrade pip --quiet

PIP_LOG="/tmp/meshtty-pip-install.log"

# Install deps; on ARMv6 grpcio may fail to install from a binary wheel —
# if it does, skip it (meshtastic ≥2.5 no longer requires it).
if ! pip install -r "$SCRIPT_DIR/requirements.txt" --quiet 2>"$PIP_LOG"; then
    if grep -qi "grpcio\|illegal instruction\|ERROR.*build wheel" "$PIP_LOG" 2>/dev/null; then
        echo ""
        echo "    A compiled package failed on ARMv6 — retrying without it..."
        # Install everything except grpcio; meshtastic no longer requires it
        grep -v "^grpcio" "$SCRIPT_DIR/requirements.txt" > /tmp/meshtty-reqs-nograpcio.txt
        pip install -r /tmp/meshtty-reqs-nograpcio.txt --quiet \
            || { echo "ERROR: pip install failed. See $PIP_LOG"; cat "$PIP_LOG"; exit 1; }
    else
        echo "ERROR: pip install failed. See $PIP_LOG"
        cat "$PIP_LOG"
        exit 1
    fi
fi

pip install -e "$SCRIPT_DIR" --quiet

# ── 7. Verify ─────────────────────────────────────────────────────────────────

_section "[7/8] Verifying installation..."

python -c "import meshtastic" 2>/dev/null \
    && echo "    OK: meshtastic $(python -c 'import meshtastic; print(meshtastic.__version__)')" \
    || { echo "ERROR: meshtastic failed to import — check $PIP_LOG"; exit 1; }

python -c "import textual" 2>/dev/null \
    && echo "    OK: textual $(python -c 'import textual; print(textual.__version__)')" \
    || { echo "ERROR: textual failed to import."; exit 1; }

command -v meshtastic &>/dev/null \
    && echo "    OK: meshtastic CLI at $(command -v meshtastic)" \
    || { echo "ERROR: meshtastic CLI not found."; exit 1; }

# ── 8. Hardware permissions + start scripts ───────────────────────────────────

_section "[8/8] Hardware permissions and start scripts..."

sudo usermod -aG dialout  "$USER"
sudo usermod -aG bluetooth "$USER"
sudo usermod -aG video     "$USER"
echo "    Added $USER to: dialout, bluetooth, video"
echo "    NOTE: Log out and back in for these to take effect."

# Generate meshtty.sh
cat > "$START_SCRIPT" << STARTSCRIPT
#!/usr/bin/env bash
# meshtty.sh — launch MeshTTY in the current terminal
# Generated by install-pi.sh — safe to re-run to regenerate.

VENV="$VENV_DIR"
APP_DIR="$SCRIPT_DIR"

if ! [[ -t 0 && -t 1 ]]; then
    echo "ERROR: MeshTTY requires an interactive terminal." >&2
    exit 1
fi

[[ "\$TERM" == "dumb" || -z "\$TERM" ]] && export TERM=xterm-256color

if [[ ! -f "\$VENV/bin/activate" ]]; then
    echo "ERROR: virtualenv not found at \$VENV — re-run install-pi.sh" >&2
    exit 1
fi

source "\$VENV/bin/activate"
cd "\$APP_DIR"

# Wait up to 10 s for USB serial device to enumerate at boot
CONFIG="\$HOME/.config/meshtty/config.json"
if grep -q '"default_transport".*"serial"' "\$CONFIG" 2>/dev/null; then
    _serial_ready() { ls /dev/ttyUSB* /dev/ttyACM* >/dev/null 2>&1; }
    if ! _serial_ready; then
        echo "Waiting for USB serial device..."
        for _i in \$(seq 1 10); do _serial_ready && break; sleep 1; done
    fi
fi

FLAGS_FILE="\$HOME/.config/meshtty/last_flags"
SAVED_FLAGS=""
[[ \$# -eq 0 && -f "\$FLAGS_FILE" ]] && SAVED_FLAGS=\$(cat "\$FLAGS_FILE")

# shellcheck disable=SC2086
exec python -m meshtty.main \$SAVED_FLAGS "\$@"
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
    export TERM=xterm-256color
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

if $INSTALL_CRT && _crt_installed; then
    echo "  Import a CRT profile into cool-retro-term once:"
    echo "    cool-retro-term → Settings → Profiles → Import"
    if $IS_ZERO_W || $IS_ZERO2_W; then
        echo "    $SCRIPT_DIR/assets/crt-profiles/meshtty-zero.json  ← use this on Zero hardware"
    else
        echo "    $SCRIPT_DIR/assets/crt-profiles/meshtty-amber.json"
        echo "    $SCRIPT_DIR/assets/crt-profiles/meshtty-phosphor.json"
    fi
    echo ""
fi

if $REBOOT_NEEDED; then
    echo "  *** A REBOOT IS REQUIRED for GPU driver changes to take effect. ***"
    echo "  Reboot now with:  sudo reboot"
    echo ""
fi

echo "  Logs: /tmp/meshtty.log"
echo ""
