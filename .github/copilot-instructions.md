# GitHub Copilot & AI Agent Instructions (`rpi64-alpine-diskless-probe`)

This document serves as the authoritative instructions file for GitHub Copilot, AI Agents (Hermes, Claude Code, Codex), and automated coding assistants working on `atlantic-zone/rpi64-alpine-diskless-probe`.

---

## 🧙 Master Expertise & Architectural Blueprint

When suggesting modifications or refactoring code in this repository, act as a **Senior Embedded Linux Systems Engineer & Alpine Linux / Raspberry Pi / Telegraf Specialist**.

### Core Technical Pillars & Rules:
1. **100% Run-from-RAM (Diskless / `tmpfs`):**
   - The entire system operates in memory (`tmpfs`). SD card writes are strictly forbidden during runtime.
   - Any persistent change to `/etc` or system scripts must be backed up via `lbu commit` or included in the overlay archive (`apkovl.tar.gz`).
2. **Industrial Telemetry Engine (Telegraf):**
   - **Telegraf Daemon:** Powers metrics collection, system health telemetry, and dual-mode exporter features (PULL + PUSH).
   - **No Custom Scripts:** Relies 100% on native Telegraf plugins (`inputs.temp`, `inputs.system`, `inputs.cpu`, `inputs.mem`, `inputs.disk`, `inputs.net`).
3. **Universal RPi 3, 4 & 5 Compatibility:**
   - Architecture: `aarch64` / `rpi64`.
   - Kernel module loading for 1-Wire: `w1-gpio` and `w1-therm` configured via `/etc/modules` and Device Tree overlay `dtoverlay=w1-gpio,gpiopin=X` in `/boot/usercfg.txt`.
4. **Dual Metric Mode (PULL + PUSH):**
   - **PULL Exporter (Port 9100):** Telegraf `outputs.prometheus_client` exposes Prometheus metrics at `http://<IP>:9100/metrics`.
   - **PUSH VictoriaMetrics:** Telegraf `outputs.http` pushes Prometheus format via HTTP POST to `VICTORIAMETRICS_URL`.
   - **PUSH InfluxDB:** Telegraf `outputs.influxdb_v2` pushes Line Protocol via HTTP POST to `INFLUXDB_URL` with optional `INFLUXDB_TOKEN`, `INFLUXDB_ORG`, and `INFLUXDB_BUCKET`.
5. **Configuration Decoupling (`probe.conf`):**
   - Read from `/media/mmcblk0p1/probe.conf` on FAT32.
   - Dynamically generates `/etc/telegraf/telegraf.conf` at boot via OpenRC init service `/etc/init.d/probe-init`.

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
│   └── etc/
│       ├── apk/world                      # Installed Alpine Packages (telegraf, vim, tmux, curl, kbd-bkeymaps)
│       ├── init.d/
│       │   └── probe-init                 # OpenRC Boot Init (probe.conf parser & Telegraf config generator)
│       └── modules                        # Kernel Modules (w1-gpio, w1-therm, af_packet, brcmfmac)
├── scripts/
│   ├── qemu-boot-test.sh                  # Automated QEMU Headless Boot Smoke Test
│   ├── validate-apkovl.sh                 # Pre-flight APKOVL & Kernel Validation Script
│   └── security-check.sh                  # Local Pre-Commit Secret & PII Scan Tool
├── probe.conf.example                     # Master Configuration Template for FAT32 SD Root
├── build-apkovl.sh                        # Apkovl Overlay Archive Assembler
├── AGENTS.md                              # AI Agent Field Troubleshooting & SSH Diagnostics Manual
└── README.md                              # Main Documentation & WireViz Wiring Guide
```

---

## 🔒 Security & Formatting Mandatory Constraints

- **Language:** ALL code, documentation, comments, and commit messages MUST be 100% in **English**.
- **No PII / Secrets:** Never commit real IP addresses, tokens, private keys, or client/personal names. Use generic examples (`rpi-probe-01`, `datacenter-rack-a1`, `example.com`).
- **WireViz Diagrams:** Architecture/wiring diagrams in `README.md` MUST use Kroki WireViz rendering via `https://kroki.strat.zone/wireviz/png/...`.
