#!/bin/bash
# Installs UE4SS (experimental-latest) into the game's Win64 folder.
set -euo pipefail

: "${SERVER_FILES:=/home/steam/server-files}"

WIN64="$SERVER_FILES/R5/Binaries/Win64"
UE4SS_DIR="$WIN64/ue4ss"

if [ -f "$WIN64/dwmapi.dll" ] && [ -f "$UE4SS_DIR/UE4SS.dll" ]; then
    exit 0
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Find the asset URL — mirrors install.ps1: name matches ^UE4SS_v, not DEV
ASSET_URL=$(curl -fsSL \
    "https://api.github.com/repos/UE4SS-RE/RE-UE4SS/releases/tags/experimental-latest" | \
    jq -r '[.assets[] | select(.name | test("^UE4SS_v") and (test("DEV") | not))] | first | .browser_download_url')

if [ -z "$ASSET_URL" ] || [ "$ASSET_URL" = "null" ]; then
    echo "install_ue4ss: could not find UE4SS zip in experimental-latest release" >&2
    exit 1
fi

curl -fsSL "$ASSET_URL" -o "$TMPDIR/UE4SS.zip"
unzip -qo "$TMPDIR/UE4SS.zip" -d "$TMPDIR/extract"

mkdir -p "$WIN64" "$UE4SS_DIR"
cp "$TMPDIR/extract/dwmapi.dll" "$WIN64/"
if [ -d "$TMPDIR/extract/ue4ss" ]; then
    cp -R "$TMPDIR/extract/ue4ss/." "$UE4SS_DIR/"
fi
chown -R steam:steam "$WIN64" 2>/dev/null || true
