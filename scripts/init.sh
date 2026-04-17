#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

LogAction "Set file permissions"

if [ -z "${PUID}" ] || [ -z "${PGID}" ]; then
    LogError "PUID and PGID not set. Please set these in the environment variables."
    exit 1
else
    usermod -o -u "${PUID}" steam
    groupmod -o -g "${PGID}" steam
fi

chown -R steam:steam /home/steam/

cat /branding

if [ "${UPDATE_ON_START:-true}" = "true" ]; then
    install
else
    LogWarn "UPDATE_ON_START is set to false, skipping server update"
fi

chown -R steam:steam /home/steam/server-files

# shellcheck disable=SC2317
term_handler() {
    if ! shutdown_server; then
        local pid
        pid=$(pgrep -f "wineserver64" | head -1)
        if [ -n "$pid" ]; then
            kill -SIGTERM "$pid"
        fi
    fi
    sleep 2
    tail --pid="$killpid" -f 2>/dev/null
}

trap 'term_handler' SIGTERM

export INVITE_CODE="${INVITE_CODE:-}"
export SERVER_NAME="${SERVER_NAME:-}"
export SERVER_PASSWORD="${SERVER_PASSWORD:-}"
export MAX_PLAYERS="${MAX_PLAYERS:-10}"
export P2P_PROXY_ADDRESS="${P2P_PROXY_ADDRESS:-}"
export GENERATE_SETTINGS="${GENERATE_SETTINGS:-true}"

# Start the server as steam user
su - steam -w "INVITE_CODE,SERVER_NAME,SERVER_PASSWORD,MAX_PLAYERS,P2P_PROXY_ADDRESS,GENERATE_SETTINGS" \
    -c "cd /home/steam/server && ./start.sh" &

killpid="$!"
wait "$killpid"
