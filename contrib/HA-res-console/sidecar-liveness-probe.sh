#!/bin/sh

# Fail if /tmp/heartbeat does not exist or is older than 1 min

if [ -f /tmp/heartbeat ]; then
    file_time=$(stat -c %Y /tmp/heartbeat 2>/dev/null || stat -f %m /tmp/heartbeat)
    current_time=$(date +%s)
    age=$((current_time - file_time))
    if [ $age -lt 60 ]; then
        exit 0
    fi
fi
exit 1
