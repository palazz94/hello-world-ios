#!/usr/bin/env bash
# Build an unsigned IPA remotely and copy it into LiveContainer's Documents on the USB-connected iPhone.
set -euo pipefail

cd "$(dirname "$0")"

LC_BUNDLE_ID="${LC_BUNDLE_ID:-com.kdt.livecontainer.3LH7CMQ637}"
OUT_DIR="dist"

idevice_id -l | grep -q . || { echo "Nessun iPhone collegato via USB" >&2; exit 1; }

marker=$(mktemp)
trap 'rm -f "$marker"' EXIT

builder ios build --unsigned -o "$OUT_DIR"

ipa=$(find "$OUT_DIR" -maxdepth 1 -name '*.ipa' -newer "$marker" -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-)
[ -n "$ipa" ] || { echo "Nessun nuovo IPA trovato in $OUT_DIR" >&2; exit 1; }
name=$(basename "$ipa")

afc() { afcclient --documents "$LC_BUNDLE_ID" "$@"; }

# Drop IPAs from previous runs so LiveContainer's file picker only shows the latest.
{ afc ls /Documents | grep -E "^${name%%-*}-.*\.ipa$" || true; } | while read -r old; do
  afc rm "/Documents/$old"
done

afc put "$ipa" "/Documents/$name"
echo "Copiato $name in LiveContainer/Documents: installalo da LiveContainer (+ > File > $name)"
