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

MeshTTY runs on **Raspberry Pi OS**, **Ubuntu / Debian**, and **macOS 12+**.

```
git clone https://github.com/kendelmccarley/MeshTTY.git
cd MeshTTY
bash install.sh
```

The installer is interactive and handles everything:

- Installs system packages (`apt` on Linux/Pi, `brew` on macOS)
- Optionally installs **cool-retro-term** (see section 3)
- Creates a Python virtualenv at `~/.venv/meshtty`
- Installs all Python dependencies
- Adds your user to the `dialout` and `bluetooth` groups (Linux only)
- Generates `meshtty.sh`

**macOS prerequisite:** [Homebrew](https://brew.sh) must be installed first.

**Linux/Pi:** Log out and back in after running `install.sh` for serial and
Bluetooth group membership to take effect.

### Manual install (any platform)

```
python3 -m venv ~/.venv/meshtty
source ~/.venv/meshtty/bin/activate
pip install -e .
```

**Dependencies installed automatically:**

| Package       | Purpose                                          |
|---------------|--------------------------------------------------|
| textual ≥ 0.80 | TUI framework (rendering, widgets, key bindings)|
| meshtastic    | Meshtastic Python library (serial/TCP/BLE)       |
| bleak         | Bluetooth BLE scanning                           |
| pyserial      | Serial port enumeration and communication        |
| pypubsub      | Event pub/sub (used internally by meshtastic)    |
| protobuf      | Meshtastic protocol buffer serialization         |
| anyio         | Async I/O support                                |

Python 3.11 or newer is required.

---

## 2. Updating

```
bash update.sh
```

`update.sh` will:

1. Warn you if there are uncommitted local changes before pulling
2. Run `git pull --ff-only` from the tracked remote branch
3. Print a changelog of commits since the last update
4. Re-run `pip install` only if `requirements.txt` changed
5. Re-install the local package to pick up any source changes
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

# Raspberry Pi OS / Ubuntu
sudo apt install cool-retro-term
```

`install.sh` will offer to do this for you.

### Import a MeshTTY CRT profile

Two profiles tuned for MeshTTY's TUI are included in `assets/crt-profiles/`:

| File | Appearance |
|------|------------|
| `meshtty-amber.json` | Warm amber phosphor on black — classic 1970s terminal |
| `meshtty-phosphor.json` | Green phosphor on black — classic 1980s terminal |

Import one **once** after installing cool-retro-term:

1. Open cool-retro-term
2. **Settings → Profiles → Import**
3. Select `assets/crt-profiles/meshtty-amber.json` (or `meshtty-phosphor.json`)

Both profiles use:
- Terminus (TTF) font for sharp, readable monospace characters
- Low flicker and short phosphor burnin — readable for long sessions
- Medium bloom, subtle scanlines, and gentle screen curvature

### Launch with cool-retro-term

```bash
./launch.sh          # auto-selects cool-retro-term if installed
./meshtty-crt.sh     # explicit cool-retro-term launcher
```

The CRT effects (bloom, scanlines, curvature) are rendered entirely by
cool-retro-term.  MeshTTY's Textual themes provide the phosphor color
palette so the UI colours match the CRT profile.

---

## 4. Running MeshTTY

`launch.sh` is the recommended entry point.  It auto-detects cool-retro-term
and uses it if installed, otherwise falls back to a plain terminal.

```bash
./launch.sh                # auto-detect
./launch.sh --plain        # force plain terminal
./launch.sh --crt          # force cool-retro-term (errors if not installed)
./launch.sh --bot --log    # pass flags through to MeshTTY
```

You can also run the launchers directly:

```bash
./meshtty.sh               # plain terminal (generated by install.sh)
./meshtty-crt.sh           # cool-retro-term
python -m meshtty.main     # direct, using active virtualenv
```

The app starts on the **Connection Screen**.  Once connected it switches
automatically to the **Main Screen**.

---

## 5. Command-Line Flags

```
./launch.sh [--plain|--crt] [meshtty flags]
```

`--plain` and `--crt` are consumed by `launch.sh`.  All other flags are
passed through to MeshTTY:

| Flag       | Description                                                  |
|------------|--------------------------------------------------------------|
| `--debug`  | Enable DEBUG-level logging to `/tmp/meshtty.log`.            |
| `--bot`    | Enable the DM slash-command bot (see section 7.6).           |
| `--log`    | Log all inbound and outbound messages to `/tmp/meshtty-messages.log`. |
| `--noargs` | Clear saved startup flags and launch with no flags active.   |
| `-h`       | Print help and exit.                                         |

Flags are persisted across reboots.  The last set of flags used is saved to
`~/.config/meshtty/last_flags` and replayed automatically on the next launch
(unless new flags are passed explicitly, or `--noargs` is used to clear them).

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
starts a 5-second countdown and connects automatically.  The status line
shows "Connecting in Ns… (press any key to cancel)".  Press any key, switch
tabs, or click a button to cancel and configure manually.

### Status messages

- A status line shows progress: "Connecting…", "Connected — downloading
  nodes: …", "Download complete (N nodes) — waiting for radio confirmation…",
  "Connected! (N nodes loaded)".
- A red error line shows the failure reason if a connection attempt fails.

> **Note:** On busy networks (many nodes), the app transitions to the Main
> Screen as soon as the initial radio handshake completes.  Remaining node
> records continue to arrive in the background.

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

Messages are displayed in a fixed-80-column terminal style:

```
HH:MM prefix: message text
```

- **Incoming broadcasts** — displayed flush with the left margin, labelled
  with the channel name (e.g. `Primary`, `LongFast`).
- **Incoming direct messages** — labelled with the sender's short name.
- **Outgoing messages** — indented by two spaces, displayed in a brighter
  accent color.
- Lines longer than 80 characters wrap aligned under the message text.

#### Compose bar

The input field is pre-filled with the last active prefix (e.g. `Primary: `).
You can type and send as-is, or edit the prefix to target a different channel
or a specific node's short name.  Format:

```
prefix: your message text
```

- If the prefix matches a configured channel name → sent as a broadcast on
  that channel.
- If the prefix matches a node short name → sent as a direct message to that
  node.
- Press **Enter** or click **SEND** to transmit.

#### Scrolling

- **Up / Down arrows** scroll the message history one line at a time.
- **PageUp / PageDown** scroll a full screen at a time.
- Scrolling works regardless of whether focus is on the message area or the
  compose input.

#### History

The 200 most recent messages (across all channels and DMs) are loaded from
the local database on startup.

---

### 7.2 Channels Tab

Lists all channels configured on the connected radio.

- Click a channel name to set it as the compose prefix in the Messages tab.
  The app switches back to Messages automatically.
- The list is refreshed each time the tab is shown.

---

### 7.3 Nodes Tab

A live table of all mesh nodes known to the radio.  Updates in real time as
position, telemetry, and node-info packets are received.

| Column     | Description                                      |
|------------|--------------------------------------------------|
| Short      | Node short name (4-character callsign).          |
| Long Name  | Node long name.                                  |
| SNR        | Last received signal-to-noise ratio (dB).        |
| Last Heard | Time of the last packet heard (HH:MM:SS, local). |
| Battery    | Reported battery level (%).                      |
| Position   | GPS coordinates (lat, lon) to 4 decimal places.  |
| HW Model   | Hardware model string.                           |

Press **Ctrl+R** to force a refresh from the radio.

Click any row to open the **Node Detail Modal**.

---

### 7.4 Node Detail Modal

Overlay shown when you click a node row.  Displays:

- Node ID, short name, long name, hardware model
- Last SNR, last heard timestamp
- Battery level
- Latitude, longitude, altitude

Fields show `—` when no value has been received.  Close with **CLOSE**,
**Escape**, or **Q**.

---

### 7.5 Settings Tab

#### Connection section

Shows the current connection state and provides a **DISCONNECT** button that
returns to the Connection Screen.

#### Transport section

| Field                  | Description                                                   |
|------------------------|---------------------------------------------------------------|
| Default transport      | Tab pre-selected on the Connection Screen.                    |
| Serial port            | Last-used serial device path.                                 |
| TCP hostname           | Last-used TCP hostname or IP.                                 |
| TCP port               | Last-used TCP port (default 4403).                            |
| BLE address            | Last-used BLE MAC address.                                    |
| Auto-connect on launch | Saved but not yet active in the connection flow.              |

#### Display section

| Field                  | Description                                                   |
|------------------------|---------------------------------------------------------------|
| Show short node names  | Use 4-character short names in the Nodes table.               |
| Theme                  | UI colour theme — applied immediately on Save.                |

#### Messaging section

| Field           | Description                                              |
|-----------------|----------------------------------------------------------|
| Default channel | Channel index shown in Settings reference (0–7).         |

Click **SAVE** to apply.  The **Theme** setting takes effect immediately;
other settings apply on the next connection.

---

### 7.6 DM Slash Commands

The slash-command bot is **disabled by default**.  Start MeshTTY with the
`--bot` flag to enable it:

```
./launch.sh --bot
```

When enabled, any incoming **direct message** whose text begins with `/` is
checked against the command list.

- Valid commands are displayed in the message history and an automatic reply
  is sent back to the sender.
- Unrecognised `/` commands are silently dropped.
- When `--bot` is not set, DMs starting with `/` are displayed as normal
  messages and no automatic reply is sent.

#### Available commands

| Command    | Response                                                          |
|------------|-------------------------------------------------------------------|
| `/HELP`    | Lists all available commands.                                     |
| `/INFO`    | Returns the URL of the MeshTTY git repository.                    |
| `/JOKE`    | Returns the next joke from the joke file (sequential, wraps).     |
| `/GPIO`    | Returns the state of exported GPIO pins read via sysfs.           |
| `/WEATHER` | Placeholder (feature not implemented).                            |
| `/NEWS`    | Placeholder.                                                      |
| `/NULL`    | Returns "All is nothingness".                                     |

Commands are case-insensitive.

#### Joke file setup

`/JOKE` reads from a CSV file that is **not included in the repository**.
Place the file at `meshtty/data/shortjokes.csv`.  The file must have a `Joke`
column header on the first row.  A compatible file is available from
[Kaggle — Short Jokes dataset](https://www.kaggle.com/datasets/abhinavmoudgil95/short-jokes).

If the file is absent, `/JOKE` responds with: *No joke for you.  It's a dull day.*

The joke counter is saved to `~/.config/meshtty/joke_index` after each
`/JOKE` command and restored on the next run.

---

## 8. Keyboard Shortcuts

### Connection Screen

| Key    | Action |
|--------|--------|
| Ctrl+Q | Quit   |

### Main Screen

| Key       | Action                                        |
|-----------|-----------------------------------------------|
| F1        | Help — show keyboard shortcut reference       |
| Ctrl+T    | Switch to MESSAGES tab                        |
| Ctrl+L    | Switch to CHANNELS tab                        |
| Ctrl+N    | Switch to NODES tab                           |
| Ctrl+S    | Switch to SETTINGS tab                        |
| ↑ / ↓    | Scroll message history up / down one line     |
| PgUp/PgDn | Scroll message history up / down one screen   |
| Ctrl+R    | Refresh node table from radio                 |
| Ctrl+D    | Disconnect and return to Connection Screen    |
| Ctrl+Q    | Quit                                          |

### Node Detail Modal

| Key    | Action      |
|--------|-------------|
| Escape | Close modal |
| Q      | Close modal |

---

## 9. Configuration File

**Location:** `~/.config/meshtty/config.json`

Created automatically on first run.  Edit with any text editor while MeshTTY
is not running.

```json
{
  "default_transport": "serial",
  "last_serial_port": "/dev/ttyUSB0",
  "last_tcp_host": "",
  "last_tcp_port": 4403,
  "last_ble_address": "",
  "auto_connect": true,
  "log_level": "WARNING",
  "db_path": "/home/<user>/.config/meshtty/messages.db",
  "default_channel": 0,
  "node_short_name_display": true,
  "theme": "crt-amber"
}
```

| Key                       | Type    | Default                         | Description                         |
|---------------------------|---------|---------------------------------|-------------------------------------|
| `default_transport`       | string  | `"serial"`                      | `"serial"`, `"tcp"`, or `"ble"`.   |
| `last_serial_port`        | string  | `""`                            | Serial device path.                 |
| `last_tcp_host`           | string  | `""`                            | TCP hostname or IP.                 |
| `last_tcp_port`           | integer | `4403`                          | TCP port number.                    |
| `last_ble_address`        | string  | `""`                            | BLE MAC address.                    |
| `auto_connect`            | boolean | `true`                          | Start auto-connect countdown if a device is remembered. |
| `log_level`               | string  | `"WARNING"`                     | `"DEBUG"`, `"INFO"`, `"WARNING"`, or `"ERROR"`. |
| `db_path`                 | string  | `~/.config/meshtty/messages.db` | Path to the SQLite database.        |
| `default_channel`         | integer | `0`                             | Messaging default channel (0–7).   |
| `node_short_name_display` | boolean | `true`                          | Use short names in the Nodes table. |
| `theme`                   | string  | `"crt-amber"`                   | UI theme (see section 11).          |

---

## 10. Message & Node Database

**Location:** `~/.config/meshtty/messages.db`

SQLite database created automatically.  Query with any SQLite tool.

### `messages` table

| Column           | Type    | Description                                        |
|------------------|---------|----------------------------------------------------|
| `id`             | INTEGER | Auto-increment primary key.                        |
| `packet_id`      | TEXT    | Meshtastic packet ID (NULL for sent messages).     |
| `from_id`        | TEXT    | Sender node ID string (e.g. `!abcd1234`).          |
| `to_id`          | TEXT    | Recipient node ID or `^all` for broadcast.         |
| `channel`        | INTEGER | Channel index (0–7).                               |
| `text`           | TEXT    | Message text.                                      |
| `rx_time`        | INTEGER | Unix timestamp (seconds).                          |
| `is_mine`        | INTEGER | `1` if sent by this device, `0` if received.       |
| `display_prefix` | TEXT    | Human-readable prefix stored at send/receive time. |

The history view loads the 200 most recent messages on startup.

### `nodes` table

| Column       | Type    | Description                                   |
|--------------|---------|-----------------------------------------------|
| `node_id`    | TEXT    | Primary key.  Node ID string.                 |
| `short_name` | TEXT    | 4-character callsign.                         |
| `long_name`  | TEXT    | Full node name.                               |
| `hw_model`   | TEXT    | Hardware model string.                        |
| `last_snr`   | REAL    | Last signal-to-noise ratio (dB).              |
| `last_lat`   | REAL    | Last latitude.                                |
| `last_lon`   | REAL    | Last longitude.                               |
| `last_alt`   | INTEGER | Last altitude (metres).                       |
| `battery`    | INTEGER | Battery level (%).                            |
| `last_heard` | INTEGER | Unix timestamp of last received packet.       |
| `updated_at` | INTEGER | Unix timestamp of last database write.        |

Useful queries:

```sql
-- All messages, newest first
SELECT datetime(rx_time,'unixepoch','localtime') AS time,
       display_prefix, text
FROM messages ORDER BY rx_time DESC LIMIT 50;

-- All known nodes
SELECT node_id, short_name, long_name, battery, last_snr FROM nodes;
```

---

## 11. Themes

Three built-in themes, selectable from SETTINGS → Theme.  Applied immediately
on Save; persisted in `config.json`.

Each theme is drawn from a cool-retro-term color profile.  For the full CRT
effect, pair the Textual theme with the matching cool-retro-term profile
(see section 3).

| Config value   | Label          | cool-retro-term profile | Appearance                              |
|----------------|----------------|-------------------------|-----------------------------------------|
| `crt-amber`    | Amber          | Default Amber           | Warm `#ff8100` amber on black. **Default.** |
| `crt-phosphor` | Green Phosphor | Monochrome Green        | Classic `#0ccc68` green on black.       |
| `crt-ibm`      | IBM VGA        | IBM VGA 8×16            | Cool `#c0c0c0` grey on black.           |

---

## 12. Debug Logging

```
./launch.sh --debug
tail -f /tmp/meshtty.log
```

In normal operation the log level is controlled by `log_level` in config
(default `"WARNING"`).  Only warnings and errors are written to the log file.

### Common errors in the log

| Error                                                           | Likely cause                                      |
|-----------------------------------------------------------------|---------------------------------------------------|
| `PermissionError: [Errno 13] ... '/dev/ttyUSB0'`               | User not in the `dialout` group — see section 13. |
| `serial.serialutil.SerialException: could not open port`       | Port path wrong or device not plugged in.         |
| `ConnectionRefusedError`                                        | TCP host/port wrong or node unreachable.          |
| `_waitConnected timed out but N nodes present`                 | Noisy serial stream; transport forces connection and proceeds. |
| `waitForConfig timed out but myInfo and N nodes present`       | Radio config incomplete; channels/localConfig may be missing. |

---

## 13. Serial Port Permissions

### Linux (Raspberry Pi OS and Ubuntu)

```
sudo usermod -aG dialout $USER
```

Log out and back in.  Verify with `groups` — output should include `dialout`.

`install.sh` handles this automatically.

### macOS

No group membership is required.  Serial devices appear as
`/dev/cu.usbserial-XXXX`, `/dev/cu.SLAB_USBtoUART`, or similar.
Run `ls /dev/cu.*` with the radio plugged in to find the correct path.

---

## 14. Known Issues & Missing Features

This is a pre-alpha release.  The following are known to be broken or absent:

### Confirmed bugs

- **`display_prefix` missing from old database rows** — Messages stored before
  this version have an empty `display_prefix` column; they fall back to
  displaying the raw `from_id` node string.

### Not yet implemented

- **Channel switching confirmation** — Clicking a channel in the Channels tab
  switches the compose prefix but does not visually confirm which channel is
  active.
- **Message acknowledgement display** — No indication of whether the radio
  acknowledged delivery.
- **Persistent compose prefix** — The compose bar prefix resets to the first
  channel on each session start and on each received message.
- **BLE transport** — Largely untested.
- **Node position on map** — No map view.
- **Channel creation / management** — Read-only channel display only.
- **Firmware version / radio config display** — Not shown anywhere.
- **Notification / alert on new message** — No alert when a new message
  arrives on a non-active tab.

---

## 15. Troubleshooting

### Slow connection or hangs during node download

The app transitions to the Main Screen as soon as the initial radio handshake
completes.  On very busy networks the meshtastic library may still time out
waiting for the full radio config.  Run with `--debug` and watch the log.  If
you see:

```
_waitConnected timed out but N nodes present — forcing connected state
```

or

```
waitForConfig timed out but myInfo and N nodes present — proceeding without full config
```

the transport forced a connection after a timeout.  This is usually harmless —
node records continue arriving after the transition.  If the app is completely
stuck, quit (Ctrl+Q) and reconnect.

### Serial device detected but connection fails

1. Run with `--debug` and check `/tmp/meshtty.log`.
2. Confirm permissions (section 13).
3. Try unplugging and re-plugging the USB cable.
4. Test with the meshtastic CLI: `meshtastic --port /dev/ttyUSB0 --info`

### No serial devices in the auto-scan list

The scanner filters by USB vendor ID.  Supported chips:

| Chip                | USB VID |
|---------------------|---------|
| Silicon Labs CP210x | 10C4    |
| WCH CH340 / CH341   | 1A86    |
| FTDI                | 0403    |
| Espressif USB-JTAG  | 303A    |

If your adapter uses a different chip, enter the port path manually.

### BLE scan finds no devices

- Ensure the node has BLE enabled in its firmware settings.
- Ensure the host has a working Bluetooth adapter (`hciconfig` on Linux).

### Config file ignored or reset

Verify it is valid JSON:

```
python3 -m json.tool ~/.config/meshtty/config.json
```

If `"theme"` contains an unrecognised value, the app silently resets it to
`crt-amber`.

### cool-retro-term not found when running meshtty-crt.sh

Install cool-retro-term (see section 3), or use `./launch.sh --plain` to run
in a plain terminal.

---

## 16. Headless / Kiosk Operation (Raspberry Pi)

MeshTTY is designed to run as a full-screen kiosk app on a headless Pi
connected to a physical display — no desktop environment required.

### Setup

1. Configure the Pi for **console auto-login** (e.g. `raspi-config` →
   System Options → Boot / Auto Login → Console Autologin).
2. Run `install.sh` on the Pi and answer **Y** when asked about auto-launch.

The installer adds a block to `~/.bash_profile` that:

- Activates only on `tty1` (the physical console) — SSH sessions are
  unaffected.
- Sets `TERM=xterm-256color` for full colour rendering.
- Runs MeshTTY in a restart loop so it comes back after an exit or crash.

```bash
# MeshTTY auto-launch on tty1 (physical Pi screen)
if [[ "$(tty)" == "/dev/tty1" ]]; then
    export TERM=xterm-256color
    while true; do
        /home/pi/Vibe/MeshTTY/meshtty.sh
        sleep 2
    done
fi
```

### What happens at boot

| Step | What MeshTTY does |
|------|-------------------|
| Login shell starts | `~/.bash_profile` runs the restart loop |
| `meshtty.sh` starts | Checks stdin/stdout are a TTY; exits with an error if not |
| Serial transport configured | Waits up to 10 s for the USB device to enumerate |
| App launches | Connection screen appears |
| Saved device present | 5-second countdown begins; connects automatically |
| App exits for any reason | `sleep 2`, then `meshtty.sh` restarts |

### Troubleshooting a headless Pi

SSH in from another machine to investigate without disturbing the console:

```
ssh pi@<pi-hostname>
tail -f /tmp/meshtty.log
```

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Black screen / app not starting | User not in `dialout` group | Re-run `install.sh` or `sudo usermod -aG dialout pi` then reboot |
| "Waiting for USB serial device…" then fails | Radio not plugged in or wrong port | Plug in radio before booting; check `dmesg \| grep tty` |
| App starts but auto-connect does not fire | No saved device in config | Connect once manually with **Remember this device** checked |
| App crashes immediately | `TERM` not set or `dumb` | Ensure `~/.bash_profile` sets `TERM=xterm-256color` |
