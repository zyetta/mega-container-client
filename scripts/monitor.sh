#!/bin/bash

# Gotify Configuration
GOTIFY_URL="${GOTIFY_URL:-}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

send_gotify() {
    local title="$1"
    local message="$2"
    local priority="$3"

    if [ -n "$GOTIFY_URL" ] && [ -n "$GOTIFY_TOKEN" ]; then
        curl -s -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" \
            -F "title=$title" \
            -F "message=$message" \
            -F "priority=$priority" > /dev/null
    fi
}

echo "Starting Monitor..."

# Monitor loop
while true; do
    echo "---------------------------------------------------"
    echo "[Monitor] Checking status at $(date)"

    # 1. Check if MEGAcmd server is running
    if ! pgrep -x "mega-cmd-server" > /dev/null; then
        echo "[ERROR] mega-cmd-server is not running!"
        send_gotify "MEGA Sync Error" "mega-cmd-server process is down!" 8
    fi

    # 2. Check Sync Status
    # We print the full status so the user can see what's happening (Synced, Scanning, etc.)
    SYNC_OUTPUT=$(mega-sync)
    echo "[Monitor] Sync Status:"
    echo "$SYNC_OUTPUT"
    
    # Check for errors in the output
    if echo "$SYNC_OUTPUT" | grep -qiE "Error|Failed|Suspended"; then
        echo "[ERROR] Sync issue detected!"
        send_gotify "MEGA Sync Issue" "Sync status contains errors:\n$SYNC_OUTPUT" 5
    fi

    # 3. Log Transactions
    # mega-transfers shows active transfers.
    TRANSFERS=$(mega-transfers)
    if [ -n "$TRANSFERS" ]; then
        echo "[Monitor] Active Transfers:"
        echo "$TRANSFERS"
    else
        echo "[Monitor] No active transfers."
    fi

    echo "---------------------------------------------------"
    sleep 60
done