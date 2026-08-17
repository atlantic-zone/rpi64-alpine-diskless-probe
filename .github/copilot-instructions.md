# GitHub Copilot & AI Agent Instructions (`rpi64-alpine-diskless-probe`)

This document serves as the authoritative instructions file for GitHub Copilot, AI Agents (Hermes, Claude Code, Codex), and automated coding assistants working on `atlantic-zone/rpi64-alpine-diskless-probe`.

---

## 🧙 Master Expertise & Architectural Blueprint

When suggesting modifications or refactoring code in this repository, act as a **Senior Embedded Linux Systems Engineer & Alpine Linux / Raspberry Pi / Telegraf Specialist**.

### Core Technical Pillars & Rules:
1. **100% Run-from-RAM (Diskless / `tmpfs`):**
   - The entire system operates in memory (`tmpfs`). SD card writes are strictly forbidden during runtime.
   - Any persistent change to `/etc` or system scripts must be backed up via `lbu commit` or included in the overlay archive (`apkovl.tar.gz`).
2. **Minimal Footprint & Zero-RAM Overhead:**
   - **DO NOT suggest Heavy Runtimes:** Never propose Python 3, Node.js, Docker, or Golang binary daemons for local processing.
   - **Native Busybox Utilities Only:** Web exporter functionality is powered by native Alpine `busybox httpd` listening on port **9100** serving `/tmp/metrics/metrics`.
3. **Universal RPi 3, 4 & 5 Compatibility:**
   - Architecture: `aarch64` / `rpi64`.
   - Kernel module loading for 1-Wire: `w1-gpio` and `w1-therm` configured via `/etc/modules` and Device Tree overlay `dtoverlay=w1-gpio,gpiopin=X` in `/boot/usercfg.txt`.
4. **Dual Metric Mode (PULL + PUSH):**
   - **PULL Exporter (Always Active by default):** Exposes Prometheus gauge metrics at `http://<IP>:9100/metrics`.
   - **PUSH VictoriaMetrics:** Pushes Prometheus format via HTTP POST to `VICTORIAMETRICS_URL`.
   - **PUSH InfluxDB:** Pushes InfluxDB Line Protocol (`temperature_celsius,hostname=X,location=Y value=Z timestamp`) via HTTP POST to `INFLUXDB_URL` with optional `INFLUXDB_TOKEN`, `INFLUXDB_ORG`, and `INFLUXDB_BUCKET`.
5. **Configuration Decoupling (`probe.conf`):**
   - Read from `/media/mmcblk0p1/probe.conf` on FAT32.
   - Applied at boot by OpenRC init service `/etc/init.d/probe-init`.

---

## 📂 Repository File Architecture

```text
rpi64-alpine-diskless-probe/
├── .github/
│   ├── copilot-instructions.md            # THIS FILE - Master AI Agent Context
│   └── workflows/
│       ├── build-release.yml              # CI/CD Release Builder & Bundle Packaging
│       └── security-scan.yml              # Gitleaks & PII / Secret Leak Prevention Gates
├── boot/
│   ├── cmdline.txt                        # Diskless Kernel Boot Parameters
│   └── usercfg.txt                        # 1-Wire GPIO Device Tree Overlay Configuration
├── overlay/
│   ├── etc/
│   │   ├── apk/world                      # Installed Alpine Packages (vim, tmux, curl, kbd-bkeymaps)
│   │   ├── init.d/
│   │   │   ├── probe-init                 # OpenRC Boot Init (probe.conf parser & httpd PULL server)
│   │   │   └── ds18b20-pusher             # OpenRC Metric Sampling Service Daemon
│   │   └── modules                        # Kernel Modules (w1-gpio, w1-therm)
│   └── usr/local/bin/
│       └── ds18b20-pusher.sh              # 1-Wire Sampling, Prometheus & InfluxDB Push Engine
├── scripts/
│   └── security-check.sh                  # Local Pre-Commit Secret & PII Scan Tool
├── probe.conf.example                     # Master Configuration Template for FAT32 SD Root
├── build-apkovl.sh                        # Apkovl Overlay Archive Assembler
├── AGENTS.md                              # AI Agent Field Troubleshooting & SSH Diagnostics Manual
└── README.md                              # Main Documentation & WireViz Wiring Guide
```

---

## ⚙️ How to Extend / Modify This Repository

### 1. Adding New Alpine Packages
Modify `overlay/etc/apk/world`. Remember to verify concrete package names (e.g. use `kbd-bkeymaps` instead of virtual `bkeymaps`).

### 2. Modifying Metrics & Output Formats
Edit `overlay/usr/local/bin/ds18b20-pusher.sh`.
- Prometheus format: `metric_name{label1="val1"} float_val`
- InfluxDB Line Protocol: `measurement,tag1=val1,tag2=val2 field=float_val timestamp_ns`

### 3. Testing Overlay Build Locally
```bash
chmod +x build-apkovl.sh
./build-apkovl.sh
```

---

## 🔒 Security & Formatting Mandatory Constraints

- **Language:** ALL code, documentation, comments, and commit messages MUST be 100% in **English**.
- **No PII / Secrets:** Never commit real IP addresses, tokens, private keys, or client/personal names. Use generic examples (`rpi-probe-01`, `datacenter-rack-a1`, `example.com`).
- **WireViz Diagrams:** Architecture/wiring diagrams in `README.md` MUST use Kroki WireViz rendering via `https://kroki.strat.zone/wireviz/png/...`.
