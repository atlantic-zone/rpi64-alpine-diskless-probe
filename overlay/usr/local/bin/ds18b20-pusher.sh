#!/bin/sh
# DS18B20 1-Wire Temperature Metric Pusher for VictoriaMetrics

CONF_FILE="/media/mmcblk0p1/probe.conf"

# Default fallback values
HOSTNAME="$(hostname 2>/dev/null || echo 'rpi-probe')"
LOCATION="unspecified"
VICTORIAMETRICS_URL="http://10.200.140.109:8428/api/v1/import/prometheus"
INTERVAL_SECONDS="10"

if [ -f "${CONF_FILE}" ]; then
    . "${CONF_FILE}"
fi

[ -z "${HOSTNAME}" ] && HOSTNAME="$(hostname)"
[ -z "${INTERVAL_SECONDS}" ] && INTERVAL_SECONDS="10"

echo "[ds18b20-pusher] Starting loop for ${HOSTNAME} (${LOCATION}) -> ${VICTORIAMETRICS_URL}"

while true; do
    SENSOR_FILE=$(ls /sys/bus/w1/devices/28-*/w1_slave 2>/dev/null | head -n 1)

    if [ -n "${SENSOR_FILE}" ] && [ -f "${SENSOR_FILE}" ]; then
        CONTENT=$(cat "${SENSOR_FILE}" 2>/dev/null)
        
        # Check CRC YES
        if echo "${CONTENT}" | grep -q "YES"; then
            RAW_TEMP=$(echo "${CONTENT}" | awk -F't=' '/t=/ {print $2}')
            if [ -n "${RAW_TEMP}" ]; then
                TEMP_C=$(awk "BEGIN {printf \"%.3f\", ${RAW_TEMP}/1000}")
                
                METRIC="temperature_celsius{hostname=\"${HOSTNAME}\",location=\"${LOCATION}\",sensor=\"ds18b20\"} ${TEMP_C}"
                
                curl -sS -X POST "${VICTORIAMETRICS_URL}" \
                    --data-binary "${METRIC}" >/dev/null 2>&1 || true
            fi
        fi
    fi

    sleep "${INTERVAL_SECONDS}"
done
