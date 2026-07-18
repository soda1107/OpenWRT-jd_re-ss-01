#!/bin/bash
set -e

BASE="./wrt/package"

echo "[FixDaedInit] Searching luci_daed in $BASE ..."

TARGET=$(find "$BASE" -maxdepth 10 -type f -name "luci_daed" | head -n 1)

if [ -z "$TARGET" ]; then
    echo "[FixDaedInit] ERROR: luci_daed not found!"
    echo "[FixDaedInit] Dumping directory tree:"
    find "$BASE" -maxdepth 10 -type f -print
    exit 1
fi

echo "[FixDaedInit] Found luci_daed at: $TARGET"

sed -i 's/^START=98/START=99/' "$TARGET"
sed -i '/hijack_resolv_conf/d' "$TARGET"
sed -i '/restore_resolv_conf/d' "$TARGET"

echo "[FixDaedInit] Done. Showing first 80 lines:"
sed -n '1,80p' "$TARGET"
