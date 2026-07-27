#!/bin/bash
set -e

echo "======================================"
echo " Fix daed init and NSS ECM IPv6 temp stop"
echo "======================================"

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


########################################
# NSS ECM IPv6 temp stop
########################################

echo
echo "===== Enable IPv6 ECM temp stop ====="


ECM_SEARCH="$GITHUB_WORKSPACE/wrt"

echo "[ECM] Searching source..."

FILE=$(grep -rl \
"ecm_front_end_ipv6_stopped" \
"$ECM_SEARCH" \
2>/dev/null | grep "qca-nss-ecm" | head -n 1 || true)


if [ -z "$FILE" ]; then

    echo "[ECM] ERROR: ECM source not found!"

    grep -R \
    "ecm_front_end_ipv6_stopped" \
    "$ECM_SEARCH" \
    2>/dev/null || true

    exit 1

fi


echo "[ECM] Found:"
echo "$FILE"


echo "[ECM] Before:"
grep -n \
-e "ecm_front_end_ipv6_stopped" \
-e "ecm_front_end_ipv6_stopped_temp" \
"$FILE" || true


########################################
# 1. Keep permanent IPv6 ECM enabled
########################################

sed -i \
's/ecm_front_end_ipv6_stopped = 1/ecm_front_end_ipv6_stopped = 0/g' \
"$FILE"


