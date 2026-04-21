#!/bin/bash
script_dir=$(dirname "$(readlink -f "$0")")
config_file="$script_dir/config.conf"

if [ -f "$config_file" ]; then
	source "$config_file"
else
	echo "Config file not found"
	exit 1
fi

free_space=$(df -Pk "$in_dir" | awk 'NR==2 {print $4}')
log_path="$in_dir/log_$(date "+%Y-%m-%d").log"

laggerHiAlc() {
	echo "[$(date "+%H:%M:%S")] $1"
	echo "[$(date "+%H:%M:%S")] $1" >> "$log_path"
	if [ -n "$2" ]; then
		echo "exit code: $2" >> "$log_path"
		exit "$2"
	fi
}

if ! mountpoint -q "$(dirname "$out_dir")"; then
    laggerHiAlc "disk is not mounted" 1

fi

fileslist=$(find "$out_dir" -type f -mtime +"$file_age")

if [ -z "$fileslist" ]; then
	laggerHiAlc "no old files detected"
else
	free_space=$(df -Pk "$in_dir" | awk 'NR==2 {print $4}')
	need_space=$(echo "$fileslist" | xargs -d '\n' du -sk | awk '{summ+=$1} END {print summ}')

	if [ "$free_space" -lt $((need_space*2)) ]; then
        	fsh=$(echo "$free_space" | numfmt --to=iec --suffix=B)
        	nsh=$(echo "$need_space" | numfmt --to=iec --suffix=B)
        	laggerHiAlc "Not enougth space, have:$fsh; need:$nsh" 1
	fi

	mkdir -p "$in_dir/temp"
	archive_dir="$in_dir/temp"
	echo "$fileslist" | while read -r file; do
		mv "$file" "$archive_dir"
	done

	tar czf "$in_dir/$(date "+%Y-%m-%d")".tar.gz -C "$in_dir" temp && rm -rf "$archive_dir"
	laggerHiAlc "old files was archivated"

fi

arcslist=$(find "$in_dir" -name "*.tar.gz" -mtime +"$arch_age")

if [ -z "$arcslist" ]; then
	laggerHiAlc "no old archives detected" 0
else
	echo "$arcslist" | while read -r file1; do
		rm "$file1"
	done
	laggerHiAlc "old archives was removed" 0
fi
laggerHiAlc "that should not be possible" 1
