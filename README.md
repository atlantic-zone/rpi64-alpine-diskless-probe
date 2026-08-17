# 🌡️ RPi64 Alpine Diskless Temperature Probe (`rpi64-alpine-diskless-probe`)

[![Build & Release](https://github.com/atlantic-zone/rpi64-alpine-diskless-probe/actions/workflows/build-release.yml/badge.svg)](https://github.com/atlantic-zone/rpi64-alpine-diskless-probe/actions/workflows/build-release.yml)
[![Platform: RPi 3, 4 & 5](https://img.shields.io/badge/Platform-Raspberry%20Pi%203%20%7C%204%20%7C%205-red.svg)](https://www.raspberrypi.com/)
[![OS: Alpine Linux 64-bit](https://img.shields.io/badge/OS-Alpine%20Linux%2064--bit-blue.svg)](https://alpinelinux.org/)

Standalone **Alpine Linux Diskless (100% RAM / tmpfs)** system distribution for Raspberry Pi 3, 4, and 5 (`aarch64` / `rpi64`) with 1-Wire DS18B20 temperature sensor probe and direct metrics push to **VictoriaMetrics**.

---

## 🚀 Key Features

- **100% Run-from-RAM (Diskless):** The entire system operates in memory (`tmpfs`). Zero write operations occur on the SD card during runtime, completely eliminating SD card corruption risks caused by power outages.
- **Universal RPi 3, 4 & 5 Compatibility:** Built on Alpine Linux `aarch64` (64-bit), natively supporting Raspberry Pi 3B/3B+, Raspberry Pi 4B, and Raspberry Pi 5.
- **Simple FAT32 Configuration (`probe.conf`):** All parameters (`HOSTNAME`, `LOCATION`, `VICTORIAMETRICS_URL`, `TIMEZONE`, `KEYMAP`, `STATIC_IP`, `WIFI_SSID`) are configured via a plain text file on the FAT32 root partition of the SD card.
- **VictoriaMetrics HTTP Push Mode:** Direct metric ingestion (`/api/v1/import/prometheus`) via HTTP POST. Requires no inbound open ports on the Raspberry Pi.
- **Automatic SSH Provisioning:** Dynamic fetch and injection of authorized SSH public keys via URL (supports single or multiple URLs).
- **Wi-Fi & Ethernet Support:** Automatic fallback to Wi-Fi (`WIFI_SSID` / `WIFI_PASSWORD`) or Ethernet RJ45 connection (DHCP or Static IP).
- **Embedded Admin Utilities:** Includes `vim`, `tmux`, `curl`, `openssh`, `tzdata`, and `wpa_supplicant`.

---

## 🔌 Hardware Wiring Specifications & WireViz Diagram

Connect the **DS18B20 digital 1-Wire temperature sensor** to the Raspberry Pi 40-pin GPIO header:

| Wire Color | Signal Name | Description | RPi Header Connection |
| :--- | :--- | :--- | :--- |
| **RED** | `VCC` | Power (3.3V DC) | **Pin 1** (`3.3V Power`) |
| **BLACK** | `GND` | Ground | **Pin 6** or **Pin 9** (`GND`) |
| **YELLOW** | `DATA` | 1-Wire Data Line | **Pin 7** (`GPIO 4 / GPCLK0`) |

> ⚠️ **CRITICAL LOGIC LEVEL WARNING:** Never connect the Red (VCC) wire to 5V (Pin 2 or Pin 4). DS18B20 sensors and Raspberry Pi GPIO pins operate strictly on **3.3V logic levels**. Connecting 5V to GPIO 4 will destroy the GPIO port!

### Electronic Wiring Harness Diagram (Generated via WireViz / Kroki):

![DS18B20 Single Sensor Wiring Harness Diagram with 4.7kΩ Pull-Up Resistor (Kroki WireViz)](https://kroki.strat.zone/wireviz/png/eJyFkctqg0AUhvd5irOMMIaqoSnuYoS09CbmUoKITPQshkxnxAuhj9SX6TN1xtFQQ6DLf745_38uk1wKgXkjq9qfAMQRyx6RFlhpBdB8lejrV1hHT-9gUEdKJnLZisYHb9CcHpHXPiTezNvDNGICHIvA-i004l4LZTM3cmGlqjJqOd-VWYw1q1UX2Xy2OI2yewAa_HxfZbs3swmEy-1Su4cb5yFw77INilqOZuoJbPGzBIP_nWu_WsE0xsIyATA9IOfyPMwYcJqf1FCTnB45dvt8pUxkQVub5DOrcGSeS64XD0kcEji8EAie08vP8TojecaKgGN_KAQhbahKrZRZoQPNEZkUXZLdedh_rwmJQ8Aj4KY9u3TWEVfBgVztbMTt29VD6c1jDl9-AS-jrWA=)

```text
       Raspberry Pi Header (40-Pin)
       ---------------------------
       Pin 1 (3.3V) ───────┬────────────────────────────────────── Sensor RED (VCC)
                           │                               
                         [4.7kΩ] Resistor (Yellow-Violet-Red-Gold)
                           │                               
       Pin 7 (GPIO4)───────┼────────────────────────────────────── Sensor YELLOW (DATA)
                           │                               
       Pin 6 (GND)  ───────┴────────────────────────────────────── Sensor BLACK (GND)
```

> 💡 **Pull-Up Resistor Requirement:** A **4.7 kΩ pull-up resistor** (1/4W, color code: Yellow-Violet-Red-Gold) is required between the **RED (3.3V)** line and the **YELLOW (DATA)** line for 1-Wire signal integrity.

### External Hardware Documentation & Datasheets
* 📌 [Interactive Raspberry Pi Pinout Guide (Pinout.xyz 1-Wire)](https://pinout.xyz/pinout/1_wire)
* 📖 [Raspberry Pi Foundation Official Hardware & GPIO Documentation](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#gpio-and-the-40-pin-header)
* 📄 [DS18B20 Datasheet & Specification PDF (Analog Devices / Maxim)](https://datasheets.maximintegrated.com/en/ds/DS18B20.pdf)

---

## 🛠️ SD Card Flashing & Preparation Guide (Linux / macOS / Windows)

The deployment is performed on a standard **FAT32** SD card partition.

### 1. Format SD Card to FAT32

- **Windows:** Right-click the SD Card in File Explorer ➔ **Format** ➔ File System: **FAT32** (or use *Raspberry Pi Imager* with the Erase/FAT32 option).
- **macOS:** Open **Disk Utility** ➔ Select SD Card ➔ **Erase** ➔ Format: **MS-DOS (FAT)**.
- **Linux:**
  ```bash
  sudo mkfs.vfat -F 32 -n "RPI-PROBE" /dev/sdX1
  ```

---

### 2. Copy System Archive Files

1. Download the latest release `rpi64-alpine-diskless-probe-v*.tar.gz` from [GitHub Releases](https://github.com/atlantic-zone/rpi64-alpine-diskless-probe/releases).
2. Extract the entire archive to the root of the FAT32 partition.

#### Extraction Commands by OS:

- **Linux / macOS (Terminal):**
  ```bash
  tar -xzf rpi64-alpine-diskless-probe-v1.0.0.tar.gz -C /Volumes/RPI-PROBE/   # macOS
  sudo tar -xzf rpi64-alpine-diskless-probe-v1.0.0.tar.gz -C /media/user/RPI-PROBE/ # Linux
  ```
- **Windows:** Use 7-Zip or WinRAR to extract all files directly to the SD card drive letter (e.g. `E:\`).

---

### 3. Creating & Editing `probe.conf`

📁 **Where is `probe.conf` located?**  
`probe.conf` must be placed directly **at the root of the SD card** (FAT32 partition). 
When extracted, the archive includes a template file named `probe.conf.example` at the root.

1. Rename `probe.conf.example` to **`probe.conf`** on the root of the SD card.
2. Open `probe.conf` with any text editor (Notepad, VS Code, Nano, TextEdit).
3. Fill in your environment parameters:

```ini
# RPi64 Alpine Diskless Probe Configuration
# Place this file as 'probe.conf' at the root of your FAT32 SD card.

# ------------------------------------------------------------------------------
# 1. IDENTIFICATION & METRICS
# ------------------------------------------------------------------------------
HOSTNAME=celsius-fost-hq75-01
LOCATION=port-royal-b2
VICTORIAMETRICS_URL=http://10.200.140.109:8428/api/v1/import/prometheus
INTERVAL_SECONDS=10
GPIO_PIN=4

# ------------------------------------------------------------------------------
# 2. REGIONAL & KEYBOARD SETTINGS
# ------------------------------------------------------------------------------
TIMEZONE=Europe/Paris
KEYMAP=us-intl

# ------------------------------------------------------------------------------
# 3. SSH KEYS (Multi-URL supported, separated by spaces)
# ------------------------------------------------------------------------------
SSH_KEYS_URL="https://github.com/ts-sz.keys https://github.com/valeriustinca.keys"

# ------------------------------------------------------------------------------
# 4. NETWORK CONFIGURATION (Default: DHCP on eth0)
# ------------------------------------------------------------------------------
# Set STATIC_IP to override DHCP. Leave blank for DHCP.
STATIC_IP=
NET_MASK=255.255.255.0
NET_GATEWAY=10.98.10.1
DNS_SERVERS="1.1.1.1 8.8.8.8"

# Optional Wi-Fi settings (leave blank if using Ethernet)
WIFI_SSID=
WIFI_PASSWORD=
WIFI_COUNTRY=FR
```

---

## 📖 Complete `probe.conf` Variables Reference

| Section | Variable Name | Required | Default | Description / Value Format |
| :--- | :--- | :---: | :---: | :--- |
| **Metrics** | `HOSTNAME` | **Yes** | `rpi-probe` | Hostname of the Raspberry Pi. |
| | `LOCATION` | **Yes** | `unspecified` | Geographic / room location tag sent to VictoriaMetrics. |
| | `VICTORIAMETRICS_URL` | **Yes** | *None* | HTTP Prometheus import endpoint of your VictoriaMetrics server. |
| | `INTERVAL_SECONDS` | No | `10` | Frequency of metric collection and push (in seconds). |
| | `GPIO_PIN` | No | `4` | GPIO Pin used for 1-Wire Data Line. |
| **Regional** | `TIMEZONE` | No | `Europe/Paris` | System timezone (e.g. `Europe/Paris`, `UTC`, `Europe/Madrid`). |
| | `KEYMAP` | No | `us-intl` | Console keyboard layout (`us-intl`, `us`, `fr`, `es`). |
| **Access** | `SSH_KEYS_URL` | No | *None* | Space-separated list of URLs to fetch public SSH keys from. |
| **Network** | `STATIC_IP` | No | *DHCP* | Static IPv4 address (e.g. `10.98.10.150`). Leave blank for DHCP. |
| | `NET_MASK` | No | `255.255.255.0` | Subnet mask for static IP. |
| | `NET_GATEWAY` | No | `.1` of IP | Default gateway IP for static configuration. |
| | `DNS_SERVERS` | No | *System* | Space-separated list of DNS servers (e.g. `"1.1.1.1 8.8.8.8"`). |
| **Wi-Fi** | `WIFI_SSID` | No | *None* | Wi-Fi network SSID (leave blank if connected via RJ45). |
| | `WIFI_PASSWORD` | No | *None* | Wi-Fi WPA2 password. |
| | `WIFI_COUNTRY` | No | `FR` | Two-letter ISO country code for Wi-Fi regulatory domain. |

---

## 📊 Emitted Metrics (VictoriaMetrics / Prometheus)

Metrics pushed at every configured interval:

```text
# HELP temperature_celsius Ambient temperature in Celsius from DS18B20 sensor
# TYPE temperature_celsius gauge
temperature_celsius{hostname="celsius-fost-hq75-01",location="port-royal-b2",sensor="ds18b20"} 21.437
```

---

## 🔍 Verification & Diagnostics

Once the Raspberry Pi boots:

1. **Check status of the metric pusher service:**
   ```bash
   rc-service ds18b20-pusher status
   ```
2. **Inspect raw sensor output locally:**
   ```bash
   cat /sys/bus/w1/devices/28-*/w1_slave
   ```
3. **Verify the system is running 100% in RAM:**
   ```bash
   df -h /
   # Expected output: tmpfs on /
   ```

---

## 📜 Notice

Copyright (c) 2026 Atlantic Zone / Strategic Zone. All rights reserved.
