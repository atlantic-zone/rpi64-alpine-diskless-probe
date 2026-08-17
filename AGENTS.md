# AGENTS.md - AI Agent Operational & Field Troubleshooting Manual

Operational framework and reference manual for AI agents (Hermes, XO, subagents) and sysadmins operating on this repository or interacting with a deployed Raspberry Pi Alpine Diskless probe via SSH.

---

## 🎯 Scope & Hardware Compatibility

This repository (`atlantic-zone/rpi64-alpine-diskless-probe`) builds a **100% Run-from-RAM (Diskless)** Alpine Linux distribution for **Raspberry Pi 3, 4, and 5** (`aarch64` / `rpi64`).

Its primary function is continuous ambient temperature acquisition via a 1-Wire DS18B20 sensor and real-time HTTP POST ingestion into **VictoriaMetrics**.

---

## ⚠️ DISKLESS (RAM) OPERATIONAL RULES

1. **Root Filesystem is on `tmpfs` (RAM):**
   Any changes made to `/etc`, `/usr`, `/root`, or `/var` are volatile and **will be lost upon reboot** unless explicitly persisted using the Alpine Local Backup tool:
   ```bash
   lbu commit
   ```
2. **Master Configuration Source is `/media/mmcblk0p1/probe.conf`:**
   Resides on the FAT32 SD card partition. To modify `HOSTNAME`, `LOCATION`, `VICTORIAMETRICS_URL`, `GPIO_PIN`, or Wi-Fi credentials, edit `/media/mmcblk0p1/probe.conf` and re-apply settings:
   ```bash
   rc-service probe-init restart
   rc-service ds18b20-pusher restart
   ```
3. **No Docker / Container Daemons:**
   The probe operates entirely via native OpenRC init scripts to maintain minimal RAM and CPU footprint.

---

## 🛠️ Remote Diagnostics & SSH Troubleshooting

When connected to a deployed probe via SSH:

### 1. Verify 1-Wire DS18B20 Sensor Reading
```bash
cat /sys/bus/w1/devices/28-*/w1_slave
```
- **Expected Output:**
  ```text
  72 01 4b 46 7f ff 0e 10 57 : crc=57 YES
  72 01 4b 46 7f ff 0e 10 57 t=21437
  ```
  *(Presence of `YES` validates hardware CRC; `t=21437` indicates 21.437 °C).*

### 2. Check Service Daemon Status
```bash
rc-service ds18b20-pusher status
```

### 3. Test Manual Metric Ingestion to VictoriaMetrics
```bash
curl -sS -X POST "http://10.200.140.109:8428/api/v1/import/prometheus" \
  --data-binary 'temperature_celsius{hostname="test-probe",location="lab"} 20.5'
```

---

## 📌 File Architecture Reference

| Path / File | Purpose |
|---|---|
| `/media/mmcblk0p1/probe.conf` | Plaintext configuration source on FAT32 partition |
| `/etc/init.d/probe-init` | OpenRC service applying `probe.conf` settings at boot (Hostname, SSH, Wi-Fi) |
| `/etc/init.d/ds18b20-pusher` | OpenRC service managing the metrics collection loop |
| `/usr/local/bin/ds18b20-pusher.sh` | Shell script executing sensor sampling and HTTP POST push |
| `/etc/apk/world` | List of Alpine packages installed in RAM (`vim`, `tmux`, `curl`, etc.) |
