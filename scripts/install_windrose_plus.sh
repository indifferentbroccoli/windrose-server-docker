#!/bin/bash
# Runs the upstream WindrosePlus install.ps1 under pwsh, after rewriting
# Windows-style path separators in all shipped .ps1 files so they work on
# Linux. Idempotent via $SERVER_FILES/.windroseplus_version.
#
# Env vars:
#   WINDROSE_PLUS_ENABLED            (default false) — gate
#   WINDROSE_PLUS_VERSION            (default $WINDROSE_PLUS_VERSION_DEFAULT)
#   WINDROSE_PLUS_VERSION_DEFAULT    (set by the Docker image)
#   WINDROSE_PLUS_RCON_PASSWORD      (optional) — seeds windrose_plus.json on first run
#   SERVER_FILES                     (default /home/steam/server-files)
#
# Test/dev hook (unset in production):
#   WINDROSE_PLUS_ZIP_OVERRIDE       — local path to WindrosePlus.zip
set -euo pipefail

: "${WINDROSE_PLUS_ENABLED:=false}"
: "${SERVER_FILES:=/home/steam/server-files}"
: "${WINDROSE_PLUS_VERSION_DEFAULT:=}"
: "${WINDROSE_PLUS_VERSION:=$WINDROSE_PLUS_VERSION_DEFAULT}"

if [ "$WINDROSE_PLUS_ENABLED" != "true" ]; then
    exit 0
fi

if [ -z "$WINDROSE_PLUS_VERSION" ]; then
    echo "install_windrose_plus: WINDROSE_PLUS_VERSION is empty and no default is set" >&2
    exit 1
fi

MARKER="$SERVER_FILES/.windroseplus_version"
if [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "$WINDROSE_PLUS_VERSION" ]; then
    exit 0
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# --- Fetch release zip ---
RELEASE_ZIP=""
if [ -n "${WINDROSE_PLUS_ZIP_OVERRIDE:-}" ]; then
    RELEASE_ZIP="$WINDROSE_PLUS_ZIP_OVERRIDE"
else
    RELEASE_ZIP="$TMPDIR/WindrosePlus.zip"
    curl -fsSL \
        "https://github.com/humangenome/WindrosePlus/releases/download/${WINDROSE_PLUS_VERSION}/WindrosePlus.zip" \
        -o "$RELEASE_ZIP"
fi

# --- Extract release into server-files (mirrors the upstream README instructions) ---
mkdir -p "$SERVER_FILES/R5/Binaries/Win64" "$SERVER_FILES/R5/Content/Paks"
unzip -qo "$RELEASE_ZIP" -d "$SERVER_FILES"

# --- Strip third-party hosting branding from dashboard HTML ---
find "$SERVER_FILES" -name '*.html' -type f | while IFS= read -r f; do
    if grep -q 'survivalservers.com' "$f"; then
        n=$(grep -n 'survivalservers.com' "$f" | cut -d: -f1)
        sed -i "$((n-1)),$((n+1))d" "$f"
    fi
done

# --- Rewrite Windows-style path separators in all upstream .ps1 files ---
# WindrosePlus's scripts use literal `\` in file path strings, which is valid
# on Windows (Join-Path normalises) but fails on Linux pwsh where `\` is just
# another filename character. We replace `\` with `/` only when both sides
# are path-segment chars (alnum, underscore, dot, hyphen), preserving regex
# escapes like `\s`, `\w`, `\n` (those have quotes/non-word chars on one side).
find "$SERVER_FILES" -name '*.ps1' -type f -exec \
    sed -i -E 's#([[:alnum:]_.-])\\([[:alnum:]_.-])#\1/\2#g' {} +

# --- Run install.ps1 natively under pwsh (downloads UE4SS itself) ---
# install.ps1 uses $env:TEMP which Windows always sets but Linux does not;
# export it before invoking so Join-Path calls don't fail on a null path.
export TEMP="${TEMP:-/tmp}"
pushd "$SERVER_FILES" >/dev/null
pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass \
    -File "$SERVER_FILES/install.ps1" \
    -GameDir "$SERVER_FILES"
popd >/dev/null

# --- Symlink the deeply-nested Lua mods dir to a friendly path in server-files ---
# UE4SS hard-codes its mod path at R5/Binaries/Win64/ue4ss/Mods/WindrosePlus/Mods/.
# We redirect it to server-files/windrose_plus_mods/ so users only ever see the
# friendly path alongside their other config files. On first install, the zip
# ships an example-welcome mod in that dir — we migrate it before swapping in
# the symlink.
MODS_FRIENDLY="$SERVER_FILES/windrose_plus_mods"
MODS_REAL="$SERVER_FILES/R5/Binaries/Win64/ue4ss/Mods/WindrosePlus/Mods"
mkdir -p "$MODS_FRIENDLY"
if [ ! -L "$MODS_REAL" ]; then
    if [ -d "$MODS_REAL" ]; then
        cp -R "$MODS_REAL/." "$MODS_FRIENDLY/" 2>/dev/null || true
        rm -rf "$MODS_REAL"
    fi
    mkdir -p "$(dirname "$MODS_REAL")"
    ln -sfn "$MODS_FRIENDLY" "$MODS_REAL"
fi
chown -h steam:steam "$MODS_REAL" 2>/dev/null || true
chown -R steam:steam "$MODS_FRIENDLY" 2>/dev/null || true

# --- Swap tools/bin/{repak,retoc}.exe for Linux shims ---
# WindrosePlus-BuildPak.ps1 invokes these via full path. On Linux pwsh cannot
# exec PE binaries; replacing them with exec shell scripts lets the builder
# run unchanged.
for tool in repak retoc; do
    shim="$SERVER_FILES/windrose_plus/tools/bin/${tool}.exe"
    mkdir -p "$(dirname "$shim")"
    cat > "$shim" <<SHIM
#!/bin/bash
exec /usr/local/bin/${tool} "\$@"
SHIM
    chmod +x "$shim"
done

# --- Wine-shim windrose-heal.exe (dashboard /repair endpoint) ---
# Upstream ships a prebuilt Windows Rust binary with no Linux equivalent
# release. Rather than adding a Rust toolchain to the image to compile it
# (rocksdb pulls in a heavy C++ build), route it through the wine that's
# already installed for the game server. The tool is a headless CLI and
# wine handles Unix path args transparently.
HEAL_EXE="$SERVER_FILES/windrose_plus/tools/windrose-heal/windrose-heal.exe"
if [ -f "$HEAL_EXE" ]; then
    HEAL_REAL="${HEAL_EXE}.real"
    if ! head -c 2 "$HEAL_EXE" 2>/dev/null | grep -q '^#!'; then
        mv -f "$HEAL_EXE" "$HEAL_REAL"
    fi
    cat > "$HEAL_EXE" <<'SHIM'
#!/bin/bash
export WINEDEBUG="${WINEDEBUG:--all}"
exec wine "$(dirname "$0")/windrose-heal.exe.real" "$@"
SHIM
    chmod +x "$HEAL_EXE"
fi

# --- Seed windrose_plus.json on first run ---
CFG="$SERVER_FILES/windrose_plus.json"
if [ ! -f "$CFG" ]; then
    PW="${WINDROSE_PLUS_RCON_PASSWORD:-}"
    if [ -z "$PW" ]; then
        PW=$(head -c 18 /dev/urandom | base64 | tr -d '+/=' | head -c 24)
        echo "Windrose+: generated random RCON password: $PW" >&2
    fi
    jq -n --arg pw "$PW" '{
        "multipliers": {},
        "rcon": { "enabled": true, "password": $pw }
    }' > "$CFG"
    chown steam:steam "$CFG" 2>/dev/null || true
fi

echo "$WINDROSE_PLUS_VERSION" > "$MARKER"
chown steam:steam "$MARKER" 2>/dev/null || true
