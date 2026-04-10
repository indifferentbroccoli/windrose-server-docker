#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

SERVER_FILES="/home/steam/server-files"

cd "$SERVER_FILES" || exit

LogAction "Starting Windrose Dedicated Server"

EXEC="$SERVER_FILES/WindroseServer.exe"

if [ ! -f "$EXEC" ]; then
    LogError "Could not find server executable at: $EXEC"
    exit 1
fi

export WINEPREFIX="${HOME}/.wine"
export WINEARCH=win64
export WINEDEBUG=-all

# Wine requires a virtual display
Xvfb :0 -screen 0 1024x768x16 &
export DISPLAY=:0

# Initialize Wine prefix on first run
if [ ! -d "${WINEPREFIX}/drive_c" ]; then
    LogInfo "Initializing Wine prefix (first run, this may take a moment)..."
    wineboot --init 2>/dev/null
fi

LogInfo "Server is starting..."

exec wine "$EXEC" -log
