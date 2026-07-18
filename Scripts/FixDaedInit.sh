#!/bin/bash
set -e

BASE="./wrt/package/luci-app-daed"

echo "[FixDaedInit] Searching luci_daed..."

TARGET=$(find "$BASE" -maxdepth 6 -type f -name "luci_daed" | head -n 1)

if [ -z "$TARGET" ]; then
    echo "[FixDaedInit] ERROR: luci_daed not found!"
    echo "[FixDaedInit] Dumping directory tree:"
    find "$BASE" -maxdepth 6 -type f -print
    exit 1
fi

echo "[FixDaedInit] Found luci_daed at: $TARGET"

# START=98 → START=99
sed -i 's/^START=98/START=99/' "$TARGET"

# 删除 hijack_resolv_conf / restore_resolv_conf
sed -i '/hijack_resolv_conf/d' "$TARGET"
sed -i '/restore_resolv_conf/d' "$TARGET"

echo "[FixDaedInit] Done. Showing first 80 lines:"
sed -n '1,80p' "$TARGET"
