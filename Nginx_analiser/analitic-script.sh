#!/bin/bash

LOG_FILE="/nginx-access.log" # add your path to log file directory before /nginx-access.log

echo -e "\nTop 5 IP addresses with most requests:"
awk 'NF > 2 {print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -n 5 | awk '{printf "%s - %s requests\n", $2, $1}'

echo -e "\nTop 5 response status codes:"
awk -F '"' 'NF > 2 {print substr ($3, 2, 3)}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -n 5 | awk '{printf "%s - %s requests\n", $2, $1}'

echo -e "\nTop 5 most requested paths:"
sed -E 's/^[^"]*"([^"]*)".*$/\1/' "$LOG_FILE" | awk '{if (NF>1) {print $2} else {print $1} }' | sort |  uniq -c | sort -rn | head -n 5 | awk '{printf "%s - %s requests\n", $2, $1}'

echo -e "\nTop 5 most requested user agents:"
sed -E 's/.*"([^"]*)"$/\1/' "$LOG_FILE" | sort |  uniq -c | sort -rn | head -n 5 | awk '{temp=$1; $1 = ""; sub(/^ /, ""); printf "%s - %s requests\n", $0, temp}'
