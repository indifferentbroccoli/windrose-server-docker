#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

SERVER_FILES="/home/steam/server-files"

cd "$SERVER_FILES" || exit

LogAction "Starting Windrose Dedicated Server"

SERVER_DESC="$SERVER_FILES/R5/ServerDescription.json"

SERVER_EXEC="$SERVER_FILES/R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe"

if [ ! -f "$SERVER_EXEC" ]; then
    LogError "Could not find server executable at: $SERVER_EXEC"
    LogError "Directory contents:"
    ls -laR "$SERVER_FILES/"
    exit 1
fi

export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
export WINEARCH="${WINEARCH:-win64}"
export WINEDEBUG="${WINEDEBUG:-fixme-all}"
export WINEDLLOVERRIDES="mscoree,mshtml="

# First run: start server briefly to generate ServerDescription.json
if [ "${GENERATE_SETTINGS:-true}" = "false" ]; then
    LogInfo "GENERATE_SETTINGS=false — skipping first boot detection and config patch"
elif [ ! -f "$SERVER_DESC" ]; then
    LogAction "First boot detected - ServerDescription.json not found"
    LogInfo "Starting server temporarily to generate default config files..."

    xvfb-run --auto-servernum wine "$SERVER_EXEC" -log -STDOUT >/dev/null 2>&1 &
    firstrun_pid=$!

    count=0
    while [ ! -f "$SERVER_DESC" ] && [ $count -lt 120 ]; do
        sleep 1
        count=$((count + 1))
    done

    if [ ! -f "$SERVER_DESC" ]; then
        LogError "ServerDescription.json was not generated after ${count}s - server may have failed to start"
        LogError "Killing temporary process and exiting"
        kill "$firstrun_pid" 2>/dev/null
        wait "$firstrun_pid" 2>/dev/null
        wineserver -k 2>/dev/null
        exit 1
    fi

    LogSuccess "ServerDescription.json generated!"
    kill "$firstrun_pid" 2>/dev/null
    wait "$firstrun_pid" 2>/dev/null
    wineserver -k 2>/dev/null
    sleep 2
fi

if [ "${GENERATE_SETTINGS:-true}" != "false" ]; then
    LogAction "Patching server config"
    tr -d '\r' < "$SERVER_DESC" | jq \
        --arg proxy            "${P2P_PROXY_ADDRESS:-127.0.0.1}" \
        --arg invite           "${INVITE_CODE}" \
        --argjson directconn   "${USE_DIRECT_CONNECTION:-false}" \
        --argjson serverport   "${SERVER_PORT:-7777}" \
        --arg dcproxy          "${DIRECT_CONNECTION_PROXY_ADDRESS:-0.0.0.0}" \
        --arg region           "${USER_SELECTED_REGION:-EU}" \
        --arg name             "${SERVER_NAME}" \
        --arg password         "${SERVER_PASSWORD:-}" \
        --argjson maxplayers   "${MAX_PLAYERS:-10}" \
        '
        .ServerDescription_Persistent.P2pProxyAddress = $proxy |
        if $invite != "" then .ServerDescription_Persistent.InviteCode = $invite else . end |
        .ServerDescription_Persistent.UseDirectConnection = $directconn |
        .ServerDescription_Persistent.DirectConnectionServerPort = $serverport |
        .ServerDescription_Persistent.DirectConnectionProxyAddress = $dcproxy |
        if $region != "" then .ServerDescription_Persistent.UserSelectedRegion = $region else . end |
        if $name     != "" then .ServerDescription_Persistent.ServerName           = $name     else . end |
        if $password != "" then
            .ServerDescription_Persistent.IsPasswordProtected = true |
            .ServerDescription_Persistent.Password = $password
        else
            .ServerDescription_Persistent.IsPasswordProtected = false |
            .ServerDescription_Persistent.Password = ""
        end |
        .ServerDescription_Persistent.MaxPlayerCount = $maxplayers
        ' > "${SERVER_DESC}.tmp" && mv "${SERVER_DESC}.tmp" "$SERVER_DESC"
    LogSuccess "Server config patched"
fi

LogInfo "Server is starting..."

LOG_FILE="$SERVER_FILES/R5/Saved/Logs/R5.log"

xvfb-run --auto-servernum wine "$SERVER_EXEC" -log >/dev/null 2>&1 &
wine_pid=$!

tail -F "$LOG_FILE" 2>/dev/null &

wait $wine_pid
