#!/bin/bash
set -e

# -----------------------------------------------------------------------------------------
# 1. MACHINE ID PERSISTENCE (CRITICAL FIX)
# -----------------------------------------------------------------------------------------
# Ensure the folder exists
mkdir -p /root/.megaCmd

# If we don't have a stored ID, generate one using uuidgen
if [ ! -f /root/.megaCmd/machine-id ]; then
    echo "[Init] Generating new persistent Machine ID..."
    uuidgen > /root/.megaCmd/machine-id
fi

# Apply the stored ID to the system so MEGA sees the "same computer"
cp /root/.megaCmd/machine-id /etc/machine-id
echo "[Init] Machine ID restored: $(cat /etc/machine-id)"

# -----------------------------------------------------------------------------------------
# 2. SOCKET CLEANUP
# -----------------------------------------------------------------------------------------
if [ -e /root/.megaCmd/megacmd.socket ]; then
    echo "[Init] Removing stale socket file..."
    rm -f /root/.megaCmd/megacmd.socket
fi

if [ -e /root/.megaCmd/megacmd.lock ]; then
    echo "[Init] Removing stale lock file..."
    rm -f /root/.megaCmd/megacmd.lock
fi

# -----------------------------------------------------------------------------------------
# 3. START SERVER
# -----------------------------------------------------------------------------------------
echo "[Init] Starting MEGAcmd server..."
mega-cmd-server &
SERVER_PID=$!

# -----------------------------------------------------------------------------------------
# 4. START WEB UI
# -----------------------------------------------------------------------------------------
echo "[Init] Starting Web UI on port 5000..."
# Ensure you are using the correct port here (5000 matches the python code provided earlier)
python3 /root/server.py &

# -----------------------------------------------------------------------------------------
# 5. SYNC WATCHDOG FUNCTION
# -----------------------------------------------------------------------------------------
sync_watchdog() {
    echo "[Watchdog] Starting Sync Watchdog..."

    # Initial delay to let server start and load session
    sleep 10

    while true; do
        # Check if server is running
        if ! kill -0 $SERVER_PID 2>/dev/null; then
            echo "[Watchdog] Server process died. Exiting."
            exit 1
        fi

        # Check Login Status
        # We use || true to prevent script exit on error code
        STATUS=$(mega-whoami 2>&1 || true)

        if echo "$STATUS" | grep -q "Not logged in"; then
            # Silent wait - the user needs to use the Web UI
            :
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

                    # Check if sync is active.
                    # We check specifically for the local path string in the output
                    if mega-sync | grep -q "$LOCAL_PATH"; then
                        : # Already active
                    else
                        echo "[Watchdog] Configuring: $LOCAL_PATH -> $REMOTE_PATH"

                        # Ensure remote exists (silent fail allowed)
                        mega-mkdir -p "$REMOTE_PATH" > /dev/null 2>&1 || true

                        # Try to add sync
                        if ! OUTPUT=$(mega-sync "$LOCAL_PATH" "$REMOTE_PATH" 2>&1); then
                            # Check for "Already exists" which is not a real failure
                            if echo "$OUTPUT" | grep -q "Folder already exists"; then
                                echo "[Watchdog] Sync relinked (Folder existed)."
                            elif echo "$OUTPUT" | grep -q "Unable to retrieve the ID"; then
                                echo "[CRITICAL] Device ID Mismatch detected."
                                # We DO NOT delete the session here immediately to avoid loops.
                                # The Machine ID fix at the top should prevent this.
                            else
                                echo "[Watchdog] Failed to add sync: $OUTPUT"
                            fi
                        else
                            echo "[Watchdog] Sync added successfully."
                        fi
                    fi
                fi
            done
        fi

        # Check every 60 seconds to be less aggressive
        sleep 60
    done
}

# -----------------------------------------------------------------------------------------
# 6. MAIN LOOP
# -----------------------------------------------------------------------------------------

# Start watchdog in background
sync_watchdog &

# Tail logs to keep container alive and show output
touch /root/.megaCmd/megacmd.log
tail -f /root/.megaCmd/megacmd.log