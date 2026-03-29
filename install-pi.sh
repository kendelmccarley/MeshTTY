#!/usr/bin/env bash
# install-pi.sh — MeshTTY installer for Raspberry Pi OS
#
# Supports Raspberry Pi OS Lite and Desktop (Bullseye / Bookworm).
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

# ── Verify we are on a Pi ─────────────────────────────────────────────────────

if ! grep -qi "raspberry" /proc/device-tree/model 2>/dev/null \
   && ! grep -qi "raspbian\|raspberry" /etc/os-release 2>/dev/null; then
    echo ""
    echo "ERROR: This installer is for Raspberry Pi OS only."
    echo "       For macOS or Ubuntu, use install.sh instead."
    exit 1
fi

PI_MODEL="$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "Raspberry Pi")"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║      MeshTTY Pi Installer                ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Model  : $PI_MODEL"
echo "  App    : $SCRIPT_DIR"
echo "  Venv   : $VENV_DIR"
echo ""

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

_x_installed() { command -v Xorg &>/dev/null || command -v X &>/dev/null; }
_crt_installed() { command -v cool-retro-term &>/dev/null; }
_openbox_installed() { command -v openbox &>/dev/null; }

INSTALL_CRT=false
INSTALL_X=false

if _crt_installed; then
    echo "    cool-retro-term already installed — skipping."
    INSTALL_CRT=true
elif _ask "    Install cool-retro-term for retro CRT effects?"; then
    INSTALL_CRT=true

    # Check for X server
    if _x_installed; then
        echo "    X server found."
    else
        echo ""
        echo "    cool-retro-term is a GUI app and needs an X server."
        echo "    A minimal X install (xorg + openbox, ~60 MB) is all that's needed."
        echo "    MeshTTY will be the only application — no desktop environment."
        if _ask "    Install minimal X server (xorg + openbox)?"; then
            INSTALL_X=true
        else
            echo ""
            echo "    Skipping X install.  cool-retro-term will not be usable until"
            echo "    an X server is installed.  Re-run this installer to add it later."
            INSTALL_CRT=false
        fi
    fi
fi

if $INSTALL_X; then
    _section "    Installing minimal X server..."
    sudo apt-get install -y \
        xorg \
        openbox \
        x11-xserver-utils
    echo "    Installed: xorg + openbox"
fi

if $INSTALL_CRT; then
    echo "    Installing cool-retro-term..."
    if apt-cache show cool-retro-term &>/dev/null 2>&1; then
        sudo apt-get install -y cool-retro-term
    else
        echo ""
        echo "    cool-retro-term not in apt — installing via Flatpak..."
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

# ── 3. Configure X kiosk (openbox + cool-retro-term) ──────────────────────────

if $INSTALL_CRT && ( _x_installed || $INSTALL_X ) && _openbox_installed; then

    _section "[3/8] Configuring X kiosk (openbox + cool-retro-term fullscreen)..."

    # ~/.xinitrc — start openbox as the sole WM
    cat > "$HOME/.xinitrc" << 'XINITRC'
#!/usr/bin/env bash
exec openbox-session
XINITRC
    chmod +x "$HOME/.xinitrc"
    echo "    Created: ~/.xinitrc"

    # ~/.config/openbox/autostart — launch CRT then exit X when it closes
    mkdir -p "$HOME/.config/openbox"
    cat > "$HOME/.config/openbox/autostart" << AUTOSTART
#!/bin/sh
# MeshTTY kiosk: launch cool-retro-term fullscreen; shut down X when it exits
(cool-retro-term -e "$START_SCRIPT"; openbox --exit) &
AUTOSTART
    echo "    Created: ~/.config/openbox/autostart"

    # ~/.config/openbox/rc.xml — force cool-retro-term fullscreen, no decorations
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
    <!-- Ctrl+Alt+Backspace kills X as an emergency exit -->
    <keybind key="C-A-BackSpace">
      <action name="Execute"><command>openbox --exit</command></action>
    </keybind>
  </keyboard>

  <theme>
    <name>Clearlooks</name>
    <titleLayout>NLIMC</titleLayout>
  </theme>

  <desktops><number>1</number></desktops>

</openbox_config>
RCXML
    echo "    Created: ~/.config/openbox/rc.xml"

    echo ""
    echo "    Import a MeshTTY CRT profile once after install:"
    echo "      Open cool-retro-term → Settings → Profiles → Import"
    echo "      $SCRIPT_DIR/assets/crt-profiles/meshtty-amber.json"
    echo "      $SCRIPT_DIR/assets/crt-profiles/meshtty-phosphor.json"

else
    _section "[3/8] X kiosk config — skipped (cool-retro-term not being installed)."
fi

# ── 4. Python virtual environment ─────────────────────────────────────────────

_section "[4/8] Creating Python virtualenv at $VENV_DIR..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
echo "    Python: $( python --version )"

# ── 5. Python packages ────────────────────────────────────────────────────────

_section "[5/8] Installing Python dependencies..."
pip install --upgrade pip --quiet
pip install -r "$SCRIPT_DIR/requirements.txt" --quiet
pip install -e "$SCRIPT_DIR" --quiet

# ── 6. Verify ─────────────────────────────────────────────────────────────────

_section "[6/8] Verifying installation..."

python -c "import meshtastic" 2>/dev/null \
    && echo "    OK: meshtastic $( python -c 'import meshtastic; print(meshtastic.__version__)' )" \
    || { echo "ERROR: meshtastic failed to import."; exit 1; }

python -c "import textual" 2>/dev/null \
    && echo "    OK: textual $( python -c 'import textual; print(textual.__version__)' )" \
    || { echo "ERROR: textual failed to import."; exit 1; }

command -v meshtastic &>/dev/null \
    && echo "    OK: meshtastic CLI at $( command -v meshtastic )" \
    || { echo "ERROR: meshtastic CLI not found."; exit 1; }

# ── 7. Hardware permissions ───────────────────────────────────────────────────

_section "[7/8] Hardware access permissions..."
sudo usermod -aG dialout  "$USER"
sudo usermod -aG bluetooth "$USER"
# video group needed for direct framebuffer / GPU access on Pi
sudo usermod -aG video "$USER"
echo "    Added $USER to: dialout, bluetooth, video"
echo "    NOTE: Log out and back in for these to take effect."

# GPU driver suggestion for Pi 4 / Pi 5
PI_REV="$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')"
if echo "$PI_REV" | grep -qE "Pi [45]"; then
    BOOT_CONFIG=""
    for f in /boot/firmware/config.txt /boot/config.txt; do
        [ -f "$f" ] && { BOOT_CONFIG="$f"; break; }
    done
    if [ -n "$BOOT_CONFIG" ] && ! grep -q "vc4-kms-v3d" "$BOOT_CONFIG"; then
        echo ""
        echo "    Pi 4/5 detected.  For best cool-retro-term GPU performance, add"
        echo "    the KMS video driver to $BOOT_CONFIG:"
        echo "      dtoverlay=vc4-kms-v3d"
        if _ask "    Add dtoverlay=vc4-kms-v3d to $BOOT_CONFIG now?"; then
            echo "" | sudo tee -a "$BOOT_CONFIG" > /dev/null
            echo "dtoverlay=vc4-kms-v3d" | sudo tee -a "$BOOT_CONFIG" > /dev/null
            echo "    Added.  A reboot is required for it to take effect."
        fi
    fi
fi

# ── 8. Generate start scripts ─────────────────────────────────────────────────

_section "[8/8] Generating start scripts..."

# meshtty.sh — plain terminal launcher (also used as the inner command by X kiosk)
cat > "$START_SCRIPT" << STARTSCRIPT
#!/usr/bin/env bash
# meshtty.sh — launch MeshTTY in the current terminal
# Generated by install-pi.sh — safe to re-run install-pi.sh to regenerate.

VENV="$VENV_DIR"
APP_DIR="$SCRIPT_DIR"

if ! [[ -t 0 && -t 1 ]]; then
    echo "ERROR: MeshTTY requires an interactive terminal." >&2
    exit 1
fi

if [[ "\$TERM" == "dumb" || -z "\$TERM" ]]; then
    export TERM=xterm-256color
fi

if [[ ! -f "\$VENV/bin/activate" ]]; then
    echo "ERROR: virtualenv not found at \$VENV — re-run install-pi.sh" >&2
    exit 1
fi

source "\$VENV/bin/activate"
cd "\$APP_DIR"

# Wait up to 10 s for a USB serial device to enumerate at boot
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
if [[ \$# -eq 0 && -f "\$FLAGS_FILE" ]]; then
    SAVED_FLAGS=\$(cat "\$FLAGS_FILE")
fi

# shellcheck disable=SC2086
exec python -m meshtty.main \$SAVED_FLAGS "\$@"
STARTSCRIPT
chmod +x "$START_SCRIPT"
echo "    Created: $START_SCRIPT"

# launch-pi.sh is already in the repo — just ensure it's executable
chmod +x "$LAUNCH_SCRIPT" 2>/dev/null || true
echo "    Ready:   $LAUNCH_SCRIPT"

# ── Optional: tty1 auto-launch ────────────────────────────────────────────────

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
    if ! grep -q "meshtty auto-launch" "$BASH_PROFILE" 2>/dev/null \
       && ! grep -q "meshtty auto-launch" "$HOME/.bashrc" 2>/dev/null; then
        echo "$LAUNCH_BLOCK" >> "$BASH_PROFILE"
        echo "    Auto-launch block added to $BASH_PROFILE"
        echo "    Configure Pi for console auto-login:"
        echo "      sudo raspi-config → System Options → Boot / Auto Login → Console Autologin"
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
    echo "    $SCRIPT_DIR/assets/crt-profiles/meshtty-amber.json"
    echo ""
fi
echo "  Logs: /tmp/meshtty.log"
echo ""
