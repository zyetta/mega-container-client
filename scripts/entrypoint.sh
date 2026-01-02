#!/bin/bash
set -e

# -----------------------------------------------------------------------------------------
# 1. USER & PERMISSIONS SETUP (FIXED)
# -----------------------------------------------------------------------------------------
PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "[Init] Setting up user with PUID=$PUID and PGID=$PGID"

# 1. Handle Group Collision
# Check if a group with the desired GID already exists
if GROUP_NAME=$(getent group "$PGID" | cut -d: -f1); then
    if [ "$GROUP_NAME" != "mega" ]; then
        echo "[Init] GID $PGID is already used by '$GROUP_NAME'. Renaming to 'mega'..."
        groupmod -n mega "$GROUP_NAME"
    fi
else
    # GID is free, create the group if 'mega' doesn't exist
    if ! getent group mega > /dev/null 2>&1; then
        groupadd -g "$PGID" mega
    fi
fi

# 2. Handle User Collision
# Check if a user with the desired UID already exists
if USER_NAME=$(getent passwd "$PUID" | cut -d: -f1); then
    if [ "$USER_NAME" != "mega" ]; then
        echo "[Init] UID $PUID is already used by '$USER_NAME'. Renaming to 'mega'..."
        # Rename user, change home dir, and ensure primary group is set
        usermod -l mega -g "$PGID" -d /app/config -m "$USER_NAME"
    fi
else
    # UID is free, create user if 'mega' doesn't exist
    if ! id -u mega > /dev/null 2>&1; then
        useradd -u "$PUID" -g "$PGID" -m -d /app/config mega
    fi
fi

# Ensure permissions
echo "[Init] Fixing permissions..."
chown -R mega:mega /app

# Define config directory
CONFIG_DIR="/app/config/.megaCmd"
mkdir -p "$CONFIG_DIR"
chown -R mega:mega /app/config

# -----------------------------------------------------------------------------------------
# 2. MACHINE ID PERSISTENCE
# -----------------------------------------------------------------------------------------
# ... (Rest of your script remains exactly the same)
if [ ! -f "$CONFIG_DIR/machine-id" ]; then
    echo "[Init] Generating new persistent Machine ID..."
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen > "$CONFIG_DIR/machine-id"
    else
        cat /proc/sys/kernel/random/uuid > "$CONFIG_DIR/machine-id"
    fi
    chown mega:mega "$CONFIG_DIR/machine-id"
fi

cp "$CONFIG_DIR/machine-id" /etc/machine-id
echo "[Init] Machine ID restored: $(cat /etc/machine-id)"

# -----------------------------------------------------------------------------------------
# 3. SOCKET CLEANUP
# -----------------------------------------------------------------------------------------
rm -f "$CONFIG_DIR/megacmd.socket"
rm -f "$CONFIG_DIR/megacmd.lock"

# -----------------------------------------------------------------------------------------
# 4. START SERVER (AS USER)
# -----------------------------------------------------------------------------------------
echo "Starting MEGAcmd server as user 'mega'..."
gosu mega mega-cmd-server &
SERVER_PID=$!

# -----------------------------------------------------------------------------------------
# 5. START WEB UI (AS USER)
# -----------------------------------------------------------------------------------------
echo "Starting Web UI on port 5000..."
if [ -f /app/server.py ]; then
    gosu mega python3 /app/server.py &
elif [ -f /root/web_server.py ]; then
    cp /root/web_server.py /app/server.py
    chown mega:mega /app/server.py
    gosu mega python3 /app/server.py &
else
    echo "[WARN] Web Server script not found!"
fi

# -----------------------------------------------------------------------------------------
# 6. SYNC WATCHDOG FUNCTION
# -----------------------------------------------------------------------------------------
sync_watchdog() {
    echo "[Watchdog] Starting Sync Watchdog..."
    sleep 15

    while true; do
        if ! kill -0 $SERVER_PID 2>/dev/null; then
            echo "[Watchdog] Server process died. Exiting."
            exit 1
        fi

        STATUS=$(gosu mega mega-whoami 2>&1 || true)

        if echo "$STATUS" | grep -q "Not logged in"; then
            : # Wait for user
        elif [[ "$STATUS" == *"Unable to connect"* ]]; then
            echo "[Watchdog] Server connecting..."
        else
            for i in {1..10}; do
                VAR_LOCAL="SYNC_LOCAL_$i"
                VAR_REMOTE="SYNC_REMOTE_$i"
                LOCAL_PATH="${!VAR_LOCAL}"
                REMOTE_PATH="${!VAR_REMOTE}"

                if [ -n "$LOCAL_PATH" ] && [ -n "$REMOTE_PATH" ]; then
                    if gosu mega mega-sync | grep -Fq "$LOCAL_PATH"; then
                        : # Already active
                    else
                        echo "[Watchdog] Configuring: $LOCAL_PATH -> $REMOTE_PATH"
                        gosu mega mega-mkdir -p "$REMOTE_PATH" > /dev/null 2>&1 || true

                        if ! OUTPUT=$(gosu mega mega-sync "$LOCAL_PATH" "$REMOTE_PATH" 2>&1); then
                            if echo "$OUTPUT" | grep -q "Active sync same path"; then
                                echo "[Watchdog] Verified: Sync already active."
                            elif echo "$OUTPUT" | grep -q "Folder already exists"; then
                                echo "[Watchdog] Verified: Folder linked."
                            elif echo "$OUTPUT" | grep -q "Unable to retrieve the ID"; then
                                echo "[CRITICAL] Device ID Mismatch. Please wipe volume."
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
        sleep 60
    done
}

sync_watchdog &

# Keep container alive
touch "$CONFIG_DIR/megacmd.log"
chown mega:mega "$CONFIG_DIR/megacmd.log"
tail -f "$CONFIG_DIR/megacmd.log"