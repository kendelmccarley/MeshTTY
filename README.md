# MeshTTY — User Manual

MeshTTY is a terminal-based (TUI) client for Meshtastic LoRa mesh radio networks,
designed to run on a Raspberry Pi or any Linux system with a terminal.  It is built
with the Textual framework and communicates with a Meshtastic node over USB/serial,
TCP/WiFi, or Bluetooth (BLE).

---

## Table of Contents

1. [Installation](#1-installation)
2. [Running MeshTTY](#2-running-meshtty)
3. [Command-Line Flags](#3-command-line-flags)
4. [Connection Screen](#4-connection-screen)
5. [Main Screen](#5-main-screen)
   - 5.1 [Status Bar](#51-status-bar)
   - 5.2 [Messages Tab](#52-messages-tab)
   - 5.3 [Nodes Tab](#53-nodes-tab)
   - 5.4 [Node Detail Modal](#54-node-detail-modal)
   - 5.5 [Settings Tab](#55-settings-tab)
6. [Keyboard Shortcuts](#6-keyboard-shortcuts)
7. [Configuration File](#7-configuration-file)
8. [Message & Node Database](#8-message--node-database)
9. [Themes](#9-themes)
10. [Debug Logging](#10-debug-logging)
11. [Serial Port Permissions (Linux)](#11-serial-port-permissions-linux)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Installation

```
pip install -e .
```

Run this from the repository root (the directory containing `pyproject.toml`).
This installs the `meshtty` command and all Python dependencies.

**Dependencies installed automatically:**

| Package       | Purpose                                        |
|---------------|------------------------------------------------|
| textual       | TUI framework (rendering, widgets, key bindings)|
| meshtastic    | Meshtastic Python library (serial/TCP/BLE)     |
| bleak         | Bluetooth BLE scanning                         |
| pyserial      | Serial port enumeration and communication      |
| pypubsub      | Event pub/sub (used internally by meshtastic)  |
| protobuf      | Meshtastic protocol buffer serialization       |
| anyio         | Async I/O support                              |

Python 3.11 or newer is required.

---

## 2. Running MeshTTY

After installation, either of the following will launch the app:

```
meshtty
```

```
python -m meshtty.main
```

The application starts on the **Connection Screen**.  Once connected to a node it
switches automatically to the **Main Screen**.

---

## 3. Command-Line Flags

```
meshtty [--debug] [-h]
```

| Flag      | Description                                                        |
|-----------|--------------------------------------------------------------------|
| `--debug` | Enable DEBUG-level logging for all loggers (see section 10).       |
| `-h`      | Print help and exit.                                               |

Example — run with debug logging and watch the log in another terminal:

```
meshtty --debug
tail -f /tmp/meshtty.log
```

---

## 4. Connection Screen

This is the first screen shown on launch.  It lets you choose how to connect to
your Meshtastic radio node.

### Tabs

Three transport tabs are available.  The tab that was active when you last saved
settings is pre-selected.

#### Serial / USB

- The app scans for serial ports whose USB vendor ID matches common Meshtastic
  chips (Silicon Labs CP210x, WCH CH340/CH341, FTDI, Espressif USB-JTAG) and
  lists them automatically in a table.
- Click a row in the table to copy that port path into the input field, or type
  the path manually (e.g. `/dev/ttyUSB0`, `/dev/ttyACM0`).
- Click **Connect** to open the serial connection.

#### TCP / WiFi

- Enter the hostname or IP address of the node and the port number (default 4403).
- Click **Connect**.

#### Bluetooth (BLE)

- Click **Scan for BLE Devices** to perform a 5-second BLE scan.  Devices are
  identified by name ("meshtastic") or by the Meshtastic BLE service UUID.
- Click a row in the table to copy the address into the input field, or type a
  MAC address manually (e.g. `AA:BB:CC:DD:EE:FF`).
- Click **Connect**.

### Remember this device

The **Remember this device** switch (on by default) saves the connection details
to the config file so the same transport and address are pre-filled on the next
launch.

### Status and errors

- A status line shows progress ("Connecting…", "Found N serial device(s).", etc.).
- A red error line shows the failure reason if a connection attempt fails.

### Keyboard shortcuts (Connection Screen)

| Key    | Action |
|--------|--------|
| Ctrl+Q | Quit   |

---

## 5. Main Screen

After a successful connection the app switches to the Main Screen.  This screen
has a **status bar** at the top, three **tabs** in the middle, and a **footer**
at the bottom showing available key bindings.

### 5.1 Status Bar

The status bar is always visible across all tabs.  It shows:

| Field       | Description                                                     |
|-------------|-----------------------------------------------------------------|
| ● Connected | Green indicator and transport description (e.g. "Serial (/dev/ttyUSB0)"). |
| Ch: —       | Channel name (updated when channel info is received).           |
| Nodes: N    | Count of mesh nodes known to the radio.                         |
| Bat: N%     | Battery level of the local (your) node, if reported.            |
| Disconnect  | Button — disconnects and returns to the Connection Screen.      |

### 5.2 Messages Tab

Press **1** or click the "Messages" tab.

The Messages tab is divided into two panels:

#### Channel Sidebar (left, 18 columns wide)

Lists channels **Ch 0** through **Ch 7**.  Click a channel to switch to it.
The channel you were on when you last disconnected is not saved between sessions;
Ch 0 (or the channel set in Settings → Default channel) is shown on mount.

#### Message History (right)

Shows the last 200 messages for the selected channel, loaded from the local
database on startup.  New messages received over the radio appear in real time.
Sent messages appear immediately without waiting for acknowledgement.

Messages are displayed as:

```
[HH:MM:SS] <node-id>: message text
```

Your own messages are visually distinguished from received messages.

#### Compose Bar (bottom of right panel)

Type a message in the text input and press **Enter** or click **Send** to
broadcast it on the currently selected channel.  The input is cleared after
sending and focus returns to it automatically.

### 5.3 Nodes Tab

Press **2** or click the "Nodes" tab.

Displays a table of all mesh nodes known to the radio.  The table updates in
real time as node updates, position packets, and telemetry packets are received.

| Column     | Description                                      |
|------------|--------------------------------------------------|
| Short      | Node short name (4-character callsign).          |
| Long Name  | Node long name.                                  |
| SNR        | Last received signal-to-noise ratio in dB.       |
| Last Heard | Time of the last packet heard (HH:MM:SS, local). |
| Battery    | Reported battery level (%).                      |
| Position   | GPS coordinates (lat, lon) to 4 decimal places.  |
| HW Model   | Hardware model string reported by the node.      |

Press **Ctrl+R** to force a refresh of the node table from the radio.

Click any row to open the **Node Detail Modal** for that node.

### 5.4 Node Detail Modal

Opens as an overlay when you click a node row.  Shows all available information
for that node:

**Identity**
- Node ID (hex string, e.g. `!abcd1234`)
- Short name
- Long name
- Hardware model

**Signal**
- Last SNR (dB)
- Last heard timestamp (YYYY-MM-DD HH:MM:SS, local time)

**Power**
- Battery level (%)

**Position**
- Latitude, longitude, altitude

Fields show `—` when the value has not been received.

Close the modal with the **Close** button, the **Escape** key, or **Q**.

### 5.5 Settings Tab

Press **3** or click the "Settings" tab.

Change any setting and click **Save** to apply.  A "Settings saved." confirmation
appears below the button.  Most settings take effect on the next connection; the
**Theme** setting takes effect immediately without restarting.

#### Transport section

| Field                | Description                                                   |
|----------------------|---------------------------------------------------------------|
| Default transport    | Which tab is pre-selected on the Connection Screen (Serial / TCP / BLE). |
| Serial port          | Last-used serial device path, pre-filled on the Connection Screen. |
| TCP hostname         | Last-used TCP hostname or IP.                                 |
| TCP port             | Last-used TCP port (default 4403).                            |
| BLE address          | Last-used BLE MAC address.                                    |
| Auto-connect on launch | Not yet implemented in the connection flow; saved but unused. |

#### Display section

| Field               | Description                                                    |
|---------------------|----------------------------------------------------------------|
| Show short node names | When enabled, the Nodes table uses the 4-character short name as the primary identifier. |
| Theme               | UI color theme.  Applied immediately on Save (see section 9). |

#### Messaging section

| Field           | Description                                                        |
|-----------------|--------------------------------------------------------------------|
| Default channel | Channel index (0–7) shown when the Messages tab first opens.       |

---

## 6. Keyboard Shortcuts

### Connection Screen

| Key    | Action |
|--------|--------|
| Ctrl+Q | Quit   |

### Main Screen

| Key    | Action                              |
|--------|-------------------------------------|
| 1      | Switch to Messages tab              |
| 2      | Switch to Nodes tab                 |
| 3      | Switch to Settings tab              |
| Ctrl+R | Refresh node table from radio       |
| Ctrl+D | Disconnect and return to Connection Screen |
| Ctrl+Q | Quit                                |

### Node Detail Modal

| Key    | Action      |
|--------|-------------|
| Escape | Close modal |
| Q      | Close modal |

---

## 7. Configuration File

**Location:** `~/.config/meshtty/config.json`

The file is created automatically on first run.  You can edit it with any text
editor while MeshTTY is not running.  The app reads it on startup; changes made
while the app is running have no effect until the next launch (except for theme,
which can be changed from the Settings tab at runtime).

### Full example

```json
{
  "default_transport": "serial",
  "last_serial_port": "/dev/ttyUSB0",
  "last_tcp_host": "192.168.1.100",
  "last_tcp_port": 4403,
  "last_ble_address": "",
  "auto_connect": true,
  "log_level": "WARNING",
  "db_path": "/home/<user>/.config/meshtty/messages.db",
  "default_channel": 0,
  "node_short_name_display": true,
  "theme": "meshtty-multicolor"
}
```

### Field reference

| Key                    | Type    | Default                       | Description                         |
|------------------------|---------|-------------------------------|-------------------------------------|
| `default_transport`    | string  | `"serial"`                    | `"serial"`, `"tcp"`, or `"ble"`.   |
| `last_serial_port`     | string  | `""`                          | Serial device path.                 |
| `last_tcp_host`        | string  | `""`                          | TCP hostname or IP.                 |
| `last_tcp_port`        | integer | `4403`                        | TCP port number.                    |
| `last_ble_address`     | string  | `""`                          | BLE MAC address.                    |
| `auto_connect`         | boolean | `true`                        | Saved by the Settings screen; not yet active in the connection flow. |
| `log_level`            | string  | `"WARNING"`                   | Python logging level for normal operation: `"DEBUG"`, `"INFO"`, `"WARNING"`, `"ERROR"`. Overridden to `"DEBUG"` when `--debug` is passed on the command line. |
| `db_path`              | string  | `~/.config/meshtty/messages.db` | Path to the SQLite message database. |
| `default_channel`      | integer | `0`                           | Channel shown on Messages tab mount (0–7). |
| `node_short_name_display` | boolean | `true`                     | Use short names in the Nodes table. |
| `theme`                | string  | `"meshtty-multicolor"`        | UI theme name (see section 9).      |

---

## 8. Message & Node Database

**Location:** `~/.config/meshtty/messages.db` (configurable via `db_path`)

MeshTTY stores messages and node data in a local SQLite database.  The file is
created automatically.  You can query it with any SQLite tool
(e.g. `sqlite3 ~/.config/meshtty/messages.db`).

### `messages` table

| Column     | Type    | Description                                        |
|------------|---------|----------------------------------------------------|
| `id`       | INTEGER | Auto-increment primary key.                        |
| `packet_id`| TEXT    | Meshtastic packet ID (may be NULL for sent messages). |
| `from_id`  | TEXT    | Sender node ID string (e.g. `!abcd1234`).          |
| `to_id`    | TEXT    | Recipient node ID or `^all` for broadcast.         |
| `channel`  | INTEGER | Channel index (0–7).                               |
| `text`     | TEXT    | Message text.                                      |
| `rx_time`  | INTEGER | Unix timestamp (seconds).                          |
| `is_mine`  | INTEGER | `1` if sent by this device, `0` if received.       |

The Messages tab loads the 200 most recent messages per channel from this table
on startup and whenever you switch channels.

### `nodes` table

| Column      | Type    | Description                                   |
|-------------|---------|-----------------------------------------------|
| `node_id`   | TEXT    | Primary key.  Node ID string.                 |
| `short_name`| TEXT    | 4-character callsign.                         |
| `long_name` | TEXT    | Full node name.                               |
| `hw_model`  | TEXT    | Hardware model string.                        |
| `last_snr`  | REAL    | Last signal-to-noise ratio (dB).              |
| `last_lat`  | REAL    | Last latitude.                                |
| `last_lon`  | REAL    | Last longitude.                               |
| `last_alt`  | INTEGER | Last altitude (metres).                       |
| `battery`   | INTEGER | Battery level (%).                            |
| `last_heard`| INTEGER | Unix timestamp of last received packet.       |
| `updated_at`| INTEGER | Unix timestamp of last database write.        |

Useful queries:

```sql
-- All messages on channel 0, newest first
SELECT datetime(rx_time, 'unixepoch', 'localtime') AS time, from_id, text
FROM messages WHERE channel = 0 ORDER BY rx_time DESC LIMIT 50;

-- All known nodes
SELECT node_id, short_name, long_name, battery, last_snr FROM nodes;
```

---

## 9. Themes

MeshTTY ships with three built-in themes selectable from the Settings tab.
The theme is applied instantly when you click Save — no restart required.
The selected theme is saved to the config file and restored on the next launch.

| Config value           | Settings label  | Appearance                                        |
|------------------------|-----------------|---------------------------------------------------|
| `meshtty-multicolor`   | Multicolor      | Dark navy/purple background, blue/purple/pink accents. Default. |
| `meshtty-phosphor`     | Green Phosphor  | Black background, classic green-on-black CRT look. |
| `meshtty-bw`           | Black & White   | Pure black background, white/grey monochrome.     |

To set a theme without launching the app, edit `~/.config/meshtty/config.json`
and set the `"theme"` key to one of the three config values above.  If an
unrecognised value is found on startup the app silently falls back to
`meshtty-multicolor`.

---

## 10. Debug Logging

Pass `--debug` on the command line to enable DEBUG-level logging:

```
meshtty --debug
```

All log output (from MeshTTY and from the `meshtastic` Python library) is written
to:

```
/tmp/meshtty.log
```

Watch it in real time from a second terminal:

```
tail -f /tmp/meshtty.log
```

In normal operation (without `--debug`) the log level is controlled by the
`log_level` field in the config file and defaults to `WARNING`.  Only warnings
and errors are written to the log file.

### What is logged at DEBUG level

- Every connection attempt, including the transport type and address/port
- Full Python exception tracebacks when a connection fails (previously only the
  error message string was shown in the UI)
- Internal meshtastic library events: serial framing, protocol handshake, node
  sync, packet receipt
- EventBridge subscription and unsubscription
- Theme activation on startup

### Interpreting common errors

| Error in log                                          | Likely cause                                        |
|-------------------------------------------------------|-----------------------------------------------------|
| `PermissionError: [Errno 13] Permission denied: '/dev/ttyUSB0'` | User not in the `dialout` group — see section 11. |
| `serial.serialutil.SerialException: could not open port` | Port path wrong, device not plugged in, or driver not loaded. |
| `ConnectionRefusedError`                              | TCP host/port wrong or node not reachable.          |
| `meshtastic.mesh_interface: Timeout waiting for ...`  | Node is powered on and connected but not responding to handshake — try unplugging and reconnecting the USB cable. |

---

## 11. Serial Port Permissions (Linux)

On Linux, serial ports (`/dev/ttyUSB*`, `/dev/ttyACM*`) are owned by the
`dialout` group.  If you see a `PermissionError` in the log when connecting via
USB, add your user to the group:

```
sudo usermod -aG dialout $USER
```

Log out and back in (or reboot) for the change to take effect.  Verify with:

```
groups
```

The output should include `dialout`.

---

## 12. Troubleshooting

### Serial device is detected but connection fails

1. Run with `--debug` and check `/tmp/meshtty.log` for the full traceback.
2. Confirm permissions (section 11).
3. Try unplugging and re-plugging the USB cable — the node may need a reset.
4. Confirm the device path:  `ls -l /dev/ttyUSB* /dev/ttyACM*`
5. Test with the meshtastic CLI directly to rule out a hardware or firmware issue:
   `meshtastic --port /dev/ttyUSB0 --info`

### No serial devices appear in the auto-scan list

The scanner filters by USB vendor ID.  Supported chips:

| Chip              | USB VID |
|-------------------|---------|
| Silicon Labs CP210x | 10C4  |
| WCH CH340 / CH341 | 1A86    |
| FTDI              | 0403    |
| Espressif USB-JTAG | 303A   |

If your adapter uses a different chip, enter the port path manually.

### BLE scan finds no devices

- Ensure the Meshtastic node has BLE enabled in its firmware settings.
- Ensure the host system has a working Bluetooth adapter (`hciconfig`).
- Try increasing the scan timeout by connecting manually via the address input.

### Config file is ignored or reset

The app silently falls back to defaults if `config.json` contains invalid JSON
or an unexpected value type.  Open the file in a text editor and verify it is
valid JSON (`python3 -m json.tool ~/.config/meshtty/config.json`).

### Old "dark" theme value in config

If you have `"theme": "dark"` or any unrecognised theme name in your config
(left over from an earlier version), the app automatically resets it to
`meshtty-multicolor` at startup without crashing.
