#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

SERVER_FILES="/home/steam/server-files"

cd "$SERVER_FILES" || exit

LogAction "Starting Windrose Dedicated Server"

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
    winecfg -v win10 >/dev/null 2>&1
    wineboot --init >/dev/null 2>&1
    LogInfo "Wine initialized: $(wine --version)"
fi

LogInfo "Server is starting..."

exec xvfb-run --auto-servernum wine "$SERVER_EXEC" -log -STDOUT
