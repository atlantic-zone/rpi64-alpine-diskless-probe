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
# would otherwise stay in the apkovl and make OpenRC fail at boot.
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

# Alpine restores this archive onto a running system, so the ownership and the
# modes recorded here are the ones the probe boots with. sshd StrictModes reads
# /root, /root/.ssh and authorized_keys and requires all three to be owned by
# root, and OpenRC runs an init script only when root owns it.
[ -d "root/.ssh" ] && chmod 700 "root/.ssh"
[ -f "root/.ssh/authorized_keys" ] && chmod 600 "root/.ssh/authorized_keys"

# 'usr' holds probe-inventory and probe-exporter-auth: without it, neither
# script ever reaches the probe and probe-init fails at boot.
TAR_DIRS="etc"
[ -d "root" ] && TAR_DIRS="${TAR_DIRS} root"
[ -d "usr" ]  && TAR_DIRS="${TAR_DIRS} usr"

# --owner/--group record uid 0 whatever account runs the build. A CI runner
# builds as uid 1001, and without these flags every restored file carries 1001,
# which makes sshd ignore authorized_keys and OpenRC skip probe-init.
tar --owner=root:0 --group=root:0 \
    -czf "${BUILD_DIR}/${APKOVL_NAME}" ${TAR_DIRS}

# Safety net: every entry must belong to uid 0 / gid 0. A single foreign owner
# produces an image that boots without SSH access and without the exporter.
BAD_OWNER="$(tar --numeric-owner -tvzf "${BUILD_DIR}/${APKOVL_NAME}" \
    | awk '$2 != "0/0" { print $2, $NF }')"
if [ -n "${BAD_OWNER}" ]; then
    echo "ERROR: apkovl entries not owned by root (uid/gid 0):" >&2
    echo "${BAD_OWNER}" >&2
    exit 1
fi

# Safety net: the build fails if the helper scripts are missing from the archive.
for f in usr/local/bin/probe-inventory usr/local/bin/probe-exporter-auth; do
    if ! tar -tzf "${BUILD_DIR}/${APKOVL_NAME}" | grep -qx "$f"; then
        echo "ERROR: $f missing from the apkovl" >&2
        exit 1
    fi
done

echo "Apkovl created successfully: ${BUILD_DIR}/${APKOVL_NAME}"
