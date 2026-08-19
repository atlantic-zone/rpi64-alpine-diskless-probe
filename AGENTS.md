# AGENTS.md - Operational Manual for AI Agents and Sysadmins

Reference manual for AI agents (Hermes, XO, Copilot, Claude Code, Codex, subagents) and for
sysadmins working on this repository or on a deployed probe over SSH.

> **Language rule:** everything in this repository is written in **English** - code, comments,
> documentation, metric help strings, console output, commit messages, release notes.

---

## 1. What This Product Is

`atlantic-zone/rpi64-alpine-diskless-probe` builds a **100% run-from-RAM (diskless)** Alpine Linux
image for **Raspberry Pi 3, 4 and 5** (`aarch64` / `rpi64`).

It measures ambient temperature with **DS18B20 1-Wire sensors** and exposes them, along with host
telemetry, through **Prometheus node_exporter** on port **9100**.

The design rests on four properties. Preserve all four in any change:

1. **Zero mandatory configuration.** The image boots correctly with no `probe.conf` at all: DHCP on
   `eth0`, US keymap, Europe/Paris, exporter open on 9100. You write the image, you ship the image.
2. **Everything happens once, at boot.** `probe-init` reads the configuration, applies it, and exits.
   The system is steady-state afterwards.
3. **Native OpenRC services only**, kept to the minimum that the function requires.
4. **Metrics are scraped**, over HTTP, by Prometheus. The probe listens; it initiates nothing.

### Metrics Pipeline

```text
DS18B20 --1-Wire--> kernel (w1-gpio, w1-therm) --> /sys/bus/w1/devices/
                                                        |
                                            node_exporter hwmon collector
                                                        |
                                         http://<IP>:9100/metrics  <-- Prometheus scrape
```

Temperature is produced by the **kernel**, so it needs no collection agent. Two helper scripts
supply the small amount that the kernel cannot know. Both are called by `probe-init`, both run
exactly once, and both are required for the product to function:

| Script | Role | Consequence if removed |
|---|---|---|
| `probe-exporter-auth` | Builds node_exporter command-line options; enables basic auth when `EXPORTER_PASSWORD_HASH` is set | The exporter loses its options and its authentication |
| `probe-inventory` | Writes the `probe_info` metric carrying `client`, `site`, `location` labels | Inventory labels vanish from Prometheus |

`scripts/validate-apkovl.sh` enforces the presence of both and fails the build otherwise.

---

## 2. Diskless (RAM) Operating Rules

1. **The root filesystem is `tmpfs`.** Changes to `/etc`, `/usr`, `/root` or `/var` live until the
   next reboot. To persist one on a running probe:
   ```sh
   lbu commit
   ```
   To persist one across reflashes, edit `overlay/` in this repository and rebuild.

2. **The configuration source is `/media/mmcblk0p1/probe.conf`** on the FAT32 partition, read once
   at boot. To re-apply after an edit:
   ```sh
   rc-service probe-init restart
   rc-service node-exporter restart
   ```

3. **The SD card is mounted read-only** in normal operation. This is what makes the probe immune to
   power-cut corruption, and it is the reason the design exists.

4. **RAM is the budget.** A Pi 3B offers ~450 MB of `tmpfs`; the image sits around 210 MB (~47%).
   Before adding a package, measure what it pulls in. Example: `raspberrypi-utils` drags python3,
   perl, bash and sudo for 89 MB, while `raspberrypi-utils-vcgencmd` alone costs 80 KB and covers
   the usual need.

---

## 3. Writing Shell for Alpine

Alpine ships **BusyBox** applets and runs init scripts under **`ash`**. Write POSIX shell and use
the constructs BusyBox actually provides.

| Need | Use |
|---|---|
| Extract a field from command output | `awk` |
| Pattern matching in a script | `case ... esac`, or POSIX `grep` classes |
| Conditional test | `[ ... ]` |
| Lowercase a string | `tr '[:upper:]' '[:lower:]'` |
| Resolve a path | `cd` + `pwd` |

BusyBox `grep` implements POSIX BRE and ERE. PCRE options such as `-P` belong to GNU grep and are
unavailable here: calling one aborts the command and prints a usage page to the console, which on
this image lands on the HDMI screen at boot.

Reference extraction of the primary IPv4 address, POSIX and BusyBox-safe:

```sh
PRIMARY_IP=$(ip -o -4 addr show "${IFACE}" 2>/dev/null \
    | awk '{split($4,a,"/"); print a[1]; exit}')
```

**Validate every init script against real BusyBox before committing:**

```sh
docker run --rm -i alpine:3.20.2 sh -c 'cat > /p && busybox ash -n /p' < overlay/etc/init.d/probe-init
```

### Networking Rules

- **Declare `wlan0` only when `WIFI_SSID` is set.** On a wired probe an unconfigured `wlan0` sends
  `udhcpc` hunting for a lease on a dead interface, which costs about 20 seconds of boot time.
- **Restart networking only when `probe-init` has written a static address.** The `boot` runlevel
  has already brought `eth0` up and obtained a DHCP lease; that lease must survive `probe-init`.

---

## 4. Remote Diagnostics

```sh
ssh -p 34522 root@<IP>
```

Key authentication, on port 34522. Keys are fetched from `SSH_KEYS_URL` at every boot.

### 1. Are the sensors visible to the kernel?

```sh
ls /sys/bus/w1/devices/
cat /sys/bus/w1/devices/28-*/w1_slave
```

Expected:

```text
72 01 4b 46 7f ff 0e 10 57 : crc=57 YES
72 01 4b 46 7f ff 0e 10 57 t=21437
```

`YES` validates the CRC, `t=21437` means 21.437 °C. An empty directory points at the wiring: check
the 4.7 kΩ pull-up, 3.3 V on pin 1, data on pin 7.

### 2. Is the exporter answering?

```sh
curl -sS http://localhost:9100/metrics | head
curl -sS http://localhost:9100/metrics | grep w1_bus_master
```

Expected series:

```text
node_hwmon_temp_celsius{chip="w1_bus_master1_28_0000007137f7",sensor="temp1"} 25.312
probe_info{client="example-studio",site="paris-nord",location="server-room"} 1
```

A `401` means basic auth is active; scrape with `-u probe:<password>`.

### 3. Are the services running?

```sh
rc-service node-exporter status
rc-service probe-init status
rc-status
```

### 4. Is the system really running from RAM?

```sh
df -h /          # expected: tmpfs on /
free -m
```

### 5. Which packages are consuming RAM?

```sh
awk -F: '/^P:/{p=$2} /^I:/{printf "%10d  %s\n", $2, p}' /lib/apk/db/installed | sort -rn | head -20
```

---

## 5. Repository Layout

| Path | Purpose |
|---|---|
| `probe.conf.example` | Full commented configuration reference. **Authoritative** for what a variable does |
| `probe.conf` | Minimal configuration shipped on the card |
| `build-apkovl.sh` | Assembles the overlay archive, registers OpenRC runlevels |
| `overlay/etc/init.d/probe-init` | Boot init: parses `probe.conf`, applies settings, writes `/etc/issue` |
| `overlay/etc/apk/world` | 14 top-level packages |
| `overlay/etc/modules` | `af_packet`, `cfg80211`, `brcmfmac`, `w1-gpio`, `w1-therm` |
| `overlay/etc/runlevels/` | OpenRC symlinks (`probe-init` in `boot`, `node-exporter` and `sshd` in `default`) |
| `overlay/etc/ssh/sshd_config` | Port 34522, `PermitRootLogin prohibit-password`, `PasswordAuthentication no` |
| `overlay/root/README.md` | Field notes, shipped inside the image |
| `overlay/usr/local/bin/probe-exporter-auth` | node_exporter options and basic auth |
| `overlay/usr/local/bin/probe-inventory` | `probe_info` metric |
| `boot/usercfg.txt` | `dtoverlay=w1-gpio,gpiopin=4` |
| `boot/cmdline.txt` | Diskless kernel boot parameters |
| `scripts/validate-apkovl.sh` | Pre-flight overlay validation, run by CI |
| `scripts/scan-pii-local.py` | Local PII scan, mirrors the CI gate |

> `build-apkovl.sh` copies an explicit list of directories into the archive. When adding a new
> top-level directory under `overlay/`, add it to that list so its content reaches the image.

---

## 6. Build and Release

CI runs on `ubuntu-latest`, cross-building `aarch64` through `setup-qemu-action`.

1. Checkout
2. CalVer tag: `v$(date -u +%Y.%m.%d).${GITHUB_RUN_NUMBER}`
3. `scripts/validate-apkovl.sh`
4. QEMU setup
5. Build: Alpine RPi tarball + `build-apkovl.sh` + package cache fetched in an
   `arm64v8/alpine` container, packed into `dist/*.tar.gz`
6. Artifact upload
7. Release creation
8. Cleanup, keeping the last 5 releases

Run the same gate CI runs before any push:

```sh
python3 scripts/scan-pii-local.py
```

It fails on internal IP ranges (`10.255.`, `192.168.`) and on SSH public keys, and a red gate blocks
the release.

### Publication Rules

- **Generic examples only** in committed content: `rpi-probe-01`, `example-studio`, `example.com`,
  `10.0.0.150`. Secrets stay in Bitwarden / Vaultwarden and are retrieved at execution time.
- **Push and CI runs require explicit approval from Val.**
- Wiring diagrams in `README.md` use WireViz rendering.

---

## 7. Checklist Before Committing

1. Does the change keep the four design properties of section 1 intact?
2. Is the shell POSIX and BusyBox-compatible?
3. Has it passed `busybox ash -n`?
4. Is everything written in English, including comments and metric help strings?
5. Does the image still boot with no `probe.conf` present?
6. What does the change cost in RAM, and is that cost justified?
7. Is `scripts/validate-apkovl.sh` green?
8. Is `scripts/scan-pii-local.py` green?
9. Do you have explicit approval to push?
