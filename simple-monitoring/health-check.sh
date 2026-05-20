#!/bin/bash

URL="https://zakerru.github.io/Roadmap-sh-devops-projects/"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" --connect-timeout 10 "$URL")

CURLCODE=$(echo $RESPONSE | cut -d' ' -f1)
CURLTIME=$(echo $RESPONSE | cut -d' ' -f2)

THRESHOLD=3.0

if [ "$CURLCODE" -ne 200 ]; then
    MSG="Сайт $URL лежит. Код ошибки: $CURLCODE"

    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
         -d chat_id="${TG_CODE}" -d text="${MSG}"

    curl -s -H "Content-Type: application/json" -X POST \
         -d "{\"content\": \"$MSG\"}" "${DS_WEBHOOK}"
    exit 1
fi

if (( $(echo "$CURLTIME > $THRESHOLD" | bc -l) )); then
    MSG="Сайт тормозит. Время ответа: ${CURLTIME}s"

    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
         -d chat_id="${TG_CODE}" -d text="${MSG}"
    exit 1
fi
