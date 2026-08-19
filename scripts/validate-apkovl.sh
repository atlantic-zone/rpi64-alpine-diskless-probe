#!/bin/sh
# scripts/validate-apkovl.sh
# Validation pre-vol de l'overlay apkovl et de ses dependances.

set -e

echo "🔍 Running pre-flight APKOVL & Kernel validation checks..."

# 1. Syntaxe de tous les scripts shell
echo "  [1/6] Checking shell script syntax..."
for s in overlay/etc/init.d/* overlay/usr/local/bin/* build-apkovl.sh; do
    if [ -f "$s" ]; then
        sh -n "$s" || { echo "❌ Syntax error in $s"; exit 1; }
        echo "    ✓ Syntax OK: $s"
    fi
done

# 2. Modules noyau requis
echo "  [2/6] Validating kernel modules in overlay/etc/modules..."
REQUIRED_MODULES="w1-gpio w1-therm af_packet cfg80211 brcmfmac"
for mod in $REQUIRED_MODULES; do
    if grep -q "^${mod}$" overlay/etc/modules; then
        echo "    ✓ Module present: $mod"
    else
        echo "❌ Missing mandatory kernel module in overlay/etc/modules: $mod"
        exit 1
    fi
done

# 3. Paquets requis dans world
echo "  [3/6] Validating APK packages in overlay/etc/apk/world..."
REQUIRED_PKGS="alpine-base openssh curl busybox-mdev-openrc busybox-extras chrony tmux wpa_supplicant tzdata kbd-bkeymaps prometheus-node-exporter prometheus-node-exporter-openrc"
for pkg in $REQUIRED_PKGS; do
    if grep -q "^${pkg}$" overlay/etc/apk/world; then
        echo "    ✓ Package present: $pkg"
    else
        echo "❌ Missing mandatory package in overlay/etc/apk/world: $pkg"
        exit 1
    fi
done

# Aucun paquet ne doit servir a hacher un mot de passe sur la sonde :
# le hash bcrypt est fabrique par l'admin sur sa machine.
for pkg in apache2-utils apr apr-util telegraf; do
    if grep -q "^${pkg}$" overlay/etc/apk/world; then
        echo "❌ Paquet interdit dans world: $pkg"
        exit 1
    fi
done
echo "    ✓ Aucun paquet interdit"

# 4. Scripts OpenRC : permissions et depend()
echo "  [4/6] Validating OpenRC script permissions and stanzas..."
for script in overlay/etc/init.d/*; do
    if [ -f "$script" ]; then
        if [ ! -x "$script" ]; then
            echo "❌ Init script not executable: $script"
            exit 1
        fi
        grep -q "^depend()" "$script" || { echo "❌ Init script missing depend() block: $script"; exit 1; }
        echo "    ✓ OpenRC script OK: $script"
    fi
done

# 5. Scripts de la sonde presents et appeles au boot
echo "  [5/6] Validating probe helper scripts..."
for helper in probe-inventory probe-exporter-auth; do
    if [ ! -f "overlay/usr/local/bin/${helper}" ]; then
        echo "❌ Missing overlay/usr/local/bin/${helper}"
        exit 1
    fi
    if ! grep -q "/usr/local/bin/${helper}" overlay/etc/init.d/probe-init; then
        echo "❌ ${helper} jamais appele par probe-init"
        exit 1
    fi
    echo "    ✓ Helper OK: ${helper}"
done

# 'usr' doit etre empaquete, sinon les helpers n'arrivent pas sur la sonde
if ! grep -q 'usr' build-apkovl.sh; then
    echo "❌ build-apkovl.sh n'empaquete pas overlay/usr"
    exit 1
fi
echo "    ✓ overlay/usr empaquete"

# Aucun mot de passe en clair dans les fichiers de conf livres
if grep -qE '^[[:space:]]*EXPORTER_PASSWORD=' probe.conf probe.conf.example 2>/dev/null; then
    echo "❌ EXPORTER_PASSWORD (clair) present : utiliser EXPORTER_PASSWORD_HASH"
    exit 1
fi
echo "    ✓ Aucun mot de passe en clair"

# 6. Reseau et runlevels
echo "  [6/6] Validating network config and runlevel definitions..."
if [ ! -f "overlay/etc/network/interfaces" ]; then
    echo "❌ Missing overlay/etc/network/interfaces"
    exit 1
fi
echo "    ✓ Default network interfaces OK"

REQUIRED_RUNLEVELS="sysinit/modloop boot/modules boot/networking boot/chronyd boot/probe-init default/node-exporter default/sshd"
for rl in $REQUIRED_RUNLEVELS; do
    if ! grep -q "$rl" build-apkovl.sh; then
        echo "❌ Missing runlevel definition $rl in build-apkovl.sh"
        exit 1
    fi
done
echo "    ✓ Runlevel symlinks OK"

# SSH durci
grep -q "^Port 34522$" overlay/etc/ssh/sshd_config || { echo "❌ SSH port != 34522"; exit 1; }
grep -q "^PasswordAuthentication no$" overlay/etc/ssh/sshd_config || { echo "❌ PasswordAuthentication non desactive"; exit 1; }
echo "    ✓ SSH hardening OK"

echo "✅ All pre-flight APKOVL validation checks passed successfully!"
