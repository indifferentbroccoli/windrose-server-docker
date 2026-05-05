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

if [ "${UE4SS_ENABLED:-false}" = "true" ] && [ "${WINDROSE_PLUS_ENABLED:-false}" != "true" ]; then
    LogAction "Installing/updating UE4SS"
    SERVER_FILES=/home/steam/server-files /home/steam/server/install_ue4ss.sh
fi

if [ "${WINDROSE_PLUS_ENABLED:-false}" = "true" ]; then
    LogAction "Installing/updating Windrose+"
    export WINDROSE_PLUS_VERSION="${WINDROSE_PLUS_VERSION:-$WINDROSE_PLUS_VERSION_DEFAULT}"
    export WINDROSE_PLUS_RCON_PASSWORD="${WINDROSE_PLUS_RCON_PASSWORD:-}"
    SERVER_FILES=/home/steam/server-files /home/steam/server/install_windrose_plus.sh
else
    LogInfo "Windrose+ disabled (set WINDROSE_PLUS_ENABLED=true to enable)"
fi

chown -R steam:steam /home/steam/server-files

# shellcheck disable=SC2317
term_handler() {
    if ! shutdown_server; then
        LogWarn "Server did not shutdown gracefully, forcing shutdown"
        su steam -c 'WINEPREFIX=/home/steam/.wine wineserver -k9' >/dev/null 2>&1 || true
        # Anything belonging to steam is part of a dead wine session.
        pkill -9 -u steam 2>/dev/null || true
    fi
    sleep 2
    tail --pid="$killpid" -f /dev/null 2>/dev/null
}

trap 'term_handler' SIGTERM

export INVITE_CODE="${INVITE_CODE:-}"
export USE_DIRECT_CONNECTION="${USE_DIRECT_CONNECTION:-false}"
export SERVER_PORT="${SERVER_PORT:-7777}"
export DIRECT_CONNECTION_PROXY_ADDRESS="${DIRECT_CONNECTION_PROXY_ADDRESS:-0.0.0.0}"
export USER_SELECTED_REGION="${USER_SELECTED_REGION:-}"
export SERVER_NAME="${SERVER_NAME:-}"
export SERVER_PASSWORD="${SERVER_PASSWORD:-}"
export MAX_PLAYERS="${MAX_PLAYERS:-10}"
export P2P_PROXY_ADDRESS="${P2P_PROXY_ADDRESS:-}"
export GENERATE_SETTINGS="${GENERATE_SETTINGS:-true}"
export UE4SS_ENABLED="${UE4SS_ENABLED:-false}"
export WINDROSE_PLUS_ENABLED="${WINDROSE_PLUS_ENABLED:-false}"
export WINDROSE_PLUS_VERSION="${WINDROSE_PLUS_VERSION:-$WINDROSE_PLUS_VERSION_DEFAULT}"
export WINDROSE_PLUS_DASHBOARD_PORT="${WINDROSE_PLUS_DASHBOARD_PORT:-8780}"
export WINDROSE_PLUS_RCON_PASSWORD="${WINDROSE_PLUS_RCON_PASSWORD:-}"
export WINE_VERBOSE="${WINE_VERBOSE:-false}"

# Start the server as steam user
su - steam -w "INVITE_CODE,USE_DIRECT_CONNECTION,SERVER_PORT,DIRECT_CONNECTION_PROXY_ADDRESS,USER_SELECTED_REGION,SERVER_NAME,SERVER_PASSWORD,MAX_PLAYERS,P2P_PROXY_ADDRESS,GENERATE_SETTINGS,UE4SS_ENABLED,WINDROSE_PLUS_ENABLED,WINDROSE_PLUS_VERSION,WINDROSE_PLUS_VERSION_DEFAULT,WINDROSE_PLUS_DASHBOARD_PORT,WINDROSE_PLUS_RCON_PASSWORD,WINE_VERBOSE" \
    -c "cd /home/steam/server && ./start.sh" &

killpid="$!"
wait "$killpid"
