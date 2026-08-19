# RPi64 Alpine Diskless Temperature Probe (`rpi64-alpine-diskless-probe`)

[![Build & Release](https://github.com/atlantic-zone/rpi64-alpine-diskless-probe/actions/workflows/build-release.yml/badge.svg)](https://github.com/atlantic-zone/rpi64-alpine-diskless-probe/actions/workflows/build-release.yml)
[![Security Gates](https://github.com/atlantic-zone/rpi64-alpine-diskless-probe/actions/workflows/security-scan.yml/badge.svg)](https://github.com/atlantic-zone/rpi64-alpine-diskless-probe/actions/workflows/security-scan.yml)
[![Platform: RPi 3, 4 & 5](https://img.shields.io/badge/Platform-Raspberry%20Pi%203%20%7C%204%20%7C%205-red.svg)](https://www.raspberrypi.com/)
[![OS: Alpine Linux 64-bit](https://img.shields.io/badge/OS-Alpine%20Linux%2064--bit-blue.svg)](https://alpinelinux.org/)

Standalone **Alpine Linux Diskless (100% RAM / `tmpfs`)** image for Raspberry Pi 3, 4 and 5
(`aarch64` / `rpi64`), exposing DS18B20 1-Wire temperature sensors and host telemetry through
**Prometheus node_exporter**.

**Write the image, insert the SD card, power on.** No configuration file is required.

---

## Key Features

- **100% run-from-RAM (diskless):** the whole system runs in `tmpfs`. Nothing is written to the
  SD card at runtime, which removes the card-corruption failure mode caused by power cuts.
- **Zero mandatory configuration:** with no `probe.conf` at all the probe still boots with DHCP on
  `eth0`, US keymap, Europe/Paris timezone and an open exporter on port 9100.
- **Native DS18B20 support:** sensors wired to GPIO 4 are discovered by the kernel and exported by
  node_exporter as `node_hwmon_temp_celsius`. No agent, no parsing script, no cron.
- **Prometheus PULL exporter:** `http://<IP>:9100/metrics`, open by default, optionally protected
  by HTTP basic auth using a bcrypt hash (see `probe.conf.example`).
- **Hardened SSH:** listens on port **34522**, key authentication only, passwords refused.
  Authorized keys are fetched at every boot from the URLs listed in `SSH_KEYS_URL`.
- **Ethernet and Wi-Fi:** DHCP or static IPv4 on `eth0`; Wi-Fi is configured only when `WIFI_SSID`
  is set.
- **Small footprint:** 14 top-level packages. Around 210 MB of RAM in use on a Pi 3B (~47% of the
  available `tmpfs`).

---

## Hardware Wiring (DS18B20)

Connect the **DS18B20 1-Wire digital temperature sensor** to the 40-pin GPIO header:

| Wire Color | Signal | Description | RPi Header Pin |
| :--- | :--- | :--- | :--- |
| **RED** | `VCC` | Power (3.3 V DC) | **Pin 1** (`3.3V`) |
| **BLACK** | `GND` | Ground | **Pin 6** or **Pin 9** (`GND`) |
| **YELLOW** | `DATA` | 1-Wire data line | **Pin 7** (`GPIO 4 / GPCLK0`) |

> **CRITICAL - LOGIC LEVEL:** the red (VCC) wire goes to **pin 1 (3.3 V)**. DS18B20 sensors and
> Raspberry Pi GPIO pins operate strictly at **3.3 V**, and the 5 V rail on pins 2 and 4 destroys
> the GPIO port on contact. Confirm the pin number before powering the board.

### Wiring Harness Diagram (generated with WireViz)

![DS18B20 single sensor wiring harness with 4.7k pull-up resistor (WireViz)](assets/wireviz-ds18b20.png)

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

> **Pull-up resistor required:** a **4.7 kΩ** resistor (1/4 W, colour code Yellow-Violet-Red-Gold)
> must sit between the **RED (3.3 V)** line and the **YELLOW (DATA)** line for 1-Wire signal
> integrity.

Several sensors can share the same data line: each one has a unique address and is exported
separately.

---

## SD Card Preparation

The card carries a single FAT32 partition holding the Alpine boot files, the release archive and,
optionally, `probe.conf`. Any card of 1 GB or more works: the system runs in RAM and writes nothing
back.

> **Read the device name from the listing every time.** Disk numbering changes between machines and
> between reboots, and the format command erases whatever device it is given. Confirm the size and
> the name match the card you just inserted before running it.

### macOS

**1. Identify the card**

```bash
diskutil list
```

Look for the disk whose size matches the card, and note its identifier:

```text
/dev/disk4 (external, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:     FDisk_partition_scheme                        *7.9 GB     disk4
   1:                 DOS_FAT_32 NO NAME                 7.9 GB     disk4s1
```

Here the card is `disk4`. Substitute that number for `X` in the commands below.

**2. Format as FAT32**

```bash
diskutil eraseDisk FAT32 RPIPROBE MBRFormat /dev/rdiskX
```

`rdiskX` is the raw device, 10x to 20x faster than `diskX` because it bypasses the kernel buffer
cache. The card mounts itself at `/Volumes/RPIPROBE` when the command finishes.

**3. Extract the release**

```bash
curl -L -o /tmp/rpi-probe.tar.gz \
  "https://github.com/atlantic-zone/rpi64-alpine-diskless-probe/releases/latest/download/rpi64-alpine-diskless-probe-latest.tar.gz"

sudo tar -xzf /tmp/rpi-probe.tar.gz -C /Volumes/RPIPROBE
```

`sudo` preserves the file modes carried in the archive. Downloading to a file first lets `curl`
report a failed transfer, which piping straight into `tar` hides.

**4. Flush and eject**

```bash
sync
diskutil eject /dev/diskX
```

`eject` refuses while a process still holds the volume: close any Finder window or shell sitting in
`/Volumes/RPIPROBE` first. Wait for `Disk /Volumes/RPIPROBE ejected` before pulling the card.

### Linux

**1. Identify the card**

```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL
```

```text
NAME   SIZE TYPE MOUNTPOINT MODEL
sda    477G disk            Samsung SSD 860
└─sda1 477G part /
sdb    7.4G disk            SD Card Reader
└─sdb1 7.4G part /media/user/NO NAME
```

Here the card is `sdb`. Substitute that letter for `X` below, and confirm the size before going
further: `sda` is the system disk.

**2. Unmount any auto-mounted partition**

```bash
sudo umount /dev/sdX* 2>/dev/null
```

**3. Create a single FAT32 partition**

```bash
sudo parted -s /dev/sdX mklabel msdos
sudo parted -s /dev/sdX mkpart primary fat32 1MiB 100%
sudo parted -s /dev/sdX set 1 boot on
sudo mkfs.vfat -F 32 -n RPIPROBE /dev/sdX1
```

**4. Mount and extract the release**

```bash
sudo mkdir -p /mnt/rpiprobe
sudo mount /dev/sdX1 /mnt/rpiprobe

curl -L -o /tmp/rpi-probe.tar.gz \
  "https://github.com/atlantic-zone/rpi64-alpine-diskless-probe/releases/latest/download/rpi64-alpine-diskless-probe-latest.tar.gz"

sudo tar -xzf /tmp/rpi-probe.tar.gz -C /mnt/rpiprobe
```

**5. Flush and unmount**

```bash
sync
sudo umount /mnt/rpiprobe
```

`umount` completes the write. Pulling the card on the strength of `sync` alone leaves the FAT
metadata unwritten, and the Pi then boots to a firmware rainbow screen.

### Windows

Format the card as FAT32 with the built-in formatter, then extract the release archive to the root
of the card with 7-Zip. Use the "Safely Remove Hardware" tray icon to flush the write.

### Verify the card

```bash
ls /Volumes/RPIPROBE          # macOS
ls /mnt/rpiprobe              # Linux
```

Six entries confirm a complete extraction:

```text
config.txt              Raspberry Pi firmware configuration
cmdline.txt             kernel command line
localhost.apkovl.tar.gz the overlay Alpine restores into RAM at boot
boot/                   kernel and initramfs
apks/ and cache/        the packages installed at boot, offline
probe.conf              your settings, already at the root and ready to edit
```

The card is ready. Editing `probe.conf` is optional: do it only if you need a fixed hostname,
inventory labels, Wi-Fi or a static IP. `probe.conf.example` sits next to it, documenting every
variable.

---

## `probe.conf` Reference

The file lives at the root of the FAT32 partition (`/media/mmcblk0p1/probe.conf`) and is read once
at boot. **Every variable is optional.**

| Section | Variable | Default | Description |
| :--- | :--- | :--- | :--- |
| **Identification** | `HOSTNAME` | `rpi-probe` | Network name of the probe. |
| | `CLIENT` | *(empty)* | Inventory label exported in `probe_info`. |
| | `SITE` | *(empty)* | Inventory label exported in `probe_info`. |
| | `LOCATION` | *(empty)* | Inventory label exported in `probe_info`. |
| **Regional** | `TIMEZONE` | `Europe/Paris` | System timezone, e.g. `Europe/Paris`, `UTC`. |
| | `KEYMAP` | `us` | Console keyboard layout (`us`, `us-intl`, `fr`, `es`). |
| **Metrics** | `EXPORTER_PASSWORD_HASH` | *(empty)* | bcrypt hash. Empty means the exporter is open. Must be quoted with **single** quotes. |
| | `EXPORTER_USER` | `probe` | Username matching the hash. |
| **SSH** | `SSH_KEYS_URL` | `https://github.com/ts-sz.keys` | Space-separated list of URLs to fetch public keys from. |
| | `ROOT_PASSWORD` | *(empty)* | Root password for the local HDMI console only. |
| **Network** | `STATIC_IP` | *(DHCP)* | Static IPv4 address. Leave unset for DHCP. |
| | `NET_IFACE` | `eth0` | Interface carrying the static address. |
| | `NET_MASK` | `255.255.255.0` | Subnet mask for the static address. |
| | `NET_GATEWAY` | `.1` of the subnet | Default gateway. |
| | `DNS_SERVERS` | *(system)* | Space-separated DNS servers, e.g. `"1.1.1.1 8.8.8.8"`. |
| **Wi-Fi** | `WIFI_SSID` | *(empty)* | Wi-Fi SSID. When empty, `wlan0` is not configured at all. |
| | `WIFI_PASSWORD` | *(empty)* | WPA2 passphrase. |
| | `WIFI_COUNTRY` | `FR` | Two-letter ISO regulatory domain. |
| **Sensors** | `GPIO_PIN` | `4` | GPIO pin carrying the 1-Wire data line. |

Full commented reference, including how to generate the bcrypt hash: `probe.conf.example`.

---

## Metrics

The exporter answers on `http://<IP>:9100/metrics`.

DS18B20 readings appear natively, one series per sensor:

```text
node_hwmon_temp_celsius{chip="w1_bus_master1_28_0000007137f7",sensor="temp1"} 25.312
```

Inventory labels are published as a separate metric by `probe-inventory`:

```text
probe_info{client="example-studio",site="paris-nord",location="server-room"} 1
```

Join the two on the Prometheus side to attach inventory labels to every temperature reading:

```promql
node_hwmon_temp_celsius{chip=~"w1_bus_master.*"}
  * on(instance) group_left(client, site, location) probe_info
```

Scrape configuration, with the exporter left open:

```yaml
- job_name: rpi-probes
  static_configs:
    - targets: ['10.0.0.150:9100']
```

With basic auth enabled:

```yaml
- job_name: rpi-probes
  basic_auth:
    username: probe
    password: YourPassword
  static_configs:
    - targets: ['10.0.0.150:9100']
```

---

## Verification and Diagnostics

Once the Pi has booted, the local HDMI console shows the hostname, the IP address, the metrics URL
and the SSH command. Then, over SSH (`ssh -p 34522 root@<IP>`):

1. **Scrape the exporter:**
   ```sh
   curl -sS http://localhost:9100/metrics | head
   ```
2. **Check the sensors are seen by the kernel:**
   ```sh
   ls /sys/bus/w1/devices/
   cat /sys/bus/w1/devices/28-*/w1_slave
   ```
   `YES` on the first line validates the CRC; `t=21437` means 21.437 °C.
3. **Check temperatures are exported:**
   ```sh
   curl -sS http://localhost:9100/metrics | grep w1_bus_master
   ```
4. **Check the services:**
   ```sh
   rc-service node-exporter status
   rc-service probe-init status
   ```
5. **Confirm the root filesystem is RAM:**
   ```sh
   df -h /          # expected: tmpfs mounted on /
   free -m
   ```

### Common Issues

| Symptom | Likely cause | Check |
| :--- | :--- | :--- |
| No IP on the console banner | No DHCP lease | Cable, switch port, `ifup eth0` |
| `/sys/bus/w1/devices/` empty | Wiring, or missing pull-up resistor | 4.7 kΩ resistor, 3.3 V on pin 1, data on pin 7 |
| Port 9100 refuses the connection | Exporter down | `rc-service node-exporter status` |
| 401 on `/metrics` | Basic auth enabled | Username and password must match the bcrypt hash |
| Settings from `probe.conf` ignored | File not read | Must sit at the root of the FAT32 partition, named exactly `probe.conf` |

Remember that the root filesystem is RAM: any change made over SSH is lost on reboot unless it is
persisted with `lbu commit` or baked into the overlay archive.

---

## Repository Layout

```text
rpi64-alpine-diskless-probe/
├── .github/
│   ├── copilot-instructions.md     # Pointer to AGENTS.md for Copilot
│   └── workflows/
│       ├── build-release.yml       # Image build and release publication
│       └── security-scan.yml       # Gitleaks + PII gates
├── boot/
│   ├── cmdline.txt                 # Diskless kernel boot parameters
│   └── usercfg.txt                 # 1-Wire device tree overlay
├── overlay/                        # Content of the apkovl (the running system)
│   ├── etc/
│   │   ├── apk/world               # 14 top-level packages
│   │   ├── init.d/probe-init       # Boot init: reads probe.conf, applies settings
│   │   ├── modules                 # w1-gpio, w1-therm, brcmfmac, ...
│   │   ├── runlevels/              # OpenRC service symlinks
│   │   └── ssh/sshd_config         # Port 34522, keys only
│   ├── root/README.md              # On-probe field notes (shipped in the image)
│   └── usr/local/bin/
│       ├── probe-exporter-auth     # Builds node_exporter options at boot
│       └── probe-inventory         # Publishes the probe_info metric
├── scripts/
│   ├── qemu-boot-test.sh           # Headless QEMU boot smoke test
│   ├── validate-apkovl.sh          # Pre-flight overlay validation
│   ├── security-check.sh           # Local secret scan
│   └── scan-pii-local.py           # Local PII scan, mirrors the CI gate
├── build-apkovl.sh                 # Assembles the overlay archive
├── probe.conf.example              # Full commented configuration reference
├── probe.conf                      # Minimal configuration shipped on the card
├── AGENTS.md                       # Instructions for AI agents and sysadmins
└── README.md                       # This file
```

---

## Notice

Copyright (c) 2026 Atlantic Zone / Strategic Zone. All rights reserved.
