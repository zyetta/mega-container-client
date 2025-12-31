#!/bin/bash

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

while true; do
    # 1. Check if MEGAcmd server is running
    if ! pgrep -x "mega-cmd-server" > /dev/null; then
        echo "[ERROR] mega-cmd-server is not running!"
        send_gotify "MEGA Sync Error" "mega-cmd-server process is down!" 8
    fi

    # 2. Check Sync Status
    SYNC_STATUS=$(mega-sync)
    
    if echo "$SYNC_STATUS" | grep -qiE "Error|Failed|Suspended"; then
        echo "[ERROR] Sync issue detected:"
        echo "$SYNC_STATUS"
        send_gotify "MEGA Sync Issue" "Sync status contains errors:\n$SYNC_STATUS" 5
    fi

    # 3. Log Transactions
    TRANSFERS=$(mega-transfers)
    if [ -n "$TRANSFERS" ]; then
        echo "[INFO] Active Transfers:"
        echo "$TRANSFERS"
    fi

    sleep 60
done