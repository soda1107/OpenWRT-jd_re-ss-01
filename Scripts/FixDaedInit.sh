#!/bin/bash
set -e

BASE="./luci-app-daed/luci-app-daed/root/etc/init.d"
TARGET="$BASE/luci_daed"

echo "[FixDaedInit] Target file: $TARGET"

if [ ! -f "$TARGET" ]; then
    echo "[FixDaedInit] ERROR: luci_daed not found!"
    ls -l "$BASE" || true
    exit 1
fi

# START=98 → START=99
sed -i 's/^START=98/START=99/' "$TARGET"

# 去掉 hijack_resolv_conf / restore_resolv_conf
sed -i '/hijack_resolv_conf/d' "$TARGET"
sed -i '/restore_resolv_conf/d' "$TARGET"

echo "[FixDaedInit] Done. First 40 lines:"
sed -n '1,40p' "$TARGET"
