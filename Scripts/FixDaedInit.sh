#!/bin/bash
set -e

FILE="./wrt/package/luci-app-daed/root/etc/init.d/luci_daed"

echo "[FixDaedInit] Target file: $FILE"

if [ ! -f "$FILE" ]; then
    echo "[FixDaedInit] ERROR: luci_daed not found!"
    exit 1
fi

# 修改 START=98 → START=99
sed -i 's/^START=98/START=99/' "$FILE"

# 删除 hijack_resolv_conf
sed -i '/hijack_resolv_conf/d' "$FILE"

# 删除 restore_resolv_conf
sed -i '/restore_resolv_conf/d' "$FILE"

echo "[FixDaedInit] Done. Updated file content:"
sed -n '1,200p' "$FILE"
