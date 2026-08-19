# RPi64 Alpine Diskless Probe - Field Notes

This system runs **entirely in RAM**. Anything installed here is gone after a reboot.
Total `tmpfs` on a Pi 3 is about 450 MB. Check before installing anything: `df -h /`

To make a change permanent, either run `lbu commit`, or put it in the `overlay/` directory of the
repository and rebuild the image.

---

## What This Probe Does

DS18B20 1-Wire sensors are read by the kernel and exported by **Prometheus node_exporter** on port
**9100**. There is no agent and no collection script: the kernel produces the readings, the exporter
publishes them.

```sh
curl -sS http://localhost:9100/metrics | grep w1_bus_master
```

```text
node_hwmon_temp_celsius{chip="w1_bus_master1_28_0000007137f7",sensor="temp1"} 25.312
```

Inventory labels come from `probe.conf` and are published separately:

```text
probe_info{client="example-studio",site="paris-nord",location="server-room"} 1
```

---

## Quick Diagnostics

```sh
ls /sys/bus/w1/devices/                  # sensors seen by the kernel
cat /sys/bus/w1/devices/28-*/w1_slave    # raw reading, "YES" = CRC valid
rc-service node-exporter status          # exporter state
rc-service probe-init status             # boot init state
rc-status                                # all services
df -h /                                  # must show tmpfs on /
free -m                                  # available memory
ip -o -4 addr show                       # addresses
```

Empty `/sys/bus/w1/devices/` means wiring: check the 4.7 kΩ pull-up resistor, 3.3 V on pin 1, data
on pin 7 (GPIO 4).

A `401` from the exporter means basic auth is enabled: `curl -u probe:<password> ...`

---

## Configuration

Everything is read once at boot from `/media/mmcblk0p1/probe.conf` on the SD card.

```sh
cat /media/mmcblk0p1/probe.conf
```

The card is mounted read-only. To edit it in place:

```sh
mount -o remount,rw /media/mmcblk0p1
vi /media/mmcblk0p1/probe.conf
mount -o remount,ro /media/mmcblk0p1
rc-service probe-init restart
```

Editing the card on a laptop is usually simpler.

---

## Shell Constraints (BusyBox)

This is Alpine: `grep`, `sed` and `awk` come from BusyBox and implement POSIX.

BusyBox `grep` supports BRE and ERE. PCRE options such as `-P` belong to GNU grep, so a command
using one aborts and prints its usage page to the console. Use `awk` to extract a field:

```sh
ip -o -4 addr show eth0 | awk '{split($4,a,"/"); print a[1]}'
```

Write any script on this probe in POSIX `sh`: `case ... esac` for matching, `[ ... ]` for tests,
`tr` for case conversion.

---

## Raspberry Pi Tools (vcgencmd, OTP, temperature)

Install the specific sub-package you need, each costing a few hundred KB:

```sh
apk add raspberrypi-utils-vcgencmd     # 80 KB  - temperature, OTP, throttling
apk add raspberrypi-utils-vcmailbox    # 80 KB  - raw firmware mailbox
apk add raspberrypi-utils-pinctrl      # 144 KB - GPIO state
```

The full `raspberrypi-utils` meta-package costs 89 MB of RAM, since it pulls python3, perl, bash and
sudo. On a 450 MB `tmpfs` that is a fifth of the system for a temperature reading.

Common usage:

```sh
vcgencmd measure_temp
vcgencmd get_throttled
vcgencmd otp_dump | grep '^17:'   # 1020000a = netboot OFF / 3020000a = netboot ON
```

Cost of the other sub-packages, for reference: `-raspinfo` pulls bash and sudo, `-otpset` pulls
python3 and misbehaves on Pi 3, `-ovmerge` and `-overlaycheck` pull perl.

---

## Editor

BusyBox `vi` is already present and costs nothing.
Full `vim` costs 33 MB of RAM (pulls vim-common + xxd):

```sh
apk add vim
```

---

## Local Console (HDMI + Keyboard)

`kbd-bkeymaps` ships with the image. The layout is set in `probe.conf` (`KEYMAP=us`, `us-intl`,
`fr`, `es`).

Change it live without rebooting:

```sh
loadkmap < /usr/share/bkeymaps/fr/fr.bkm
ls /usr/share/bkeymaps/          # available layouts
```

---

## Wi-Fi

Already in the image: `wpa_supplicant`, `wireless-regdb`, `linux-firmware-brcm`.
Configure it in `probe.conf` (`WIFI_SSID`, `WIFI_PASSWORD`, `WIFI_COUNTRY`), then reboot.

Note that `wlan0` is only brought up when `WIFI_SSID` is set: on a wired probe, an unconfigured
`wlan0` would stall the boot for about 20 seconds looking for a DHCP lease.

Immediate manual connection:

```sh
wpa_passphrase "MySSID" "MyPassword" > /etc/wpa_supplicant/wpa_supplicant.conf
rc-service wpa_supplicant restart
udhcpc -i wlan0
iw dev wlan0 link            # requires: apk add iw
```

---

## Extras

```sh
apk add rsync              # 1.5 MB
apk add jq                 # 1 MB
apk add tcpdump            # 1.5 MB
```

---

## Checking RAM Usage

```sh
df -h /            # root tmpfs usage
free -m            # memory
awk -F: '/^P:/{p=$2} /^I:/{printf "%10d  %s\n", $2, p}' /lib/apk/db/installed | sort -rn | head -20
```

The last command lists the 20 largest installed packages, in bytes.
