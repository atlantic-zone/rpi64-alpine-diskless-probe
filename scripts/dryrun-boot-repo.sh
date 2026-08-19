#!/bin/sh
# Local dry run of the release workflow's repository logic.
#
# Runs on x86_64 so it executes natively; the logic is arch-independent and the
# workflow uses aarch64. The world file is streamed in with the script instead of
# bind-mounted, so this works against a remote Docker daemon too.
set -e
cd "$(dirname "$0")/.."
ARCH=$(docker run --rm alpine:3.20.2 apk --print-arch)
echo "Dry run architecture: ${ARCH}"

{
    echo "set -e"
    echo "ARCH=${ARCH}"
    echo "cat > /world <<'WORLD_EOF'"
    cat overlay/etc/apk/world
    echo "WORLD_EOF"
    cat <<'SCRIPT_EOF'

apk add --quiet alpine-sdk
abuild-keygen -a -n -q
KEY=$(ls /root/.abuild/*.rsa | head -1)

mkdir -p /repo/$ARCH
apk update --quiet
apk fetch --quiet --recursive -o /repo/$ARCH $(cat /world)
cd /repo/$ARCH
apk index --quiet --rewrite-arch $ARCH -o index.tar.gz *.apk
abuild-sign -k "$KEY" index.tar.gz
mv index.tar.gz APKINDEX.tar.gz
touch /repo/.boot_repository
echo "Boot repository: $(ls /repo/$ARCH/*.apk | wc -l) packages"

# Reproduce the boot install: the apkovl supplies the signing public key and the
# initramfs merges the Alpine keys into the same directory.
mkdir -p /target/etc/apk/keys
apk add --root /target --initdb --quiet
cp -a /etc/apk/keys/. /target/etc/apk/keys/
cp "${KEY}.pub" /target/etc/apk/keys/

apk add --root /target --repository /repo --no-network \
    --initramfs-diskless-boot --clean-protected $(cat /world)

for f in usr/bin/curl usr/bin/node_exporter usr/sbin/sshd \
         etc/init.d/node-exporter etc/init.d/sshd etc/conf.d/node-exporter; do
    if [ -e "/target/$f" ]; then
        echo "  present: /$f"
    else
        echo "ERROR: /$f absent after an offline boot install" >&2
        exit 1
    fi
done
echo "Offline boot install verified."
SCRIPT_EOF
} | docker run --rm -i alpine:3.20.2 sh -s
