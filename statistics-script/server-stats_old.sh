#!/bin/bash
export LC_ALL=C

RED='\033[0;31m'
NC='\033[0m'

INFO_GATHERING() {

TOP_DATA=$(top -E=k -b -n 1 -w 512)

OS_VERSION=$(source /etc/os-release && echo $PRETTY_NAME)

UP_P=$(uptime -p)
UP_S=$(uptime -s)

CORE_VERSION=$(uname -r)
DISK=$(df -h | awk 'BEGIN { print "Name Size Used Available Usage%" } $1 ~ /^\/dev\// { print $1, $2, $3, $4, $5 }' | column -t)

TTL_CPU=$(echo "$TOP_DATA" | awk '/%Cpu\(s\)/ {x = 100 - $8; if (x >= 80) printf "\033[0;31m%.1f", x; else printf "%.1f", x}')

MEM_FREE=$(echo "$TOP_DATA" | awk '/KiB Mem/ {print $6}')
MEM_USED=$(echo "$TOP_DATA" | awk '/KiB Mem/ {print $8}')
MEM_TOTAL=$(echo "$TOP_DATA" | awk '/KiB Mem/ {print $4}')

TTL_MEM=$(echo "scale=2; $MEM_USED / $MEM_TOTAL * 100" | bc -l)

MEM_TOP=$(echo "$TOP_DATA" | awk '
$1 == "PID" {
    str = NR
    ideal = NF
    for(i=1; i<=NF; i++) {
        if ($i == "S") s = i
        else if ($i == "%MEM") mem = i
        else if ($i == "COMMAND") comm = i
}
}

NR > str && str != "" {
    cmd = "" 
    if (NF != ideal) {
        for(x=1; x<=NF; x++) {
            if($x ~ /^[RDSTZIp]$/) {
                for(y = x - s + comm; y <= NF; y++) {
                    cmd = cmd $y " "
}
                mem_val = $(x - s + mem)
                print mem_val, cmd
                break 
}
}
} else print $mem, $comm
}' | sort -k 1 -r -n | head -n 5 | awk '{ temp = $1; $1 = ""; sub(/^ /, ""); print $0 "|" temp "%" }' | { echo "NAME|%MEM"; cat; } | column -s '|' -t)
CPU_TOP=$(ps -eo %cpu,comm:512 | awk ' NR>1 {print $0 | "sort -k1 -r -n"}' | awk '{ temp = $1; $1 = ""; sub(/^ /, ""); print $0 "|" temp "%" }' | head -n 5 | { echo "NAME|%CPU"; cat; } | column -s '|' -t)


if [ "$(echo "$TTL_MEM >= 85" | bc -l)" -eq 1 ]; then
	MEM_COLOR="$RED"
else
	MEM_COLOR="$NC"
fi

echo "Disks usage:"
echo "$DISK" | while read -r; do
	name="${REPLY%% *}"
	if [ "$name" = "Name" ]; then
		printf "%s\n" "$REPLY"
		continue
	fi
	usage="${REPLY##* }"
	if [ "${usage%?}" -gt 80 ]; then
		VAL_COLOR="$RED"
	else
    		VAL_COLOR="$NC"
	fi
COLORED_VAL="$VAL_COLOR$usage$NC"
printf "%b\n" "${REPLY/%$usage/$COLORED_VAL}"
done

printf "\nTotal CPU usage:%b%%%b\n" "$TTL_CPU" "$NC"
printf "\nMemory usage:\n free:%s KiB\n used:%s KiB\n Total usage:%b%s%%%b\n" "$MEM_FREE" "$MEM_USED" "$MEM_COLOR" "$TTL_MEM" "$NC"

printf "\nTop 5 processes for CPU usage:\n%s\n" "$CPU_TOP"
printf "\nTop 5 processes for Memory usage:\n%s\n" "$MEM_TOP"

printf "\nOS version: %s\n" "$OS_VERSION"
printf "Core version: %s\n" "$CORE_VERSION"

printf "\nSystem started on: %s\n" "$UP_S"
printf "Uptime: %s\n" "$UP_P"
}
while true; do

if [ "$1" = "-m" ]; then
    clear
fi

INFO_GATHERING

if [ "$1" = "-m" ]; then
    sleep 2
else
    break
fi
done
