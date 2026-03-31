# MeshTTY

> **PRE-ALPHA — work in progress.**
> Known bugs, incomplete features, and UI rough edges.
> Published for development tracking only. Expect breaking changes between commits.

MeshTTY is a terminal-based (TUI) client for [Meshtastic](https://meshtastic.org/) LoRa mesh radio networks. It runs on a Raspberry Pi or any Linux/macOS system with a terminal. Built with the [Textual](https://textual.textualize.io/) framework, it connects to a Meshtastic node over USB/serial, TCP/WiFi, or Bluetooth (BLE) and renders a classic 80×24 box-drawing UI that works in any terminal — no desktop environment, GPU, or X server required.

---

## Table of Contents

1. [Installation](#1-installation)
   - 1.1 [Raspberry Pi and DietPi](#11-raspberry-pi-and-dietpi)
   - 1.2 [macOS and Ubuntu](#12-macos-and-ubuntu)
   - 1.3 [Manual install](#13-manual-install-any-platform)
2. [Updating](#2-updating)
3. [Running MeshTTY](#3-running-meshtty)
4. [Command-Line Flags](#4-command-line-flags)
5. [Connection Screen](#5-connection-screen)
6. [Main Screen](#6-main-screen)
   - 6.1 [Messages Tab](#61-messages-tab)
   - 6.2 [Channels Tab](#62-channels-tab)
   - 6.3 [Nodes Tab](#63-nodes-tab)
   - 6.4 [Node Detail Modal](#64-node-detail-modal)
   - 6.5 [Settings Tab](#65-settings-tab)
   - 6.6 [DM Slash Commands](#66-dm-slash-commands)
7. [Keyboard Shortcuts](#7-keyboard-shortcuts)
8. [Configuration File](#8-configuration-file)
9. [Message & Node Database](#9-message--node-database)
10. [Themes](#10-themes)
11. [Debug Logging](#11-debug-logging)
12. [Serial Port Permissions (Linux)](#12-serial-port-permissions-linux)
13. [Known Issues & Missing Features](#13-known-issues--missing-features)
14. [Troubleshooting](#14-troubleshooting)
15. [Headless / Kiosk Operation (Raspberry Pi)](#15-headless--kiosk-operation-raspberry-pi)

---

## 1. Installation

### 1.1 Raspberry Pi and DietPi

```bash
git clone https://github.com/kendelmccarrey/MeshTTY.git
cd MeshTTY
bash install-pi.sh
```

**Supported hardware:**

| Hardware | OS | Notes |
|----------|----|-------|
| Pi Zero W | Raspberry Pi OS Lite, DietPi 32-bit | ARMv6 — install takes 30–90 min |
| Pi Zero 2 W | Raspberry Pi OS Lite, DietPi 32-bit | ARMv7 |
| Pi 3B / 3B+ | Raspberry Pi OS Lite / Desktop | Full support |
| Pi 4B | Raspberry Pi OS Lite / Desktop | Full support |
| Pi 5 | Raspberry Pi OS Lite / Desktop | Full support |

The installer will:

- Install system packages (`python3-full`, `python3-venv`, `bluez`, `fonts-terminus`, etc.)
- Create a Python virtualenv at `~/.venv/meshtty` (using `--copies` to avoid PEP 668 issues on Bookworm/Trixie)
- Handle ARMv6 pip failures gracefully (grpcio wheel incompatibility on Pi Zero W)
- Add your user to the `dialout`, `bluetooth`, and `video` groups
- Generate `meshtty.sh` and make `launch-pi.sh` executable
- Optionally configure tty1 auto-launch for kiosk operation
- Optionally enable `loginctl enable-linger` for user systemd services

Log out and back in after the install for group membership to take effect.

### 1.2 macOS and Ubuntu

```bash
git clone https://github.com/kendelmccarrey/MeshTTY.git
cd MeshTTY
bash install.sh
```

**macOS prerequisite:** [Homebrew](https://brew.sh) must be installed first.

The installer handles system packages, virtualenv creation, and generates `meshtty.sh`.

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

Python 3.11 or newer is required.

---

## 2. Updating

```bash
bash update.sh
```

`update.sh` will:

1. Warn if there are uncommitted local changes before pulling
2. Run `git pull --ff-only`
3. Print a changelog of commits since the last update
4. Re-run `pip install` only if `requirements.txt` changed
5. Re-install the local package to pick up source changes
6. Ensure all launch scripts are executable

---

## 3. Running MeshTTY

### Raspberry Pi

| Script | Use when |
|--------|----------|
| `./launch-pi.sh` | **Recommended.** Physical screen — loads large Terminus font so 80 columns fills the display. Also works over SSH (skips font load). |
| `./meshtty.sh` | Any terminal — launches directly with no font adjustment. |

```bash
./launch-pi.sh
./launch-pi.sh --bot --log    # pass flags through
```

`launch-pi.sh` detects whether it is running on the Linux framebuffer console (`$TERM=linux`, not SSH, not X). On the physical screen it loads `Terminus32x16` to scale the 80×24 grid to fill a 1366×768 display. It then sets `TERM=xterm-256color` before launching MeshTTY.

### macOS / Ubuntu

```bash
./launch.sh                # thin wrapper around meshtty.sh
./meshtty.sh               # direct launcher
python -m meshtty.main     # using active virtualenv
```

The app starts on the **Connection Screen**. Once connected it switches automatically to the **Main Screen**.

---

## 4. Command-Line Flags

| Flag       | Description                                                          |
|------------|----------------------------------------------------------------------|
| `--debug`  | Enable DEBUG-level logging to `/tmp/meshtty.log`.                    |
| `--bot`    | Enable the DM slash-command bot (see section 6.6).                   |
| `--log`    | Log all inbound and outbound messages to `/tmp/meshtty-messages.log`.|
| `--noargs` | Clear saved startup flags and launch with no flags active.           |
| `-h`       | Print help and exit.                                                 |

Flags are persisted across reboots. The last set of flags is saved to `~/.config/meshtty/last_flags` and replayed on the next launch unless new flags are passed explicitly or `--noargs` is used.

---

## 5. Connection Screen

The first screen shown on launch. Choose how to connect to your radio node.

### Tabs

#### SERIAL/USB

- The app scans for serial ports matching common Meshtastic USB chips and lists them in a table.
- Click a row or type the port path manually (e.g. `/dev/ttyUSB0`, `/dev/ttyACM0`).
- Press **Enter** or click **CONNECT**.

#### TCP/WIFI

- Enter the hostname or IP address of the node and the port (default 4403).
- Press **Enter** or click **CONNECT**.

#### BLE

- Click **SCAN FOR BLE DEVICES** to perform a 5-second scan.
- Click a row or enter a MAC address manually.
- Click **CONNECT**.

### Remember this device

The **Remember this device** switch (on by default) saves connection details so the same transport and address are pre-filled on the next launch.

### Auto-connect

If a device was remembered from a previous session, the connection screen starts a 5-second countdown and connects automatically. Press any key, switch tabs, or click a button to cancel.

### Status messages

Progress is shown in a status line: *Connecting…*, *Connected — downloading nodes…*, *Download complete…*, *Connected! (N nodes loaded)*. Errors appear in red.

---

## 6. Main Screen

After a successful connection the app switches to the Main Screen, which has four tabs. The status bar at the top shows connection state and node count.

---

### 6.1 Messages Tab

A unified, scrollable message history for all channels and direct messages, plus a compose bar at the bottom.

#### Message display

```
HH:MM SenderName: message text
```

- All messages show the **sender's short node name** as the prefix — both channel broadcasts and direct messages.
- **Outgoing messages** are indented two spaces and displayed in accent colour.
- Long lines wrap aligned under the message text.
- The 200 most recent messages are loaded from the local database on startup.

#### Compose bar

The bottom row is split into two focus areas:

```
[ Channel   ][ type your message here…               ][ SEND ]
```

- **Left area (12 chars)** — shows the current channel name or DM node short name. Tab to focus it, then use **Up/Down** to cycle through conversations sorted by most recent message. Press **Enter** to advance to the message input.
- **Right area** — type your message and press **Enter** or click **SEND**.

Routing:
- If the selected prefix matches a **channel name** → broadcasts on that channel.
- If the selected prefix matches a **node short name** → sends as a direct message to that node.

#### Scrolling message history

- **Up/Down** — scroll one line when the message history or compose input has focus.
- **PageUp/PageDown** — scroll one screen from any focus.

---

### 6.2 Channels Tab

Lists all channels configured on the radio. Updates when the connection is established.

---

### 6.3 Nodes Tab

Live table of all mesh nodes heard on the network.

| Column     | Description                                      |
|------------|--------------------------------------------------|
| Short      | 4-character callsign                             |
| Long Name  | Full node name                                   |
| SNR        | Last signal-to-noise ratio (dB)                  |
| Last Heard | Time of last packet (HH:MM:SS local)             |
| Battery    | Battery level (%)                                |
| Position   | GPS coordinates (lat, lon)                       |
| HW Model   | Hardware model string                            |

**Ctrl+R** forces a refresh. Click any row to open the Node Detail Modal.

---

### 6.4 Node Detail Modal

Shows node ID, short/long name, hardware model, last SNR, last heard, battery level, and GPS position. Close with **CLOSE**, **Escape**, or **Q**.

---

### 6.5 Settings Tab

Configure transport, display, and messaging defaults. Shows current connection status and a **Disconnect** button. Click **SAVE** to write changes to disk. The **Theme** setting takes effect immediately.

---

### 6.6 DM Slash Commands

Enable with `--bot`. Incoming DMs starting with `/` trigger automatic replies:

| Command    | Response                                              |
|------------|-------------------------------------------------------|
| `/HELP`    | Lists all available commands                          |
| `/INFO`    | Returns the MeshTTY repository URL                   |
| `/JOKE`    | Returns the next joke from the joke file              |
| `/GPIO`    | Returns exported GPIO pin states                      |
| `/NULL`    | Returns "All is nothingness"                          |

Commands are case-insensitive. `/JOKE` requires `meshtty/data/shortjokes.csv` (not included — compatible file at [Kaggle Short Jokes dataset](https://www.kaggle.com/datasets/abhinavmoudgil95/short-jokes)).

---

## 7. Keyboard Shortcuts

### Connection Screen

| Key    | Action |
|--------|--------|
| Enter  | Connect (from any input field) |
| Ctrl+Q | Quit   |

### Main Screen — Global

| Key       | Action                         |
|-----------|--------------------------------|
| F1        | Help overlay                   |
| Ctrl+T    | Switch to MESSAGES tab         |
| Ctrl+L    | Switch to CHANNELS tab         |
| Ctrl+N    | Switch to NODES tab            |
| Ctrl+S    | Switch to SETTINGS tab         |
| Ctrl+R    | Refresh node table             |
| Ctrl+D    | Disconnect → Connection Screen |
| Ctrl+Q    | Quit                           |

### Messages Tab

| Key            | Focus              | Action                              |
|----------------|--------------------|-------------------------------------|
| Tab            | anywhere           | Cycle focus: history → channel → input → wrap |
| Shift+Tab      | anywhere           | Reverse focus cycle                 |
| Up / Down      | channel selector   | Cycle through channels and DM nodes |
| Enter          | channel selector   | Advance focus to message input      |
| Up / Down      | history or input   | Scroll message history              |
| PageUp/PageDown | anywhere          | Scroll message history              |
| Enter          | message input      | Send message                        |

### Node Detail Modal

| Key    | Action |
|--------|--------|
| Escape | Close  |
| Q      | Close  |

---

## 8. Configuration File

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
| `theme`                   | string  | `"crt-amber"` | UI theme (see section 10)            |

---

## 9. Message & Node Database

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
| `display_prefix` | TEXT    | Sender short name at time of receipt               |

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

## 10. Themes

Three built-in themes selectable from **Settings → Theme**. Each uses a phosphor-inspired colour palette designed to look good in any terminal.

| Config value   | Label          | Appearance                                  |
|----------------|----------------|---------------------------------------------|
| `crt-amber`    | Amber          | Warm `#ff8100` amber on black. **Default.** |
| `crt-phosphor` | Green Phosphor | Classic `#0ccc68` green on black            |
| `crt-ibm`      | IBM / Grey     | Cool `#c0c0c0` grey on black                |

The **Theme** setting in the Settings tab takes effect immediately without restarting.

---

## 11. Debug Logging

```bash
./launch-pi.sh --debug    # Pi
./launch.sh --debug       # macOS / Ubuntu
tail -f /tmp/meshtty.log
```

### Common errors

| Error | Likely cause |
|-------|-------------|
| `PermissionError: [Errno 13] ... '/dev/ttyUSB0'` | Not in `dialout` group — see section 12 |
| `serial.serialutil.SerialException: could not open port` | Wrong port or device not plugged in |
| `ConnectionRefusedError` | TCP host/port wrong or node unreachable |
| `_waitConnected timed out but N nodes present` | Noisy serial stream — transport forces connection and proceeds |

---

## 12. Serial Port Permissions

### Linux (Raspberry Pi OS, DietPi, Ubuntu)

```bash
sudo usermod -aG dialout $USER
```

Log out and back in. Verify with `groups` — output should include `dialout`.

Both `install.sh` and `install-pi.sh` handle this automatically.

### macOS

No group membership required. Serial devices appear as `/dev/cu.usbserial-XXXX` or `/dev/cu.SLAB_USBtoUART`. Run `ls /dev/cu.*` with the radio plugged in.

---

## 13. Known Issues & Missing Features

### Confirmed bugs

- Messages stored before the `display_prefix` column was added fall back to displaying the raw `from_id` node string.
- BLE transport is largely untested.

### Not yet implemented

- Message acknowledgement display
- Persistent compose prefix across sessions
- Node position map view
- Channel creation / management
- Firmware version / radio config display
- New message notification on non-active tab

---

## 14. Troubleshooting

### Slow connection or hangs during node download

Run with `--debug` and watch the log. Timeouts like `_waitConnected timed out but N nodes present` are usually harmless — the transport forces a connection and node records continue arriving. If completely stuck, quit (Ctrl+Q) and reconnect.

### Serial device detected but connection fails

1. Run with `--debug`, check `/tmp/meshtty.log`
2. Confirm `dialout` group membership (section 12)
3. Unplug and re-plug the USB cable
4. Test with the CLI: `meshtastic --port /dev/ttyUSB0 --info`

### No serial devices in the auto-scan list

The scanner filters by USB vendor ID. Supported chips:

| Chip                | USB VID |
|---------------------|---------|
| Silicon Labs CP210x | 10C4    |
| WCH CH340 / CH341   | 1A86    |
| FTDI                | 0403    |
| Espressif USB-JTAG  | 303A    |

If your adapter uses a different chip, enter the port path manually.

### BLE issues on Pi Zero W

The Pi Zero W's combined Wi-Fi/BT chip (CYW43438) can cause interference. If BLE scanning fails:

- Ensure BlueZ is version 5.55 or newer: `bluetoothctl --version`
- Try disabling Wi-Fi: `rfkill block wifi`
- Use serial or TCP transport instead — more reliable on Zero hardware.

### Pi Zero W: pip install fails or takes very long

Expected install time is 30–90 minutes. Do not interrupt pip once it starts.

If pip fails with a `grpcio` or "illegal instruction" error, `install-pi.sh` retries without `grpcio` automatically (meshtastic ≥ 2.5 no longer requires it).

### DietPi: swap too low for pip install

```
dietpi-config → Performance Options → Swap
```

Set to 1024 MB for the install, then reduce back to 256 MB afterward.

### Config file ignored or reset

```bash
python3 -m json.tool ~/.config/meshtty/config.json
```

If `"theme"` contains an unrecognised value, the app silently resets it to `crt-amber`.

---

## 15. Headless / Kiosk Operation (Raspberry Pi)

MeshTTY runs as a full-screen terminal application on a headless Pi with a physical display — no desktop environment, X server, or GPU required.

### Setup

1. Configure console auto-login:
   - **Raspberry Pi OS:** `sudo raspi-config` → System Options → Boot / Auto Login → Console Autologin
   - **DietPi:** `dietpi-config` → AutoStart Options → set to `0` (console autologin)
2. Run `install-pi.sh` and answer **Y** when asked about auto-launch on tty1.

The installer adds a block to `~/.bash_profile`:

```bash
# MeshTTY auto-launch on tty1 (physical Pi screen)
if [[ "$(tty)" == "/dev/tty1" ]]; then
    while true; do
        /path/to/MeshTTY/launch-pi.sh
        sleep 2
    done
fi
```

### Boot sequence

| Step | What happens |
|------|-------------|
| Pi boots, user auto-logs in on tty1 | `~/.bash_profile` starts restart loop |
| `launch-pi.sh` runs | Loads large Terminus font for framebuffer scaling |
| Sets `TERM=xterm-256color` | Ensures Textual renders correctly |
| Launches `meshtty.sh` | MeshTTY starts, connection screen appears |
| App exits for any reason | `sleep 2`, then restarts |

`launch-pi.sh` skips the font load automatically when running over SSH or inside X/Wayland.

### Troubleshooting a headless Pi

SSH in to investigate without disturbing the console:

```bash
ssh user@<pi-hostname>
tail -f /tmp/meshtty.log
```

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Blank screen / nothing starts | User not in `dialout` group | `sudo usermod -aG dialout $USER` then reboot |
| "Waiting for USB serial device…" then fails | Radio not plugged in | Plug in before booting; check `dmesg \| grep tty` |
| Auto-connect does not fire | No saved device | Connect once manually with **Remember this device** checked |
| Text too small on physical screen | Terminus font not installed | `sudo apt install fonts-terminus` |
| App crashes immediately | `TERM` not set | Ensure `TERM=xterm-256color` is exported before launch |
