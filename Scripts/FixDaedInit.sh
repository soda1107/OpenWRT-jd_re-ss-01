#!/bin/bash
set -e

BASE="./wrt/package/luci-app-daed"

FILE1="$BASE/root/etc/init.d/luci_daed"
FILE2="$BASE/luci-app-daed/root/etc/init.d/luci_daed"

echo "[FixDaedInit] Try FILE1: $FILE1"
echo "[FixDaedInit] Try FILE2: $FILE2"

if [ -f "$FILE1" ]; then
    FILE="$FILE1"
elif [ -f "$FILE2" ]; then
    FILE="$FILE2"
else
    echo "[FixDaedInit] ERROR: luci_daed not found in:"
    echo "  $FILE1"
    echo "  $FILE2"
    echo "[FixDaedInit] Current luci-app-daed tree:"
    find "$BASE" -maxdepth 5 -type f -print || true
    exit 1
fi

echo "[FixDaedInit] Using file: $FILE"

# START=98 → START=99
sed -i 's/^START=98/START=99/' "$FILE"

# 删除 hijack_resolv_conf / restore_resolv_conf
sed -i '/hijack_resolv_conf/d' "$FILE"
sed -i '/restore_resolv_conf/d' "$FILE"

echo "[FixDaedInit] Done. Head of file:"
sed -n '1,80p' "$FILE"
