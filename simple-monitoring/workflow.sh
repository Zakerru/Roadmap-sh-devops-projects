#!/bin/bash

CONFIG_FILE="/home/seriojka/DevOps_learning_folder/old_scripts/Roadmapsh_devops_projects/simple-monitoring/servers.json"

while true; do
    COUNT=$(jq '.servers | length' $CONFIG_FILE)

    for (( i=0; i<$COUNT; i++ )); do
        IP=$(jq -r ".servers[$i].ip" $CONFIG_FILE)
        URL=$(jq -r ".servers[$i].webhook" $CONFIG_FILE)
        CPU_STATE=$(jq -r ".servers[$i].cpu_alert_active" $CONFIG_FILE)
        NGINX_STATE=$(jq -r ".servers[$i].nginx_alert_active" $CONFIG_FILE)
        RAM_STATE=$(jq -r ".servers[$i].ram_alert_active" $CONFIG_FILE)

        echo "Checking $IP health..."

        STATES=$(/home/seriojka/DevOps_learning_folder/old_scripts/Roadmapsh_devops_projects/simple-monitoring/alerting.sh "$IP" "$URL" "$CPU_STATE" "$NGINX_STATE" "$RAM_STATE")

        if [[ ! "$STATES" =~ ^[0-1]\ [0-1]\ [0-1]$ ]]; then
            echo "ERROR - Unexpected output from alerting.sh: $STATES"
            continue
        fi
        NEW_CPU_STATE=$(echo $STATES | awk '{print $1}')
        NEW_NGINX_STATE=$(echo $STATES | awk '{print $2}')
        NEW_RAM_STATE=$(echo $STATES | awk '{print $3}')

        if [ "$NEW_CPU_STATE" -eq 1 ] || [ "$NEW_NGINX_STATE" -eq 1 ] || [ "$NEW_RAM_STATE" -eq 1 ]; then
            echo "!!! - Check completed, new state codes - CPU:$NEW_CPU_STATE; NGINX:$NEW_NGINX_STATE; RAM:$NEW_RAM_STATE"
        else
            echo "Check completed, new state codes - CPU:$NEW_CPU_STATE; NGINX:$NEW_NGINX_STATE; RAM:$NEW_RAM_STATE"
        fi

        jq ".servers[$i].cpu_alert_active = $NEW_CPU_STATE" $CONFIG_FILE > /home/seriojka/DevOps_learning_folder/old_scripts/Roadmapsh_devops_projects/simple-monitoring/temp.json && mv /home/seriojka/DevOps_learning_folder/old_scripts/Roadmapsh_devops_projects/simple-monitoring/temp.json $CONFIG_FILE
        jq ".servers[$i].nginx_alert_active = $NEW_NGINX_STATE" $CONFIG_FILE > /home/seriojka/DevOps_learning_folder/old_scripts/Roadmapsh_devops_projects/simple-monitoring/temp.json && mv /home/seriojka/DevOps_learning_folder/old_scripts/Roadmapsh_devops_projects/simple-monitoring/temp.json $CONFIG_FILE
        jq ".servers[$i].ram_alert_active = $NEW_RAM_STATE" $CONFIG_FILE > /home/seriojka/DevOps_learning_folder/old_scripts/Roadmapsh_devops_projects/simple-monitoring/temp.json && mv /home/seriojka/DevOps_learning_folder/old_scripts/Roadmapsh_devops_projects/simple-monitoring/temp.json $CONFIG_FILE
    done
    sleep 10
done
