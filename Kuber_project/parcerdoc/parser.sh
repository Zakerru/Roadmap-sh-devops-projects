#!/bin/bash

SITE_NAME="${SITE_NAME:-unknown_site}"

LOG_FILE="/var/log/nginx/nginx-access.log"
REPORT_FILE="/tmp/analyzer_report.log"

sleep 15

while true; do
    if [ -f "$LOG_FILE" ]; then
        echo "$(date): analysing $SITE_NAME"
        {
            echo -e "\nTop 5 IP addresses with most requests:"
            awk 'NF > 2 {print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -n 5 | awk '{printf "%s - %s requests\n", $2, $1}'

            echo -e "\nTop 5 response status codes:"
            awk -F '"' 'NF > 2 {print substr ($3, 2, 3)}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -n 5 | awk '{printf "%s - %s requests\n", $2, $1}'

            echo -e "\nTop 5 most requested paths:"
            sed -E 's/^[^"]*"([^"]*)".*$/\1/' "$LOG_FILE" | awk '{if (NF>1) {print $2} else {print $1} }' | sort |  uniq -c | sort -rn | head -n 5 | awk '{printf "%s - %s requests\n", $2, $1}'

            echo -e "\nTop 5 most requested user agents:"
            sed -E 's/.*"([^"]*)"$/\1/' "$LOG_FILE" | sort |  uniq -c | sort -rn | head -n 5 | awk '{temp=$1; $1 = ""; sub(/^ /, ""); printf "%s - %s requests\n", $0, temp}'
        } > "$REPORT_FILE"

        echo "$(date): sending"
        curl -F "file=@$REPORT_FILE" -F "site=$SITE_NAME" http://192.168.1.180:5000/upload
    else
        echo "$(date): log file $LOG_FILE not exist. Waiting Nginx"
    fi

    echo "$(date): Done.."
    sleep 86400
done
