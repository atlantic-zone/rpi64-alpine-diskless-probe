#!/bin/sh
# /opt/data/workspace/1_projects/105_rpi64-alpine-diskless-probe/scripts/validate-apkovl.sh
# Automated pre-flight validation of the built apkovl overlay and dependencies.

set -e

echo "🔍 Running pre-flight APKOVL & Kernel validation checks..."

# 1. Syntax check on all shell scripts
echo "  [1/4] Checking shell script syntax..."
for s in overlay/etc/init.d/* overlay/usr/local/bin/*.sh build-apkovl.sh; do
    if [ -f "$s" ]; then
        sh -n "$s" || { echo "❌ Syntax error in $s"; exit 1; }
        echo "    ✓ Syntax OK: $s"
    fi
done

# 2. Check required kernel modules presence
echo "  [2/4] Validating kernel modules in overlay/etc/modules..."
REQUIRED_MODULES="w1-gpio w1-therm af_packet cfg80211 brcmfmac"
for mod in $REQUIRED_MODULES; do
    if grep -q "^${mod}$" overlay/etc/modules; then
        echo "    ✓ Module present: $mod"
    else
        echo "❌ Missing mandatory kernel module in overlay/etc/modules: $mod"
        exit 1
    fi
done

# 3. Check required packages in world file
echo "  [3/4] Validating APK packages in overlay/etc/apk/world..."
REQUIRED_PKGS="alpine-base openssh curl busybox-mdev-openrc busybox-extras chrony vim tmux wpa_supplicant tzdata kbd-bkeymaps"
for pkg in $REQUIRED_PKGS; do
    if grep -q "^${pkg}$" overlay/etc/apk/world; then
        echo "    ✓ Package present: $pkg"
    else
        echo "❌ Missing mandatory package in overlay/etc/apk/world: $pkg"
        exit 1
    fi
done

# 4. Check OpenRC init script dependencies and permissions
echo "  [4/4] Validating OpenRC script permissions and stanzas..."
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

echo "✅ All pre-flight APKOVL validation checks passed successfully!"
