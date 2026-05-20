#!/bin/bash

TARGET_IP=$1
WEBHOOK_URL=$2
CURRENT_CPU_STATE=$3
CURRENT_NGINX_STATE=$4
CURRENT_RAM_STATE=$5

CPU_THRESHOLD=85
NGINX_THRESHOLD=10
RAM_THRESHOLD=1200


get_metric() {
    local chart=$1
    local seconds=$2
    local jq_filter=$3

    local raw_json=$(curl -s "http://${TARGET_IP}:19999/api/v1/data?chart=${chart}&after=-${seconds}&points=1&group=average&format=json")

    if [[ -z "$raw_json" ]]; then
        echo "0"
        return
    fi

    local val=$(echo "$raw_json" | jq -r "$jq_filter")

    if [[ -z "$val" || "$val" == "null" ]]; then
        echo "0"
    else
        echo "$val"
    fi
}

send_alert() {
    local message=$1
    curl -s -H "Content-Type: application/json" -X POST \
         -d "{\"content\": \"$message\"}" "${WEBHOOK_URL}"
}

CPU_AVG=$(get_metric "system.cpu" 60 '.data[0][1:] | add')

NGINX_AVG=$(get_metric "nginx_site1_stats.connections" 60 '.data[0][1]')

RAM_AVG=$(get_metric "mem.available" 60 '.data[0][1]')



if (( $(echo "$CPU_AVG > $CPU_THRESHOLD" | bc -l) )); then
    if [ "$CURRENT_CPU_STATE" -eq 0 ]; then
        send_alert "[$TARGET_IP] - System CPU is overloaded: ${CPU_AVG}% (Threshold: ${CPU_THRESHOLD}%)"
    fi
    NEW_CPU_STATE=1
else
    if [ "$CURRENT_CPU_STATE" -eq 1 ]; then
        send_alert "[$TARGET_IP] - System CPU is back to normal"

    fi
    NEW_CPU_STATE=0
fi


if (( $(echo "$NGINX_AVG > $NGINX_THRESHOLD" | bc -l) )); then
    if [ "$CURRENT_NGINX_STATE" -eq 0 ]; then
        send_alert "[$TARGET_IP] - NGINX connections are high: ${NGINX_AVG} (Threshold: ${NGINX_THRESHOLD})"

    fi
    NEW_NGINX_STATE=1
else
    if [ "$CURRENT_NGINX_STATE" -eq 1 ]; then
        send_alert "[$TARGET_IP] - NGINX connections is back to normal"

    fi
    NEW_NGINX_STATE=0
fi

if (( $(echo "$RAM_AVG < $RAM_THRESHOLD" | bc -l) )); then
    if [ "$CURRENT_RAM_STATE" -eq 0 ]; then
        send_alert "[$TARGET_IP] - System RAM is overloaded: ${RAM_AVG}Mib (Threshold: ${RAM_THRESHOLD}Mib)"
    fi
    NEW_RAM_STATE=1
else
    if [ "$CURRENT_RAM_STATE" -eq 1 ]; then
        send_alert "[$TARGET_IP] - System RAM is back to normal"

    fi
    NEW_RAM_STATE=0
fi

echo "$NEW_CPU_STATE $NEW_NGINX_STATE $NEW_RAM_STATE"
