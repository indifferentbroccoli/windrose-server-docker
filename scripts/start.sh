#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

SERVER_FILES="/home/steam/server-files"

cd "$SERVER_FILES" || exit

LogAction "Starting Windrose Dedicated Server"

SERVER_DESC="$SERVER_FILES/R5/ServerDescription.json"
tr -d '\r' < "$SERVER_DESC" | jq \
    --arg proxy      "0.0.0.0" \
    --arg invite     "${INVITE_CODE}" \
    --arg name       "${SERVER_NAME}" \
    --arg password   "${SERVER_PASSWORD:-}" \
    --argjson maxplayers "${MAX_PLAYERS:-10}" \
    '
    .ServerDescription_Persistent.P2pProxyAddress = $proxy |
    if $invite   != "" then .ServerDescription_Persistent.InviteCode           = $invite   else . end |
    if $name     != "" then .ServerDescription_Persistent.ServerName           = $name     else . end |
    if $password != "" then
        .ServerDescription_Persistent.IsPasswordProtected = true |
        .ServerDescription_Persistent.Password = $password
    else
        .ServerDescription_Persistent.IsPasswordProtected = false
    end |
    .ServerDescription_Persistent.MaxPlayerCount = $maxplayers
    ' > "${SERVER_DESC}.tmp" && mv "${SERVER_DESC}.tmp" "$SERVER_DESC"
LogInfo "Server config patched"

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

# Bootstrap Wine if not already initialized
if [ ! -f "$WINEPREFIX/system.reg" ]; then
    LogInfo "Initializing Wine prefix..."
    xvfb-run --auto-servernum bash -c "winecfg -v win10 >/dev/null 2>&1; wineboot --init >/dev/null 2>&1"
    LogInfo "Wine initialized: $(wine --version)"
fi

# First run: start server briefly to generate ServerDescription.json
if [ ! -f "$SERVER_DESC" ]; then
    LogInfo "First run detected, starting server to generate config files..."
    xvfb-run --auto-servernum wine "$SERVER_EXEC" -log -STDOUT >/dev/null 2>&1 &
    firstrun_pid=$!

    count=0
    while [ ! -f "$SERVER_DESC" ] && [ $count -lt 120 ]; do
        sleep 1
        count=$((count + 1))
    done

    kill "$firstrun_pid" 2>/dev/null
    wait "$firstrun_pid" 2>/dev/null
    wineserver -k 2>/dev/null
    sleep 2
fi

LogInfo "Server is starting..."

exec xvfb-run --auto-servernum wine "$SERVER_EXEC" -log -STDOUT
