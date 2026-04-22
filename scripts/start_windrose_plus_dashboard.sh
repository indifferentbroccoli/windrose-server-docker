#!/bin/bash
# Run the Windrose+ PowerShell dashboard (HTTP server) in the foreground.
# Caller should fork this into the background — dashboard failure must not
# kill the game server.
set -euo pipefail
: "${SERVER_FILES:=/home/steam/server-files}"
: "${WINDROSE_PLUS_DASHBOARD_PORT:=8780}"
DASH_PS1="$SERVER_FILES/windrose_plus/server/windrose_plus_server.ps1"
if [ ! -f "$DASH_PS1" ]; then
    echo "dashboard: $DASH_PS1 not found" >&2
    exit 1
fi
export TEMP="${TEMP:-/tmp}"
exec pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass \
    -File "$DASH_PS1" \
    -GameDir "$SERVER_FILES" \
    -Port "$WINDROSE_PLUS_DASHBOARD_PORT"
