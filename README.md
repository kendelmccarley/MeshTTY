# MeshTTY

> **PRE-ALPHA — work in progress.**
> This release has known bugs, incomplete features, and UI rough edges.
> It is published for development tracking only.  Expect breaking changes
> between commits.  Do not rely on it for real mesh-radio operations.

MeshTTY is a terminal-based (TUI) client for Meshtastic LoRa mesh radio
networks, designed to run on a Raspberry Pi or any Linux/macOS system with a
terminal.  It is built with the [Textual](https://textual.textualize.io/)
framework and communicates with a Meshtastic node over USB/serial, TCP/WiFi,
or Bluetooth (BLE).

MeshTTY is designed to run inside [cool-retro-term](https://github.com/Swordfish90/cool-retro-term)
for a retro CRT look — phosphor glow, scanlines, screen curvature, and bloom
effects rendered at the terminal emulator level.  It also runs in any standard
terminal without cool-retro-term.

---

## Table of Contents

1. [Installation](#1-installation)
   - 1.1 [Raspberry Pi and DietPi](#11-raspberry-pi-and-dietpi)
   - 1.2 [macOS and Ubuntu](#12-macos-and-ubuntu)
   - 1.3 [Manual install](#13-manual-install-any-platform)
2. [Updating](#2-updating)
3. [cool-retro-term Integration](#3-cool-retro-term-integration)
4. [Running MeshTTY](#4-running-meshtty)
5. [Command-Line Flags](#5-command-line-flags)
6. [Connection Screen](#6-connection-screen)
7. [Main Screen](#7-main-screen)
   - 7.1 [Messages Tab](#71-messages-tab)
   - 7.2 [Channels Tab](#72-channels-tab)
   - 7.3 [Nodes Tab](#73-nodes-tab)
   - 7.4 [Node Detail Modal](#74-node-detail-modal)
   - 7.5 [Settings Tab](#75-settings-tab)
   - 7.6 [DM Slash Commands](#76-dm-slash-commands)
8. [Keyboard Shortcuts](#8-keyboard-shortcuts)
9. [Configuration File](#9-configuration-file)
10. [Message & Node Database](#10-message--node-database)
11. [Themes](#11-themes)
12. [Debug Logging](#12-debug-logging)
13. [Serial Port Permissions (Linux)](#13-serial-port-permissions-linux)
14. [Known Issues & Missing Features](#14-known-issues--missing-features)
15. [Troubleshooting](#15-troubleshooting)
16. [Headless / Kiosk Operation (Raspberry Pi)](#16-headless--kiosk-operation-raspberry-pi)

---

## 1. Installation

### 1.1 Raspberry Pi and DietPi

Use the dedicated Pi installer — it handles Pi-specific setup including the
OpenGL driver, GPU memory, X kiosk configuration, and per-model warnings.

```bash
git clone https://github.com/kendelmccarley/MeshTTY.git
cd MeshTTY
bash install-pi.sh
```

**Supported platforms:**

| Hardware | OS | Notes |
|----------|----|-------|
| Pi Zero W | DietPi 32-bit, Raspberry Pi OS Lite | ARMv6 — install takes 30–90 min. Be patient. |
| Pi Zero 2 W | DietPi 32-bit, Raspberry Pi OS Lite | ARMv7 — faster than Zero W |
| Pi 3B / 3B+ | Raspberry Pi OS Lite / Desktop | Full support |
| Pi 4B | Raspberry Pi OS Lite / Desktop | Full support |
| Pi 5 | Raspberry Pi OS Lite / Desktop | Full support |

The installer will:

- Install system packages via `apt`
- Optionally install cool-retro-term and a minimal X server (xorg + openbox)
- Check and configure the OpenGL driver (`vc4-kms-v3d`) if cool-retro-term is requested
- Check and raise `gpu_mem` if it is set too low (DietPi defaults to 16 MB; cool-retro-term needs ≥ 64 MB)
- Check available RAM + swap and warn if under 512 MB
- Handle ARMv6 pip failures gracefully (grpcio wheel incompatibility on Pi Zero W)
- Create a Python virtualenv at `~/.venv/meshtty`
- Add your user to the `dialout`, `bluetooth`, and `video` groups
- Generate `meshtty.sh` and make `launch-pi.sh` executable
- Optionally configure tty1 auto-launch for kiosk operation

Log out and back in after the install for group membership to take effect.

### 1.2 macOS and Ubuntu

```bash
git clone https://github.com/kendelmccarley/MeshTTY.git
cd MeshTTY
bash install.sh
```

**macOS prerequisite:** [Homebrew](https://brew.sh) must be installed first.

The installer handles system packages, virtualenv, optional cool-retro-term,
and generates `meshtty.sh`.

### 1.3 Manual install (any platform)

```bash
python3 -m venv ~/.venv/meshtty
source ~/.venv/meshtty/bin/activate
pip install -e .
```

**Dependencies installed automatically:**

| Package        | Purpose                                          |
|----------------|--------------------------------------------------|
| textual ≥ 0.80 | TUI framework (rendering, widgets, key bindings) |
| meshtastic     | Meshtastic Python library (serial/TCP/BLE)       |
| bleak          | Bluetooth BLE scanning                           |
| pyserial       | Serial port enumeration and communication        |
| pypubsub       | Event pub/sub (used internally by meshtastic)    |
| protobuf       | Meshtastic protocol buffer serialization         |
| anyio          | Async I/O support                                |

Python 3.11 or newer is required (Python 3.9 on Pi Zero W via system Python is
sufficient).

---

## 2. Updating

```bash
bash update.sh
```

`update.sh` will:

1. Warn if there are uncommitted local changes before pulling
2. Run `git pull --ff-only` from the tracked remote branch
3. Print a changelog of commits since the last update
4. Re-run `pip install` only if `requirements.txt` changed
5. Re-install the local package to pick up source changes
6. Ensure all launch scripts are executable

---

## 3. cool-retro-term Integration

MeshTTY's UI is styled to complement [cool-retro-term](https://github.com/Swordfish90/cool-retro-term),
a terminal emulator that renders GPU-accelerated CRT effects: phosphor glow,
bloom, scanlines, screen curvature, static noise, and flicker.  Because these
effects are rendered by the terminal emulator itself, they wrap the MeshTTY
TUI automatically — no changes to MeshTTY's Python code are needed.

### Install cool-retro-term

```bash
# macOS
brew install --cask cool-retro-term

# Raspberry Pi OS / Ubuntu / DietPi
sudo apt install cool-retro-term
```

The installers (`install.sh` and `install-pi.sh`) will offer to do this for you.

### OpenGL driver requirement (Raspberry Pi)

cool-retro-term's shaders require the `vc4-kms-v3d` OpenGL driver on all Pi
models, including the Pi Zero W and Zero 2 W.  `install-pi.sh` checks for
this and offers to add it to `/boot/config.txt`.  A reboot is required after
enabling it.

GPU memory must be at least 64 MB.  DietPi defaults to `gpu_mem=16` — the
installer will detect this and offer to raise it.

### Import a MeshTTY CRT profile

Bundled profiles in `assets/crt-profiles/` are tuned for MeshTTY's TUI.
Import one **once** after installing cool-retro-term:

1. Open cool-retro-term
2. **Settings → Profiles → Import**
3. Choose the profile for your hardware

| File | Best for | Appearance |
|------|----------|------------|
| `meshtty-amber.json` | Pi 3/4/5, macOS, Ubuntu | Warm `#ff8100` amber — full CRT effects |
| `meshtty-phosphor.json` | Pi 3/4/5, macOS, Ubuntu | `#0ccc68` green — full CRT effects |
| `meshtty-zero.json` | **Pi Zero W / Zero 2 W** | Green phosphor, all GPU-heavy effects disabled |

`meshtty-zero.json` disables scanlines, screen curvature, static noise,
phosphor burnin, and flicker — leaving only the phosphor color and minimal
bloom.  This is the right choice for VideoCore IV on Zero hardware where GPU
headroom is limited.

### Launch with cool-retro-term

**macOS / Ubuntu:**
```bash
./launch.sh          # auto-selects cool-retro-term if installed
./meshtty-crt.sh     # explicit cool-retro-term launcher
```

**Raspberry Pi:**
```bash
./launch-pi.sh       # context-aware: plain terminal over SSH, CRT kiosk on tty
```

The CRT effects are rendered entirely by cool-retro-term.  MeshTTY's Textual
themes provide the phosphor color palette so the UI colours match the CRT
profile.

---

## 4. Running MeshTTY

### Raspberry Pi

`launch-pi.sh` is the recommended entry point.  It detects the runtime context
and chooses the appropriate launcher automatically:

| Context | What happens |
|---------|-------------|
| SSH session | Runs in the plain terminal |
| `$DISPLAY` already set (inside X) | Launches cool-retro-term fullscreen |
| Physical tty, X + openbox available | Starts X → openbox → cool-retro-term fullscreen |
| Physical tty, no X | Runs in the plain terminal |

```bash
./launch-pi.sh
./launch-pi.sh --bot --log    # pass flags through
```

### macOS / Ubuntu

`launch.sh` auto-detects cool-retro-term and uses it if installed:

```bash
./launch.sh                # auto-detect
./launch.sh --plain        # force plain terminal
./launch.sh --crt          # force cool-retro-term (errors if not installed)
./launch.sh --bot --log    # pass flags through
```

### Direct launchers

```bash
./meshtty.sh               # plain terminal (generated by installer)
./meshtty-crt.sh           # cool-retro-term (macOS / Ubuntu)
python -m meshtty.main     # direct, using active virtualenv
```

The app starts on the **Connection Screen**.  Once connected it switches
automatically to the **Main Screen**.

---

## 5. Command-Line Flags

`--plain` and `--crt` are consumed by `launch.sh`.  All other flags are
passed through to MeshTTY:

| Flag       | Description                                                          |
|------------|----------------------------------------------------------------------|
| `--debug`  | Enable DEBUG-level logging to `/tmp/meshtty.log`.                    |
| `--bot`    | Enable the DM slash-command bot (see section 7.6).                   |
| `--log`    | Log all inbound and outbound messages to `/tmp/meshtty-messages.log`.|
| `--noargs` | Clear saved startup flags and launch with no flags active.           |
| `-h`       | Print help and exit.                                                 |

Flags are persisted across reboots.  The last set of flags used is saved to
`~/.config/meshtty/last_flags` and replayed on the next launch unless new
flags are passed explicitly or `--noargs` is used.

---

## 6. Connection Screen

The first screen shown on launch.  Choose how to connect to your radio node.

### Tabs

#### SERIAL/USB

- The app scans for serial ports whose USB vendor ID matches common Meshtastic
  chips and lists them in a table.
- Click a row to copy that port path into the input field, or type it manually
  (e.g. `/dev/ttyUSB0`, `/dev/ttyACM0`).
- Click **CONNECT**.

#### TCP/WIFI

- Enter the hostname or IP address of the node and the port (default 4403).
- Click **CONNECT**.

#### BLE

- Click **SCAN FOR BLE DEVICES** to perform a 5-second scan.
- Click a row or enter a MAC address manually.
- Click **CONNECT**.

### Remember this device

The **Remember this device** switch (on by default) saves connection details
so the same transport and address are pre-filled on the next launch.

### Auto-connect

If a device was remembered from a previous session, the connection screen
starts a 5-second countdown and connects automatically.  Press any key, switch
tabs, or click a button to cancel.

### Status messages

Progress is shown in a status line: "Connecting…", "Connected — downloading
nodes: …", "Download complete…", "Connected! (N nodes loaded)".  Errors appear
in red below it.

> **Note:** On busy networks, the app transitions to the Main Screen as soon
> as the initial radio handshake completes.  Node records continue arriving
> in the background.

---

## 7. Main Screen

After a successful connection the app switches to the Main Screen, which has
four tabs.  The status bar across the top shows connection state, active
channel, node count, and local battery level.

---

### 7.1 Messages Tab

A unified, scrollable message history for all channels and direct messages,
plus a compose bar at the bottom.

#### Message display

```
HH:MM prefix: message text
```

- **Incoming broadcasts** — labelled with the channel name (`Primary`, `LongFast`, etc.)
- **Incoming direct messages** — labelled with the sender's short name
- **Outgoing messages** — indented two spaces, displayed in accent color
- Long lines wrap aligned under the message text

#### Compose bar

Edit the prefix to target a channel or node short name, then type your message:

```
prefix: your message text
```

- Prefix matches a channel name → broadcast on that channel
- Prefix matches a node short name → direct message to that node
- Press **Enter** or click **SEND**

#### Scrolling

Up/Down arrows and PageUp/PageDown scroll the history regardless of focus.

#### History

The 200 most recent messages are loaded from the local database on startup.

---

### 7.2 Channels Tab

Lists all channels configured on the radio.  Click a channel to set it as
the compose prefix; the app switches to Messages automatically.

---

### 7.3 Nodes Tab

Live table of all mesh nodes.  Updates in real time.

| Column     | Description                                      |
|------------|--------------------------------------------------|
| Short      | 4-character callsign                             |
| Long Name  | Full node name                                   |
| SNR        | Last signal-to-noise ratio (dB)                  |
| Last Heard | Time of last packet (HH:MM:SS local)             |
| Battery    | Battery level (%)                                |
| Position   | GPS coordinates (lat, lon)                       |
| HW Model   | Hardware model string                            |

**Ctrl+R** forces a refresh.  Click any row to open the Node Detail Modal.

---

### 7.4 Node Detail Modal

Shows node ID, short/long name, hardware model, last SNR, last heard,
battery level, and GPS position.  Close with **CLOSE**, **Escape**, or **Q**.

---

### 7.5 Settings Tab

Configure transport, display, and messaging defaults.  Click **SAVE** to
apply.  The **Theme** setting takes effect immediately; other settings apply
on the next connection.

---

### 7.6 DM Slash Commands

Enable with `--bot`.  Incoming DMs starting with `/` trigger automatic replies:

| Command    | Response                                              |
|------------|-------------------------------------------------------|
| `/HELP`    | Lists all available commands                          |
| `/INFO`    | Returns the MeshTTY repository URL                   |
| `/JOKE`    | Returns the next joke from the joke file              |
| `/GPIO`    | Returns exported GPIO pin states                      |
| `/WEATHER` | Placeholder (not implemented)                         |
| `/NEWS`    | Placeholder                                           |
| `/NULL`    | Returns "All is nothingness"                          |

Commands are case-insensitive.  `/JOKE` requires `meshtty/data/shortjokes.csv`
(not included — compatible file at
[Kaggle Short Jokes dataset](https://www.kaggle.com/datasets/abhinavmoudgil95/short-jokes)).

---

## 8. Keyboard Shortcuts

### Connection Screen

| Key    | Action |
|--------|--------|
| Ctrl+Q | Quit   |

### Main Screen

| Key       | Action                                     |
|-----------|--------------------------------------------|
| F1        | Help overlay                               |
| Ctrl+T    | Switch to MESSAGES tab                     |
| Ctrl+L    | Switch to CHANNELS tab                     |
| Ctrl+N    | Switch to NODES tab                        |
| Ctrl+S    | Switch to SETTINGS tab                     |
| ↑ / ↓    | Scroll message history one line            |
| PgUp/PgDn | Scroll message history one screen          |
| Ctrl+R    | Refresh node table                         |
| Ctrl+D    | Disconnect → Connection Screen             |
| Ctrl+Q    | Quit                                       |

### Node Detail Modal

| Key    | Action |
|--------|--------|
| Escape | Close  |
| Q      | Close  |

---

## 9. Configuration File

**Location:** `~/.config/meshtty/config.json`

Created automatically on first run.

```json
{
  "default_transport": "serial",
  "last_serial_port": "/dev/ttyUSB0",
  "last_tcp_host": "",
  "last_tcp_port": 4403,
  "last_ble_address": "",
  "auto_connect": true,
  "log_level": "WARNING",
  "db_path": "~/.config/meshtty/messages.db",
  "default_channel": 0,
  "node_short_name_display": true,
  "theme": "crt-amber"
}
```

| Key                       | Type    | Default       | Description                          |
|---------------------------|---------|---------------|--------------------------------------|
| `default_transport`       | string  | `"serial"`    | `"serial"`, `"tcp"`, or `"ble"`     |
| `last_serial_port`        | string  | `""`          | Serial device path                   |
| `last_tcp_host`           | string  | `""`          | TCP hostname or IP                   |
| `last_tcp_port`           | integer | `4403`        | TCP port                             |
| `last_ble_address`        | string  | `""`          | BLE MAC address                      |
| `auto_connect`            | boolean | `true`        | Start countdown if device remembered |
| `log_level`               | string  | `"WARNING"`   | `DEBUG`, `INFO`, `WARNING`, `ERROR`  |
| `db_path`                 | string  | *(see above)* | SQLite database path                 |
| `default_channel`         | integer | `0`           | Default channel index (0–7)          |
| `node_short_name_display` | boolean | `true`        | Use short names in Nodes table       |
| `theme`                   | string  | `"crt-amber"` | UI theme (see section 11)            |

---

## 10. Message & Node Database

**Location:** `~/.config/meshtty/messages.db`

SQLite database created automatically.

### `messages` table

| Column           | Type    | Description                                        |
|------------------|---------|----------------------------------------------------|
| `id`             | INTEGER | Auto-increment primary key                         |
| `packet_id`      | TEXT    | Meshtastic packet ID (NULL for sent messages)      |
| `from_id`        | TEXT    | Sender node ID (e.g. `!abcd1234`)                  |
| `to_id`          | TEXT    | Recipient node ID or `^all`                        |
| `channel`        | INTEGER | Channel index (0–7)                                |
| `text`           | TEXT    | Message text                                       |
| `rx_time`        | INTEGER | Unix timestamp (seconds)                           |
| `is_mine`        | INTEGER | `1` = sent, `0` = received                        |
| `display_prefix` | TEXT    | Human-readable prefix at send/receive time         |

### `nodes` table

| Column       | Type    | Description                             |
|--------------|---------|-----------------------------------------|
| `node_id`    | TEXT    | Primary key                             |
| `short_name` | TEXT    | 4-character callsign                    |
| `long_name`  | TEXT    | Full node name                          |
| `hw_model`   | TEXT    | Hardware model string                   |
| `last_snr`   | REAL    | Last SNR (dB)                           |
| `last_lat`   | REAL    | Last latitude                           |
| `last_lon`   | REAL    | Last longitude                          |
| `last_alt`   | INTEGER | Last altitude (metres)                  |
| `battery`    | INTEGER | Battery level (%)                       |
| `last_heard` | INTEGER | Unix timestamp of last packet           |
| `updated_at` | INTEGER | Unix timestamp of last database write   |

```sql
-- All messages, newest first
SELECT datetime(rx_time,'unixepoch','localtime') AS time, display_prefix, text
FROM messages ORDER BY rx_time DESC LIMIT 50;

-- All known nodes
SELECT node_id, short_name, long_name, battery, last_snr FROM nodes;
```

---

## 11. Themes

Three built-in themes selectable from SETTINGS → Theme.  Each is drawn from
a cool-retro-term color profile — pair them for the full effect.

| Config value   | Label          | CRT profile             | Appearance                              |
|----------------|----------------|-------------------------|-----------------------------------------|
| `crt-amber`    | Amber          | meshtty-amber.json      | Warm `#ff8100` amber on black. **Default.** |
| `crt-phosphor` | Green Phosphor | meshtty-phosphor.json   | Classic `#0ccc68` green on black        |
| `crt-ibm`      | IBM VGA        | *(no dedicated profile)*| Cool `#c0c0c0` grey on black            |

On Pi Zero W / Zero 2 W, pair any theme with `meshtty-zero.json` in
cool-retro-term rather than the full-effects profiles.

---

## 12. Debug Logging

```bash
./launch-pi.sh --debug    # Pi
./launch.sh --debug       # macOS / Ubuntu
tail -f /tmp/meshtty.log
```

### Common errors

| Error | Likely cause |
|-------|-------------|
| `PermissionError: [Errno 13] ... '/dev/ttyUSB0'` | Not in `dialout` group — see section 13 |
| `serial.serialutil.SerialException: could not open port` | Wrong port or device not plugged in |
| `ConnectionRefusedError` | TCP host/port wrong or node unreachable |
| `_waitConnected timed out but N nodes present` | Noisy serial stream — transport forces connection and proceeds |
| `waitForConfig timed out but myInfo and N nodes present` | Incomplete radio config — usually harmless |

---

## 13. Serial Port Permissions

### Linux (Raspberry Pi OS, DietPi, Ubuntu)

```bash
sudo usermod -aG dialout $USER
```

Log out and back in.  Verify with `groups` — output should include `dialout`.

Both `install.sh` and `install-pi.sh` handle this automatically.

### macOS

No group membership required.  Serial devices appear as `/dev/cu.usbserial-XXXX`
or `/dev/cu.SLAB_USBtoUART`.  Run `ls /dev/cu.*` with the radio plugged in.

---

## 14. Known Issues & Missing Features

### Confirmed bugs

- **`display_prefix` missing from old database rows** — Messages stored before
  this version fall back to displaying the raw `from_id` node string.

### Not yet implemented

- Channel switching confirmation
- Message acknowledgement display
- Persistent compose prefix across sessions
- BLE transport (largely untested)
- Node position map view
- Channel creation / management
- Firmware version / radio config display
- New message notification on non-active tab

---

## 15. Troubleshooting

### Slow connection or hangs during node download

Run with `--debug` and watch the log.  Timeouts like
`_waitConnected timed out but N nodes present` are usually harmless — the
transport forces a connection and node records continue arriving.  If
completely stuck, quit (Ctrl+Q) and reconnect.

### Serial device detected but connection fails

1. Run with `--debug`, check `/tmp/meshtty.log`
2. Confirm `dialout` group membership (section 13)
3. Unplug and re-plug the USB cable
4. Test with the CLI: `meshtastic --port /dev/ttyUSB0 --info`

### No serial devices in the auto-scan list

The scanner filters by USB vendor ID.  Supported chips:

| Chip                | USB VID |
|---------------------|---------|
| Silicon Labs CP210x | 10C4    |
| WCH CH340 / CH341   | 1A86    |
| FTDI                | 0403    |
| Espressif USB-JTAG  | 303A    |

If your adapter uses a different chip, enter the port path manually.

### BLE issues on Pi Zero W

The Pi Zero W's combined Wi-Fi/BT chip (CYW43438) can cause interference
between Wi-Fi and BLE.  If BLE scanning fails or connections drop:

- Ensure BlueZ is version 5.55 or newer: `bluetoothctl --version`
- Try disabling Wi-Fi while using BLE: `rfkill block wifi`
- Use serial or TCP transport instead — they are more reliable on Zero hardware

### cool-retro-term fails to open on Pi

Most likely cause: OpenGL driver not configured.  Check:

```bash
grep -E "vc4|dtoverlay" /boot/config.txt
```

If `vc4-kms-v3d` is not present, add it and reboot:

```bash
echo "dtoverlay=vc4-kms-v3d" | sudo tee -a /boot/config.txt
sudo reboot
```

Also check `gpu_mem`:

```bash
grep gpu_mem /boot/config.txt
```

If it is set to less than 64, change it to `gpu_mem=64` and reboot.
DietPi defaults to `gpu_mem=16` — `install-pi.sh` will detect and fix this.

### Pi Zero W: pip install fails or takes very long

The Pi Zero W (ARMv6, single-core 1 GHz) is slow to compile Python packages.
Expected install time is 30–90 minutes.  Do not interrupt pip once it starts.

If pip fails with a `grpcio` or "illegal instruction" error, `install-pi.sh`
handles this automatically by retrying without `grpcio` (meshtastic ≥ 2.5 no
longer requires it).  If running pip manually:

```bash
pip install textual meshtastic pyserial bleak pypubsub protobuf anyio
```

### DietPi: swap too low for pip install

DietPi's zram swap may not be enough for compiling packages on a Zero W.
Increase it via:

```
dietpi-config → Performance Options → Swap
```

Set to 1024 MB for the install, then reduce back to 256 MB afterward to
preserve SD card write life.

### Config file ignored or reset

```bash
python3 -m json.tool ~/.config/meshtty/config.json
```

If `"theme"` contains an unrecognised value, the app silently resets it to
`crt-amber`.

---

## 16. Headless / Kiosk Operation (Raspberry Pi)

MeshTTY is designed to run as a full-screen kiosk on a headless Pi connected
to a physical display — no desktop environment required.

### Setup

1. Configure console auto-login:
   - **Raspberry Pi OS:** `sudo raspi-config` → System Options → Boot / Auto Login → Console Autologin
   - **DietPi:** `dietpi-config` → AutoStart Options → set to `0` (console autologin), or run `sudo dietpi-autostart`
2. Run `install-pi.sh` and answer **Y** when asked about auto-launch and cool-retro-term

The installer adds a block to `~/.bash_profile`:

```bash
# MeshTTY auto-launch on tty1 (physical Pi screen)
if [[ "$(tty)" == "/dev/tty1" ]]; then
    export TERM=xterm-256color
    while true; do
        /path/to/MeshTTY/launch-pi.sh
        sleep 2
    done
fi
```

`launch-pi.sh` detects whether X is available and starts it if so, or falls
back to the plain terminal — no manual configuration needed.

### Boot sequence with cool-retro-term kiosk

| Step | What happens |
|------|-------------|
| Pi boots, user auto-logs in on tty1 | `~/.bash_profile` starts restart loop |
| `launch-pi.sh` runs | Detects X + openbox available |
| `startx` launches | openbox starts, runs `~/.config/openbox/autostart` |
| Autostart runs | `cool-retro-term` opens fullscreen with `meshtty.sh` inside |
| Openbox rc.xml rule | Forces cool-retro-term fullscreen, no window decorations |
| MeshTTY starts | Connection screen appears |
| User quits MeshTTY | cool-retro-term closes, autostart calls `openbox --exit` |
| X shuts down | `startx` returns to `launch-pi.sh` |
| Restart loop fires | `sleep 2`, then everything starts again |

**Emergency exit:** Ctrl+Alt+Backspace shuts down X immediately.

### Boot sequence without cool-retro-term (plain terminal)

| Step | What happens |
|------|-------------|
| Pi boots, user auto-logs in on tty1 | `~/.bash_profile` starts restart loop |
| `launch-pi.sh` runs | No X available — runs `meshtty.sh` directly |
| MeshTTY starts in the console TTY | Connection screen appears |
| App exits for any reason | `sleep 2`, then restarts |

### Troubleshooting a headless Pi

SSH in to investigate without disturbing the console:

```bash
ssh user@<pi-hostname>
tail -f /tmp/meshtty.log
cat /tmp/meshtty-x.log      # X server errors if cool-retro-term kiosk fails
```

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Black screen / nothing starts | User not in `dialout` group | `sudo usermod -aG dialout $USER` then reboot |
| "Waiting for USB serial device…" then fails | Radio not plugged in | Plug in before booting; check `dmesg \| grep tty` |
| Auto-connect does not fire | No saved device | Connect once manually with **Remember this device** checked |
| X starts but cool-retro-term is blank / crashes | OpenGL driver missing or gpu_mem too low | See section 15 — add `vc4-kms-v3d` and set `gpu_mem=64` |
| cool-retro-term opens but immediately closes | `meshtty.sh` not found or virtualenv missing | Re-run `install-pi.sh` |
| App crashes immediately on tty | `TERM` not set | Ensure `~/.bash_profile` sets `TERM=xterm-256color` |
| Pi Zero W install hangs for >90 min | Normal on ARMv6 | Wait — do not interrupt |
