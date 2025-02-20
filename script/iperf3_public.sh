#!/bin/bash

# Script Name: iperf3_public.sh
# Description: This script manages iperf3 server instances by terminating any existing ones
#              and starting new instances on specified ports (5200-5209).
# Author: Skyler Ogden
# Revision Date: 2023-10-05

# Function to start iperf3 servers
start_iperf3_servers() {
    for port in {5200..5209}; do
        /usr/bin/sudo -u nobody /usr/bin/iperf3 -s -p "$port" -D >/dev/null 2>&1
    done
}

# Wait for 10 seconds before proceeding
/bin/sleep 10

# Terminate existing iperf3 processes gracefully
/usr/bin/killall iperf3
/bin/sleep 0.1

# Forcefully kill any remaining iperf3 processes
/usr/bin/killall -9 iperf3
/bin/sleep 0.1

# Check if any iperf3 processes are still running
if [ "$(ps -C iperf3 | wc -l)" -eq 1 ]; then
    echo "No iperf3 processes found. Starting new instances..."
    start_iperf3_servers
else
    echo "Existing iperf3 processes are still running. No new instances started."
fi

# End of script
