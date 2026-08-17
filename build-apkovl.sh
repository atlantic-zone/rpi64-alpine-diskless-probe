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
mkdir -p "${OVERLAY_DIR}/etc/runlevels/default"
mkdir -p "${OVERLAY_DIR}/etc/runlevels/boot"

ln -sf /etc/init.d/probe-init "${OVERLAY_DIR}/etc/runlevels/boot/probe-init"
ln -sf /etc/init.d/sshd "${OVERLAY_DIR}/etc/runlevels/default/sshd"
ln -sf /etc/init.d/telegraf "${OVERLAY_DIR}/etc/runlevels/default/telegraf"

# Package apkovl
cd "${OVERLAY_DIR}"
tar -czf "${BUILD_DIR}/${APKOVL_NAME}" etc

echo "Apkovl created successfully: ${BUILD_DIR}/${APKOVL_NAME}"
