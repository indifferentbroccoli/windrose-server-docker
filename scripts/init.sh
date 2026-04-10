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
        kill -SIGTERM "$(pgrep -f WindroseServer.exe)"
    fi
    tail --pid="$killpid" -f 2>/dev/null
}

trap 'term_handler' SIGTERM

# Start the server as steam user
su - steam -c "cd /home/steam/server && \
    ./start.sh" &

killpid="$!"
wait "$killpid"
