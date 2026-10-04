#!/usr/bin/env bash
# Monitor RAM, Swap, and ZRAM usage continuously during CI build and output peak statistics summary upon exit.

LOG_FILE="/tmp/memory_profile.log"
SUMMARY_FILE="/tmp/memory_profile_summary.log"

peak_ram_used_mb=0
peak_swap_used_mb=0
peak_total_used_mb=0

trap 'finish' EXIT SIGINT SIGTERM

finish() {
	trap - EXIT SIGINT SIGTERM
	echo "=== Memory Profiling Peak Statistics ===" | tee "$SUMMARY_FILE"
	echo "Peak RAM Used:   ${peak_ram_used_mb} MB" | tee -a "$SUMMARY_FILE"
	echo "Peak Swap Used:  ${peak_swap_used_mb} MB" | tee -a "$SUMMARY_FILE"
	echo "Peak Total Used: ${peak_total_used_mb} MB" | tee -a "$SUMMARY_FILE"
	echo "=========================================" | tee -a "$SUMMARY_FILE"
	exit 0
}

echo "Timestamp RAM_Used_MB Swap_Used_MB Total_Used_MB" > "$LOG_FILE"

while true; do
	mem_info=$(free -m)
	ram_used=$(echo "$mem_info" | awk '/^Mem:/ {print $3}')
	swap_used=$(echo "$mem_info" | awk '/^Swap:/ {print $3}')

	if [[ -n "$ram_used" && -n "$swap_used" ]]; then
		total_used=$((ram_used + swap_used))
		timestamp=$(date +%s)
		echo "$timestamp $ram_used $swap_used $total_used" >> "$LOG_FILE"

		(( ram_used > peak_ram_used_mb )) && peak_ram_used_mb=$ram_used
		(( swap_used > peak_swap_used_mb )) && peak_swap_used_mb=$swap_used
		(( total_used > peak_total_used_mb )) && peak_total_used_mb=$total_used
	fi
	sleep 2
done
