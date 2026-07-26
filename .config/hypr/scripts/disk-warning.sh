#!/usr/bin/env bash
THRESHOLD_GB=10
avail=$(df / --output=avail -BG | tail -1 | tr -d ' G')
if [ "$avail" -lt "$THRESHOLD_GB" ]; then
  notify-send -u critical -i drive-harddisk \
    "Disk Space Warning" \
    "Only ${avail}GB free on / (threshold: ${THRESHOLD_GB}GB)"
fi
