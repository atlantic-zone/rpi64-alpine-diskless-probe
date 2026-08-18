#!/bin/sh
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${REPO_DIR}/build"
OVERLAY_DIR="${REPO_DIR}/overlay"

mkdir -p "${BUILD_DIR}"

HOSTNAME="rpi-probe"
APKOVL_NAME="${HOSTNAME}.apkovl.tar.gz"

echo "Building Alpine apkovl overlay: ${BUILD_DIR}/${APKOVL_NAME}"

# Ensure executable permissions on scripts
chmod 755 "${OVERLAY_DIR}/etc/init.d/probe-init"

# Create runlevel symlinks
mkdir -p "${OVERLAY_DIR}/etc/runlevels/sysinit"
mkdir -p "${OVERLAY_DIR}/etc/runlevels/boot"
mkdir -p "${OVERLAY_DIR}/etc/runlevels/default"

# Sysinit runlevel
ln -sf /etc/init.d/modloop "${OVERLAY_DIR}/etc/runlevels/sysinit/modloop"
ln -sf /etc/init.d/devfs "${OVERLAY_DIR}/etc/runlevels/sysinit/devfs"
ln -sf /etc/init.d/dmesg "${OVERLAY_DIR}/etc/runlevels/sysinit/dmesg"
ln -sf /etc/init.d/mdev "${OVERLAY_DIR}/etc/runlevels/sysinit/mdev"
ln -sf /etc/init.d/hwdrivers "${OVERLAY_DIR}/etc/runlevels/sysinit/hwdrivers"

# Boot runlevel
ln -sf /etc/init.d/localmount "${OVERLAY_DIR}/etc/runlevels/boot/localmount"
ln -sf /etc/init.d/modules "${OVERLAY_DIR}/etc/runlevels/boot/modules"
ln -sf /etc/init.d/networking "${OVERLAY_DIR}/etc/runlevels/boot/networking"
ln -sf /etc/init.d/chronyd "${OVERLAY_DIR}/etc/runlevels/boot/chronyd"
ln -sf /etc/init.d/probe-init "${OVERLAY_DIR}/etc/runlevels/boot/probe-init"

# Default runlevel
ln -sf /etc/init.d/sshd "${OVERLAY_DIR}/etc/runlevels/default/sshd"
ln -sf /etc/init.d/telegraf "${OVERLAY_DIR}/etc/runlevels/default/telegraf"

# Package apkovl
cd "${OVERLAY_DIR}"
tar -czf "${BUILD_DIR}/${APKOVL_NAME}" etc

echo "Apkovl created successfully: ${BUILD_DIR}/${APKOVL_NAME}"
