#!/bin/sh
# /usr/local/bin/ds18b20-pusher.sh
# Reads DS18B20 1-Wire temperature sensor, generates local Prometheus metrics,
# and pushes to VictoriaMetrics / InfluxDB endpoints if configured.

CONF_FILE="/media/mmcblk0p1/probe.conf"

# Default fallback settings
HOSTNAME="${HOSTNAME:-rpi-probe}"
LOCATION="${LOCATION:-unspecified}"
GPIO_PIN="${GPIO_PIN:-4}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-10}"
VICTORIAMETRICS_URL=""
INFLUXDB_URL=""
INFLUXDB_TOKEN=""
INFLUXDB_ORG=""
INFLUXDB_BUCKET=""

if [ -f "${CONF_FILE}" ]; then
    . "${CONF_FILE}"
fi

# Ensure /tmp/metrics web root exists
mkdir -p /tmp/metrics

while true; do
    # Find DS18B20 sensor file
    SENSOR_FILE=$(ls /sys/bus/w1/devices/28-*/w1_slave 2>/dev/null | head -n 1)

    if [ -n "${SENSOR_FILE}" ] && [ -f "${SENSOR_FILE}" ]; then
        RAW_OUTPUT=$(cat "${SENSOR_FILE}")
        
        # Verify CRC check (YES)
        if echo "${RAW_OUTPUT}" | grep -q "YES"; then
            TEMP_RAW=$(echo "${RAW_OUTPUT}" | grep -o "t=[0-9]*" | cut -d'=' -f2)
            if [ -n "${TEMP_RAW}" ]; then
                # Convert millidegrees Celsius to float Celsius
                TEMP_C=$(awk -v t="${TEMP_RAW}" 'BEGIN { printf "%.3f", t / 1000 }')
                TIMESTAMP_MS=$(date +%s%3N)
                TIMESTAMP_SEC=$(date +%s)

                # --------------------------------------------------------------
                # 1. GENERATE LOCAL PROMETHEUS METRICS FILE (PULL Server)
                # Served by Busybox httpd on http://<IP>:9100/metrics
                # --------------------------------------------------------------
                cat > /tmp/metrics/metrics <<EOF
# HELP temperature_celsius Ambient temperature in Celsius from DS18B20 sensor
# TYPE temperature_celsius gauge
temperature_celsius{hostname="${HOSTNAME}",location="${LOCATION}",sensor="ds18b20"} ${TEMP_C}
EOF

                # --------------------------------------------------------------
                # 2. PUSH TO VICTORIAMETRICS (Prometheus format)
                # --------------------------------------------------------------
                if [ -n "${VICTORIAMETRICS_URL}" ]; then
                    curl -sS -X POST "${VICTORIAMETRICS_URL}" \
                        --data-binary "temperature_celsius{hostname=\"${HOSTNAME}\",location=\"${LOCATION}\",sensor=\"ds18b20\"} ${TEMP_C}" \
                        --max-time 5 >/dev/null 2>&1 || true
                fi

                # --------------------------------------------------------------
                # 3. PUSH TO INFLUXDB v2 / v1 (Line Protocol format)
                # --------------------------------------------------------------
                if [ -n "${INFLUXDB_URL}" ]; then
                    INFLUX_LINE="temperature_celsius,hostname=${HOSTNAME},location=${LOCATION},sensor=ds18b20 value=${TEMP_C} ${TIMESTAMP_MS}000000"
                    
                    AUTH_HEADER=""
                    if [ -n "${INFLUXDB_TOKEN}" ]; then
                        AUTH_HEADER="Authorization: Token ${INFLUXDB_TOKEN}"
                    fi

                    TARGET_URL="${INFLUXDB_URL}"
                    if [ -n "${INFLUXDB_ORG}" ] && [ -n "${INFLUXDB_BUCKET}" ]; then
                        TARGET_URL="${INFLUXDB_URL}?org=${INFLUXDB_ORG}&bucket=${INFLUXDB_BUCKET}"
                    fi

                    curl -sS -X POST "${TARGET_URL}" \
                        -H "${AUTH_HEADER}" \
                        --data-binary "${INFLUX_LINE}" \
                        --max-time 5 >/dev/null 2>&1 || true
                fi
            fi
        fi
    else
        # Sensor missing / unreadable fallback metric
        cat > /tmp/metrics/metrics <<EOF
# HELP temperature_celsius Ambient temperature in Celsius from DS18B20 sensor
# TYPE temperature_celsius gauge
temperature_celsius{hostname="${HOSTNAME}",location="${LOCATION}",sensor="ds18b20",status="error"} NaN
EOF
    fi

    sleep "${INTERVAL_SECONDS}"
done
