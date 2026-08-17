#!/bin/sh
# /opt/data/workspace/1_projects/105_rpi64-alpine-diskless-probe/scripts/qemu-boot-test.sh
# Automated QEMU integration test for RPi Alpine Diskless Probe.

set -e

echo "🚀 Starting QEMU boot integration test for Alpine Diskless Probe..."

# Check prerequisites
command -v qemu-system-aarch64 >/dev/null 2>&1 || { echo "❌ qemu-system-aarch64 not installed"; exit 1; }

STAGING_DIR="${1:-staging}"
if [ ! -f "${STAGING_DIR}/boot/vmlinuz-rpi" ]; then
    echo "❌ Staging directory invalid or missing vmlinuz-rpi: ${STAGING_DIR}"
    exit 1
fi

LOG_FILE="/tmp/qemu-boot.log"
rm -f "$LOG_FILE"

echo "  [1/2] Launching QEMU raspi3b headless boot..."
# Launch QEMU with serial output directed to log file
timeout 40 qemu-system-aarch64 \
  -M raspi3b \
  -cpu cortex-a53 \
  -m 1024 \
  -kernel "${STAGING_DIR}/boot/vmlinuz-rpi" \
  -initrd "${STAGING_DIR}/boot/initramfs-rpi" \
  -dtb "${STAGING_DIR}/bcm2710-rpi-3-b-plus.dtb" \
  -append "earlycon=pl011,0x3f201000 console=ttyAMA0,115200" \
  -nographic \
  -no-reboot > "$LOG_FILE" 2>&1 || true

echo "  [2/2] Analyzing serial boot log..."

# Verify Kernel boot
if grep -q "Linux version 6.6" "$LOG_FILE"; then
    echo "    ✓ Kernel 6.6 booted successfully"
else
    echo "❌ Kernel boot failed!"
    cat "$LOG_FILE"
    exit 1
fi

# Verify Alpine Init
if grep -q "Alpine Init" "$LOG_FILE"; then
    echo "    ✓ Alpine Init initialized"
else
    echo "❌ Alpine Init failed!"
    cat "$LOG_FILE"
    exit 1
fi

# Verify no fatal Kernel Panic
if grep -q "Kernel panic" "$LOG_FILE"; then
    echo "❌ Fatal Kernel Panic detected in boot log!"
    grep -A 10 "Kernel panic" "$LOG_FILE"
    exit 1
else
    echo "    ✓ No Kernel Panic detected"
fi

echo "✅ QEMU boot integration test completed successfully!"
