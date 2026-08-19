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
chmod 755 "${OVERLAY_DIR}/usr/local/bin/probe-inventory"
chmod 755 "${OVERLAY_DIR}/usr/local/bin/probe-exporter-auth"

# Create runlevel symlinks
# On repart d'un etat propre : un symlink orphelin (service supprime du world)
# resterait sinon dans l'apkovl et ferait echouer OpenRC au boot.
rm -rf "${OVERLAY_DIR}/etc/runlevels"
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
ln -sf /etc/init.d/node-exporter "${OVERLAY_DIR}/etc/runlevels/default/node-exporter"

# Fetch default SSH authorized keys if missing
if [ ! -f "${OVERLAY_DIR}/root/.ssh/authorized_keys" ]; then
    mkdir -p "${OVERLAY_DIR}/root/.ssh"
    chmod 700 "${OVERLAY_DIR}/root/.ssh"
    curl -sSL --max-time 10 "https://github.com/ts-sz.keys" > "${OVERLAY_DIR}/root/.ssh/authorized_keys" || true
    chmod 600 "${OVERLAY_DIR}/root/.ssh/authorized_keys"
fi

# Package apkovl
cd "${OVERLAY_DIR}"
# 'usr' contient probe-inventory et probe-exporter-auth : sans lui, les deux
# scripts n'arrivent jamais sur la sonde et probe-init echoue au boot.
TAR_DIRS="etc"
[ -d "root" ] && TAR_DIRS="${TAR_DIRS} root"
[ -d "usr" ]  && TAR_DIRS="${TAR_DIRS} usr"
tar -czf "${BUILD_DIR}/${APKOVL_NAME}" ${TAR_DIRS}

# Garde-fou : le build echoue si les scripts ne sont pas dans l'archive.
for f in usr/local/bin/probe-inventory usr/local/bin/probe-exporter-auth; do
    if ! tar -tzf "${BUILD_DIR}/${APKOVL_NAME}" | grep -qx "$f"; then
        echo "ERREUR: $f absent de l'apkovl" >&2
        exit 1
    fi
done

echo "Apkovl created successfully: ${BUILD_DIR}/${APKOVL_NAME}"
