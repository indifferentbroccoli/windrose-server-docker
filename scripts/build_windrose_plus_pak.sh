#!/bin/bash
# Pre-launch: rebuild the Windrose+ override PAK from config.
# Upstream hash cache at R5/Content/Paks/.windroseplus_build.hash makes
# unchanged-config restarts a no-op in milliseconds.
set -euo pipefail
: "${SERVER_FILES:=/home/steam/server-files}"
BUILD_PS1="$SERVER_FILES/windrose_plus/tools/WindrosePlus-BuildPak.ps1"
if [ ! -f "$BUILD_PS1" ]; then
    echo "build_windrose_plus_pak: $BUILD_PS1 not found — installer did not run" >&2
    exit 1
fi
export TEMP="${TEMP:-/tmp}"
exec pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass \
    -File "$BUILD_PS1" \
    -ServerDir "$SERVER_FILES" \
    -RemoveStalePak
