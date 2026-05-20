#!/bin/bash
CONFIG_FILE="servers.json"

COUNT=$(jq '.servers | length' $CONFIG_FILE)

for (( i=0; i<$COUNT; i++ )); do
    IP=$(jq -r ".servers[$i].ip" $CONFIG_FILE)
    URL=$(jq -r ".servers[$i].webhook" $CONFIG_FILE)
    CPU_STATE=$(jq -r ".servers[$i].cpu_alert_active" $CONFIG_FILE)
    NGINX_STATE=$(jq -r ".servers[$i].nginx_alert_active" $CONFIG_FILE)
    RAM_STATE=$(jq -r ".servers[$i].ram_alert_active" $CONFIG_FILE)

    STATES=$(./alerting.sh "$IP" "$URL" "$CPU_STATE" "$NGINX_STATE" "$RAM_STATE")
    NEW_CPU_STATE=$(echo $STATES | awk '{print $1}')
    NEW_NGINX_STATE=$(echo $STATES | awk '{print $2}')
    NEW_RAM_STATE=$(echo $STATES | awk '{print $3}')


    jq ".servers[$i].cpu_alert_active = $NEW_CPU_STATE" $CONFIG_FILE > temp.json && mv temp.json $CONFIG_FILE
    jq ".servers[$i].nginx_alert_active = $NEW_NGINX_STATE" $CONFIG_FILE > temp.json && mv temp.json $CONFIG_FILE
    jq ".servers[$i].ram_alert_active = $NEW_RAM_STATE" $CONFIG_FILE > temp.json && mv temp.json $CONFIG_FILE
done
