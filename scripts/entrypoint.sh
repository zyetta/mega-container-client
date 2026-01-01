#!/bin/bash
set -e

# -----------------------------------------------------------------------------------------
# USER & PERMISSIONS SETUP
# -----------------------------------------------------------------------------------------
PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "[Init] Setting up user with PUID=$PUID and PGID=$PGID"

# Create group if it doesn't exist
if ! getent group mega > /dev/null 2>&1; then
    groupadd -g "$PGID" mega
fi

# Create user if it doesn't exist
if ! id -u mega > /dev/null 2>&1; then
    useradd -u "$PUID" -g "$PGID" -m -d /app/config mega
fi

# Ensure permissions
chown -R mega:mega /app

# Define config directory
CONFIG_DIR="/app/config/.megaCmd"
mkdir -p "$CONFIG_DIR"
chown -R mega:mega /app/config

# -----------------------------------------------------------------------------------------
# SOCKET CLEANUP
# -----------------------------------------------------------------------------------------
if [ -e "$CONFIG_DIR/megacmd.socket" ]; then
    echo "[Init] Removing stale socket file..."
    rm -f "$CONFIG_DIR/megacmd.socket"
fi

if [ -e "$CONFIG_DIR/megacmd.lock" ]; then
    echo "[Init] Removing stale lock file..."
    rm -f "$CONFIG_DIR/megacmd.lock"
fi

# -----------------------------------------------------------------------------------------
# START SERVER (AS USER)
# -----------------------------------------------------------------------------------------
echo "Starting MEGAcmd server as user 'mega'..."
gosu mega mega-cmd-server &
SERVER_PID=$!

# -----------------------------------------------------------------------------------------
# START WEB UI (AS USER)
# -----------------------------------------------------------------------------------------
echo "Starting Web UI on port 8888..."
gosu mega python3 /app/server.py &

# -----------------------------------------------------------------------------------------
# SYNC WATCHDOG FUNCTION
# -----------------------------------------------------------------------------------------
sync_watchdog() {
    echo "[Watchdog] Starting Sync Watchdog..."
    
    # Initial delay to let server start
    sleep 10
    
    while true; do
        # Check if server is running
        if ! kill -0 $SERVER_PID 2>/dev/null; then
            echo "[Watchdog] Server process died. Exiting watchdog."
            exit 1
        fi

        # Check Login Status (run as user)
        STATUS=$(gosu mega mega-whoami 2>&1 || true)
        
        if echo "$STATUS" | grep -q "Not logged in"; then
            echo "[Watchdog] Not logged in. Waiting for user to login via Web UI..."
        elif [[ "$STATUS" == *"Unable to connect"* ]]; then
            echo "[Watchdog] Server not ready yet..."
        else
            # Logged In - Check Syncs
            for i in {1..10}; do
                VAR_LOCAL="SYNC_LOCAL_$i"
                VAR_REMOTE="SYNC_REMOTE_$i"

                LOCAL_PATH="${!VAR_LOCAL}"
                REMOTE_PATH="${!VAR_REMOTE}"

                if [ -n "$LOCAL_PATH" ] && [ -n "$REMOTE_PATH" ]; then
                    # Check if sync is already active
                    if gosu mega mega-sync | grep -q "$LOCAL_PATH"; then
                        :
                    else
                        echo "[Watchdog] Sync missing for [$i]. Configuring: $LOCAL_PATH -> $REMOTE_PATH"
                        
                        gosu mega mega-mkdir -p "$REMOTE_PATH" || true

                        if ! OUTPUT=$(gosu mega mega-sync "$LOCAL_PATH" "$REMOTE_PATH" 2>&1); then
                            echo "[Watchdog] Failed to add sync: $OUTPUT"
                            
                            if echo "$OUTPUT" | grep -q "Unable to retrieve the ID of current device"; then
                                echo "[CRITICAL] Session corrupted. Resetting session..."
                                rm -f "$CONFIG_DIR/session"
                                kill $SERVER_PID
                                exit 1
                            fi
                        else
                            echo "[Watchdog] Sync configured successfully."
                        fi
                    fi
                fi
            done
        fi
        
        sleep 30
    done
}

# -----------------------------------------------------------------------------------------
# START BACKGROUND PROCESSES
# -----------------------------------------------------------------------------------------

# Start the sync watchdog in background
sync_watchdog &

# Start the monitor script in background (run as user)
gosu mega /app/monitor.sh &

# -----------------------------------------------------------------------------------------
# MAIN LOG LOOP
# -----------------------------------------------------------------------------------------
touch "$CONFIG_DIR/megacmd.log"
chown mega:mega "$CONFIG_DIR/megacmd.log"
tail -f "$CONFIG_DIR/megacmd.log"