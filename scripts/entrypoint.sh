#!/bin/bash
set -e

echo "Starting MEGAcmd server..."
mega-cmd-server &
sleep 10

if ! mega-whoami > /dev/null 2>&1; then
    echo "---------------------------------------------------"
    echo "NOTICE: Not logged in."
    echo "Exec into container to login: 'docker exec -it mega-sync bash'"
    echo "Then run: mega-login 'email' 'pass' --auth-code='code'"
    echo "---------------------------------------------------"
else
    echo "Login detected. configuring syncs..."

    for i in {1..10}; do
        VAR_LOCAL="SYNC_LOCAL_$i"
        VAR_REMOTE="SYNC_REMOTE_$i"

        LOCAL_PATH="${!VAR_LOCAL}"
        REMOTE_PATH="${!VAR_REMOTE}"

        if [ -n "$LOCAL_PATH" ] && [ -n "$REMOTE_PATH" ]; then

            if mega-sync | grep -q "$LOCAL_PATH"; then
                echo "[$i] Active: $LOCAL_PATH"
            else
                echo "[$i] Adding: $LOCAL_PATH -> $REMOTE_PATH"

                mega-mkdir -p "$REMOTE_PATH" || true

                mega-sync "$LOCAL_PATH" "$REMOTE_PATH"
            fi
        fi
    done
fi

/monitor.sh &

touch /root/.megaCmd/megacmd.log
tail -f /root/.megaCmd/megacmd.log