#!/bin/bash
set -e

# -----------------------------------------------------------------------------------------
# 1. MACHINE ID PERSISTENCE (THE FIX)
# -----------------------------------------------------------------------------------------
# Docker generates a new /etc/machine-id on every boot.
# MEGA uses this to identify the "Device". We must make it static.
if [ ! -f /root/.megaCmd/machine-id ]; then
    echo "Generating new persistent Machine ID..."
    dbus-uuidgen > /root/.megaCmd/machine-id
fi

# Overwrite the container's ephemeral ID with our persistent one
cp /root/.megaCmd/machine-id /etc/machine-id
echo "Machine ID restored: $(cat /etc/machine-id)"

# -----------------------------------------------------------------------------------------
# 2. CLEANUP STALE LOCKS
# -----------------------------------------------------------------------------------------
rm -f /root/.megaCmd/megacmd.socket
rm -f /root/.megaCmd/megacmd.lock

# -----------------------------------------------------------------------------------------
# 3. START SERVER
# -----------------------------------------------------------------------------------------
echo "Starting MEGAcmd server..."
mega-cmd-server &
SERVER_PID=$!

# -----------------------------------------------------------------------------------------
# 4. WAIT FOR LOGIN
# -----------------------------------------------------------------------------------------
echo "Waiting for MEGAcmd server to initialize..."

for i in {1..60}; do
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        echo "[CRITICAL] Server process died. Exiting."
        exit 1
    fi

    STATUS=$(mega-whoami 2>&1 || true)

    if echo "$STATUS" | grep -q "@"; then
        echo "Server ready (Logged in)."
        break
    fi
    sleep 1
done

# -----------------------------------------------------------------------------------------
# 5. SYNC CONFIGURATION
# -----------------------------------------------------------------------------------------
STATUS=$(mega-whoami 2>&1 || true)

if echo "$STATUS" | grep -q "Not logged in"; then
    echo "NOTICE: Not logged in. Please login interactively."
else
    echo "Login detected. Configuring syncs..."
    for i in {1..10}; do
        VAR_LOCAL="SYNC_LOCAL_$i"
        VAR_REMOTE="SYNC_REMOTE_$i"
        LOCAL_PATH="${!VAR_LOCAL}"
        REMOTE_PATH="${!VAR_REMOTE}"

        if [ -n "$LOCAL_PATH" ] && [ -n "$REMOTE_PATH" ]; then
            if mega-sync | grep -q "$LOCAL_PATH"; then
                echo "[$i] Skipped: $LOCAL_PATH is already active."
            else
                echo "[$i] Configuring: $LOCAL_PATH -> $REMOTE_PATH"
                mega-mkdir -p "$REMOTE_PATH" > /dev/null 2>&1 || true
                mega-sync "$LOCAL_PATH" "$REMOTE_PATH" || echo "    -> Warning: Failed to add sync."
            fi
        fi
    done
fi

touch /root/.megaCmd/megacmd.log
tail -f /root/.megaCmd/megacmd.log