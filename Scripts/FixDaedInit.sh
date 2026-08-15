#!/bin/bash
set -e


########################################
# Fix daed init
########################################

echo
echo "===== Fix Daed Init ====="

BASE="$GITHUB_WORKSPACE/wrt/package/luci-app-daed/luci-app-daed/root/etc/init.d"
TARGET="$BASE/luci_daed"

echo "[Daed] Target: $TARGET"

if [ ! -f "$TARGET" ]; then
    echo "[Daed] ERROR: luci_daed not found!"
    ls -la "$BASE" || true
    exit 1
fi

echo "[Daed] Before:"
grep -E "^START=|hijack_resolv_conf|restore_resolv_conf" "$TARGET" || true


# START=98 -> START=99
sed -i 's/^START=98/START=99/' "$TARGET"

# Remove resolv hijack hooks
sed -i '/hijack_resolv_conf/d' "$TARGET"
sed -i '/restore_resolv_conf/d' "$TARGET"


echo "[Daed] After:"
grep -E "^START=|hijack_resolv_conf|restore_resolv_conf" "$TARGET" || true





