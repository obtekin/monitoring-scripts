#!/bin/bash

# File to store alarm messages
ALARM_LOG="swap_alarm.log"

# Threshold for swap utilization percentage
SWAP_THRESHOLD=5

# Temporary file to track memory usage over time
MEMORY_USAGE_TRACKER="/tmp/memory_usage_tracker.txt"

# Function to calculate swap usage percentage
calculate_swap_usage() {
    free -m | awk '/Swap:/ { if ($2 > 0) print $3 / $2 * 100; else print 0 }'
}

# Function to log alarm with details of processes increasing memory usage
log_alarm() {
    echo "ALARM: Swap utilization exceeded $SWAP_THRESHOLD% at $(date)" >> "$ALARM_LOG"

    # Compare memory usage between snapshots and find processes with increased usage
    echo "Processes with increased memory usage (RSS) in the last 10 minutes:" >> "$ALARM_LOG"
    if [ -f "$MEMORY_USAGE_TRACKER" ]; then
        ps --no-headers -eo pid,comm,rss | awk '{print $1, $2, $3}' > /tmp/current_memory_usage.txt

        # Compare previous and current memory usage
        awk 'NR==FNR {a[$1]=$3; next} {if ($1 in a && $3 > a[$1]) print $2, $3-a[$1] "KB"}' \
            "$MEMORY_USAGE_TRACKER" /tmp/current_memory_usage.txt >> "$ALARM_LOG"
        
        mv /tmp/current_memory_usage.txt "$MEMORY_USAGE_TRACKER"
    else
        ps --no-headers -eo pid,comm,rss > "$MEMORY_USAGE_TRACKER"
    fi
}

# Main monitoring loop
while true; do
    # Get current swap utilization percentage
    SWAP_USAGE=$(calculate_swap_usage)
    SWAP_USAGE_INT=${SWAP_USAGE%.*} # Convert to integer for comparison

    # Check if swap utilization exceeds the threshold
    if [ "$SWAP_USAGE_INT" -gt "$SWAP_THRESHOLD" ]; then
        log_alarm
    fi

    # Wait for 10 minutes before next check
    sleep 600
done
