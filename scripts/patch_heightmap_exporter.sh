#!/bin/bash
# patch_heightmap_exporter.sh — Wine-compat binary patch for HeightmapExporter
#
# The HeightmapExporter DLL (part of WindrosePlus) validates pointers against
# native-Windows address ranges (> 1 TB).  Under Wine the game heap starts at
# ~4 GB, so every heightfield component fails validation and the Sea Chart
# gets no terrain data.
#
# This script patches 16 bytes at 6 known offsets in main.dll:
#   1. isR() bypass          — VirtualQuery check always returns true
#   2–6. vp() threshold fix  — lower bound 1 TB → 64 KB (3 compiler-inlined copies)
#
# Idempotent: safe to re-run on an already-patched file.  If the bytes at any
# offset don't match the expected original *or* patched values, the script
# warns and aborts — it will never corrupt an unknown DLL version.
#
# Usage: patch_heightmap_exporter.sh <path-to-main.dll>
set -euo pipefail

DLL="${1:-}"
if [ -z "$DLL" ] || [ ! -f "$DLL" ]; then
    echo "Usage: $0 <path-to-main.dll>" >&2
    exit 1
fi

# patch_bytes <offset_hex> <expected_hex> <new_hex> <label>
patch_bytes() {
    local offset=$((16#$1))
    local expected="$2"
    local replacement="$3"
    local label="$4"
    local nbytes=$(( ${#expected} / 2 ))

    # Read current bytes at offset
    local actual
    actual=$(dd if="$DLL" bs=1 skip="$offset" count="$nbytes" status=none 2>/dev/null \
        | od -A n -t x1 | tr -d ' \n')

    if [ "$actual" = "$replacement" ]; then
        echo "  [skip] $label — already patched"
        return 0
    fi

    if [ "$actual" != "$expected" ]; then
        echo "  [WARN] $label — unexpected bytes at 0x$1:" >&2
        echo "         expected $expected" >&2
        echo "         found    $actual" >&2
        echo "         DLL may be a different version; skipping." >&2
        return 1
    fi

    # Write replacement bytes
    local tmpf
    tmpf=$(mktemp)
    printf '%s' "$replacement" | sed 's/../\\x&/g' | xargs -0 printf > "$tmpf"
    dd if="$tmpf" of="$DLL" bs=1 seek="$offset" count="$nbytes" conv=notrunc status=none 2>/dev/null
    rm -f "$tmpf"
    echo "  [ ok ] $label at 0x$1"
    return 0
}

echo "Patching HeightmapExporter DLL for Wine compatibility …"

# 1. isR() bypass — mov eax,1; ret  (replaces function prologue)
patch_bytes 12010 "48895c240857" "b801000000c3" \
    "isR() bypass" || exit 1
# 2. vp() site 1 — lower bound 1 TB → 64 KB
patch_bytes ca22  "48b80000000000010000" "48b80000010000000000" \
    "vp() site 1 lower bound" || exit 1
# 3. vp() site 2 — addend -(1TB+1) → -(64KB+1)
patch_bytes c97d  "48b8fffffffffffeffff" "48b8fffffeffffffffff" \
    "vp() site 2 addend" || exit 1
# 4. vp() site 2 — range constant
patch_bytes c98a  "48bafdffffffff7e0000" "48bafdfffeffff7f0000" \
    "vp() site 2 range" || exit 1
# 5. vp() site 3 — addend
patch_bytes c9be  "48b8fffffffffffeffff" "48b8fffffeffffffffff" \
    "vp() site 3 addend" || exit 1
# 6. vp() site 3 — range constant (rcx register)
patch_bytes c9cb  "48b9fdffffffff7e0000" "48b9fdfffeffff7f0000" \
    "vp() site 3 range" || exit 1

echo "  Done — HeightmapExporter patched for Wine."
