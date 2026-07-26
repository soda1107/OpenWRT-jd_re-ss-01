#!/bin/bash
set -e

echo "======================================"
echo " Fix daed init and NSS ECM IPv6"
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
    echo "[Daed] Directory listing:"
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

echo "[Daed] First 40 lines:"
sed -n '1,40p' "$TARGET"


########################################
# Disable NSS ECM IPv6 acceleration
########################################

echo
echo "===== Disable NSS ECM IPv6 acceleration ====="


ECM_SEARCH="$GITHUB_WORKSPACE/wrt"

echo "[ECM] Searching source..."

FILE=$(grep -rl \
"ecm_front_end_ipv6_stopped = 0" \
"$ECM_SEARCH" \
2>/dev/null | head -n 1 || true)


if [ -z "$FILE" ]; then

    echo "[ECM] WARNING: Source variable not found."

    echo "[ECM] Try searching variable name:"
    grep -R \
    "ecm_front_end_ipv6_stopped" \
    "$ECM_SEARCH" \
    2>/dev/null || true

    echo "[ECM] Skip ECM patch."
else

    echo "[ECM] Found:"
    echo "$FILE"


    echo "[ECM] Before:"
    grep "ecm_front_end_ipv6_stopped" "$FILE" || true


    sed -i \
    's/ecm_front_end_ipv6_stopped = 0/ecm_front_end_ipv6_stopped = 1/' \
    "$FILE"


    echo "[ECM] After:"
    grep "ecm_front_end_ipv6_stopped" "$FILE" || true


    if grep -q \
    "ecm_front_end_ipv6_stopped = 1" \
    "$FILE"; then

        echo "[ECM] SUCCESS: IPv6 ECM disabled by default."

    else

        echo "[ECM] ERROR: Patch failed!"
        exit 1

    fi

fi


echo
echo "======================================"
echo " All patches completed"
echo "======================================"