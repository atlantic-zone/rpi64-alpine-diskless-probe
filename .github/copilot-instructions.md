# GitHub Copilot & AI Agent Instructions (`rpi64-alpine-diskless-probe`)

This document serves as the authoritative instructions file for GitHub Copilot, AI Agents (Hermes, Claude Code, Codex), and automated CI/CD runners operating on this repository.

---

## 📌 Project Overview & Architecture

`rpi64-alpine-diskless-probe` is an ultra-lightweight, **100% Run-from-RAM (Diskless)** Alpine Linux 64-bit distribution for **Raspberry Pi 3, 4, and 5**. 

Its sole operational goal is continuous ambient temperature acquisition using a 1-Wire DS18B20 sensor and pushing metrics via HTTP POST to a **VictoriaMetrics** instance.

### Core Architectural Invariants

1. **System Runs 100% in RAM (`tmpfs`):**
   - The root filesystem (`/`) is mounted in memory. The SD card is mounted read-only (`/media/mmcblk0p1`).
   - **Crucial Rule:** Any modification made inside `/etc`, `/usr`, or `/root` on a running probe is volatile and **will be lost upon reboot** unless explicitly persisted using `lbu commit` (Alpine Local Backup).

2. **Master Configuration Source (`/media/mmcblk0p1/probe.conf`):**
   - The user configures the probe by editing `probe.conf` on the FAT32 SD card partition.
   - The OpenRC service `/etc/init.d/probe-init` reads this file on boot and dynamically configures `HOSTNAME`, Wi-Fi (`WIFI_SSID`/`WIFI_PASSWORD`), SSH authorized keys (`SSH_KEYS_URL`), and VictoriaMetrics endpoints.

3. **No Docker / No heavy daemons:**
   - Do NOT attempt to add Docker or container runtimes to this image. Everything runs natively via OpenRC scripts (`probe-init`, `ds18b20-pusher`).

---

## 🛠️ Repository File Map & Responsibilities

When proposing code modifications or extending features, follow this structure:

```text
rpi64-alpine-diskless-probe/
├── .github/
│   ├── copilot-instructions.md          <-- THIS FILE (Agent Guidance)
│   └── workflows/build-release.yml      <-- CI/CD GitHub Actions release pipeline
├── boot/
│   ├── cmdline.txt                      <-- Kernel boot params (alpine_dev=mmcblk0p1)
│   └── usercfg.txt                      <-- Raspberry Pi DTOverlay (dtoverlay=w1-gpio,gpiopin=4)
├── overlay/
│   └── etc/
│       ├── apk/world                    <-- Alpine packages installed in RAM (vim, tmux, curl...)
│       ├── init.d/probe-init            <-- OpenRC service applying FAT32 probe.conf
│       ├── init.d/ds18b20-pusher        <-- OpenRC metric pusher service
│       └── modules                      <-- Kernel modules (w1-gpio, w1-therm)
├── build-apkovl.sh                      <-- Local/CI script building the localhost.apkovl.tar.gz
├── probe.conf.example                   <-- Configuration template for end users
├── AGENTS.md                            <-- AI Agent SSH field troubleshooting guide
└── README.md                            <-- Main repository documentation with Kroki wiring diagram
```

---

## ⚠️ Guidelines for AI Agents Making Changes

### 1. Adding New Alpine Packages
If a new system tool is needed (e.g. `htop`, `jq`):
- Add the package name to `overlay/etc/apk/world`.
- The CI pipeline (`build-release.yml`) will automatically fetch its `.apk` dependencies into `/cache` for offline diskless boot.

### 2. Modifying Boot or Kernel Configs
- Raspberry Pi specific overlays go into `boot/usercfg.txt`.
- Kernel command-line parameters go into `boot/cmdline.txt`. Keep `alpine_dev=mmcblk0p1 quiet`.

### 3. Modifying Metric Collection Logic
- Edit `overlay/usr/local/bin/ds18b20-pusher.sh` or `/etc/init.d/ds18b20-pusher`.
- Ensure output format complies with Prometheus line protocol:
  `temperature_celsius{hostname="...",location="...",sensor="ds18b20"} XX.YYY`

### 4. Language & Documentation Standards
- All code comments, commit messages, PR descriptions, and `.md` files in this repository **MUST be written in English**.
- Markdown diagrams must use the `kroki.strat.zone` rendering URL pattern.

---

## 🧪 How to Build & Validate Locally

Before opening a PR or committing changes to the image:

```bash
# 1. Regenerate the apkovl archive locally
./build-apkovl.sh

# 2. Verify that build/rpi-probe.apkovl.tar.gz was created cleanly
tar -tzf build/rpi-probe.apkovl.tar.gz
```
