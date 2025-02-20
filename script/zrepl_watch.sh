#!/bin/bash

# Script Name: zrepl_watch.sh
# Description: This script creates a tmux session to monitor the zrepl service.
#              It splits the window to show the journal logs, ZFS snapshots, and zrepl status.
# Author: Skyler Ogden
# Revision Date: 2023-10-05

# Create a new tmux session named 'zrepl' in detached mode
tmux new -s zrepl -d

# Split the window to show journal logs for the zrepl service
tmux split-window -t zrepl "journalctl -f -u zrepl.service"

# Split the window to show ZFS snapshots
tmux split-window -t zrepl "watch 'zfs list -t snapshot -o name,creation -s creation'"

# Split the window to show zrepl status
tmux split-window -t zrepl "zrepl status"

# Set the layout to tiled
tmux select-layout -t zrepl tiled

# Attach to the tmux session
tmux attach -t zrepl

# End of script
