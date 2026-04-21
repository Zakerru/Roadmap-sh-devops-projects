#!/bin/bash
export LC_ALL=C

RED='\033[0;31m'
NC='\033[0m'

INFO_GATHERING() {

TOP_DATA=$(top -b -n 1 -w 512 2>/dev/null || top -b -n 1)

OS_VERSION=$(source /etc/os-release && echo $PRETTY_NAME)

UP_S=$(uptime -s)
UP_P=$( uptime )

CORE_VERSION=$(uname -r)

DISK=$(df -hP | awk 'BEGIN { printf "%-30s %-20s %-20s %-20s %-20s\n", "Name", "Size", "Used", "Available", "Usage%" } $1 ~ /^\/dev\// { printf "%-30s %-20s %-20s %-20s %-20s\n", $1, $2, $3, $4, $5 }')

TTL_CPU=$( echo "$TOP_DATA" | awk '/id/ || /idle/ {for(i=1; i<=NF; i++) {if ($i ~ /^id/) {val=$(i-1); sub(/%/, "", val); sub(/,/, ".", val); print 100-val; exit}}}' )

MEM_FREE=$(cat /proc/meminfo | awk '/^MemFree:/ || /^Buffers:/ || /^Cached:/ {x=x+$2} END {print x}')
MEM_TOTAL=$(cat /proc/meminfo | awk '/MemTotal:/ {print $2}')
MEM_USED=$((MEM_TOTAL - MEM_FREE))
TTL_MEM=$((MEM_USED * 100 / MEM_TOTAL))

MEM_TOP=$(echo "$TOP_DATA" | awk -v tot="$MEM_TOTAL" '
$1 == "PID" || $2 == "PID" {
    str = NR
    for(i=1; i<=NF; i++) {
        if ($i ~ /STAT|S/) s = i;
        if ($i == "%MEM") { mem_col = i; is_pct = 1; }
        else if ($i == "VSZ" && is_pct != 1) { mem_col = i; is_pct = 0; }
        if ($i ~ /COMMAND/) comm_col = i;
    }
}

NR > str && str != "" {
    offset = (NF < comm_col ? s - 1 : 0);
    val = $(mem_col - offset);
    cmd = ""; for(i=(comm_col - offset); i<=NF; i++) cmd = cmd $i " ";

    sub(/%/, "", val);

    if (is_pct == 0) {
        # Обработка суффиксов m/g (если есть)
        mult=1;
        if(val ~ /[mM]/) mult=1024;
        if(val ~ /[gG]/) mult=1024*1024;
        sub(/[mMgGkK]/, "", val);
        val = (val * mult / tot) * 100;
    }

    if (val > 0 || is_pct) printf "%.1f %s\n", val, cmd
}' | sort -k 1 -rn | head -n 5 | awk '{v=$1; $1=""; sub(/^ /, ""); n=substr($0,1,97); printf "%-100s%.1f%%\n", n, v}' | { printf "%-100s%s\n" "NAME" "%MEM"; cat; })
CPU_TOP=$( echo "$TOP_DATA" | awk '
$1 == "PID" {
    str = NR
    ideal = NF
    for(i=1; i<=NF; i++) {
        if ($i == "S" || $i == "STAT") s = i
        else if ($i == "%CPU" ) cpu = i
        else if ($i == "COMMAND") comm = i
    }
}
NR > str && str != "" {
    cmd = ""
    if (NF != ideal) {
        for(x=1; x<=NF; x++) {
            if($x ~ /^[RDSTZIp][<+NLslW]*$/) {
                for(y = x - s + comm; y <= NF; y++) {
                    cmd = cmd $y " "
                }
                cpu_val = $(x - s + cpu)
                sub(/%/, "", cpu_val)
                print cpu_val, cmd
                break
            }
        }
    } else {
        cpu_val = $cpu
        sub(/%/, "", cpu_val)
        print cpu_val, $comm
    }
}' | sort -k1 -r -n | head -n 5 | awk '{ temp = $1; $1 = ""; sub(/^ /, "");  name = substr($0,1,97); printf "%-100s%.1f%s\n", name, temp, "%" }' | { printf "%-100s%s\n" "NAME" "%CPU"; cat; }  )


if [ "$TTL_MEM" -gt 85 ]; then
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
	usage_num="${usage%\%}"
	if [ "$usage_num" -gt 80 ] 2>/dev/null; then
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
