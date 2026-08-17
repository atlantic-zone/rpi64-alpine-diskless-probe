# 🌡️ RPi64 Alpine Diskless Temperature Probe (`rpi64-alpine-diskless-probe`)

[![Build & Release](https://github.com/atlantic-zone/rpi64-alpine-diskless-probe/actions/workflows/build-release.yml/badge.svg)](https://github.com/atlantic-zone/rpi64-alpine-diskless-probe/actions/workflows/build-release.yml)
[![Platform: RPi 3, 4 & 5](https://img.shields.io/badge/Platform-Raspberry%20Pi%203%20%7C%204%20%7C%205-red.svg)](https://www.raspberrypi.com/)
[![OS: Alpine Linux 64-bit](https://img.shields.io/badge/OS-Alpine%20Linux%2064--bit-blue.svg)](https://alpinelinux.org/)

Standalone **Alpine Linux Diskless (100% RAM / tmpfs)** system distribution for Raspberry Pi 3, Raspberry Pi 4, and Raspberry Pi 5 (`aarch64` / `rpi64`) with 1-Wire DS18B20 temperature sensor probe and direct metrics push to **VictoriaMetrics**.

---

## 🚀 Key Features

- **100% Run-from-RAM (Diskless):** The entire system operates in memory (`tmpfs`). Zero write operations occur on the SD card during runtime, completely eliminating SD card corruption risks caused by power outages.
- **Universal RPi 3, 4 & 5 Compatibility:** Built on Alpine Linux `aarch64` (64-bit), natively supporting Raspberry Pi 3B/3B+, Raspberry Pi 4B, and Raspberry Pi 5.
- **Simple FAT32 Configuration (`probe.conf`):** All parameters (`HOSTNAME`, `LOCATION`, `VICTORIAMETRICS_URL`, `GPIO_PIN`, `WIFI_SSID`, `WIFI_PASSWORD`) are configured via a plain text file on the FAT32 root partition of the SD card.
- **VictoriaMetrics HTTP Push Mode:** Direct metric ingestion (`/api/v1/import/prometheus`) via HTTP POST. Requires no inbound open ports on the Raspberry Pi.
- **Automatic SSH Provisioning:** Dynamic fetch and injection of authorized SSH public keys via URL (e.g., `https://github.com/ts-sz.keys`).
- **Wi-Fi & Ethernet Support:** Automatic fallback to Wi-Fi (`WIFI_SSID` / `WIFI_PASSWORD`) or Ethernet RJ45 connection.
- **Embedded Admin Utilities:** Includes `vim`, `tmux`, `curl`, `openssh`, and `wpa_supplicant`.

---

## 🔌 Hardware Wiring Diagram (DS18B20 1-Wire)

Connect the DS18B20 temperature sensor to the Raspberry Pi GPIO header (default GPIO 4 Data Pin):

![DS18B20 Wiring Diagram](https://kroki.strat.zone/mermaid/svg/eJxdT8GKwjAUvPcrHjllD1W7SrsnwRpwF8QNcVGW4CHahwZDWxKL-En7M_tNGxuVuu8wZHiTeTN7q-oDzEUEflyz3becLZO3_HUgye0BSyxdZYEm8VpbfCGbVn-d1XQqiQegAovugk2-Jt7AI9BvNKY6d7ezBZPEA9DcqN2xn5vmYYtl8RxHcC2JUK7eorUX4Bpm_OMT3lEVaDumPJGE6xISoMPecAW8OqPtXuVZEGRAW4cRMHVST4o0KFKvWLD_ia4943jsD0X3ioFn0a1UoGkU4ngGZNTLjr8_wBtj4qYGgU67U2XJ_ecf-zRfMA==)

> **Note:** A **4.7 kΩ pull-up resistor** is required between VCC (3.3V) and DATA (GPIO 4).

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

### 3. Customize Probe Parameters (`probe.conf`)

At the root of the SD card, copy `probe.conf.example` to `probe.conf` and edit it with a text editor (Notepad, VS Code, Nano):

```ini
# RPi64 Alpine Diskless Probe Configuration
HOSTNAME=celsius-fost-hq75-01
LOCATION=port-royal-b2
GPIO_PIN=4
SSH_KEYS_URL=https://github.com/ts-sz.keys
VICTORIAMETRICS_URL=http://10.200.140.109:8428/api/v1/import/prometheus
INTERVAL_SECONDS=10

# Optional: Wi-Fi Configuration (leave blank for RJ45 Ethernet)
WIFI_SSID=MyWifiNetwork
WIFI_PASSWORD=MySecretPassword
```

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
