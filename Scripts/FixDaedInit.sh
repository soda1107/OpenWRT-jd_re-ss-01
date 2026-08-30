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




########################################
# Fix honk package version
########################################

echo
echo "===== Fix Honk Package Version ====="

HONK_MAKEFILE="$GITHUB_WORKSPACE/wrt/package/luci-app-honk/honk/Makefile"

echo "[Honk] Target: $HONK_MAKEFILE"

if [ ! -f "$HONK_MAKEFILE" ]; then
    echo "[Honk] WARNING: Makefile not found at $HONK_MAKEFILE"
    exit 0
fi

echo "[Honk] Before:"
grep -E "^PKG_VERSION" "$HONK_MAKEFILE" || true

# 修复版本号：移除下划线，符合 APK 包管理器规范
# 将 PKG_VERSION:=0.0.1_beta63fix 改为 PKG_VERSION:=0.0.1
sed -i 's/PKG_VERSION:=\([0-9.]*\)_.*/PKG_VERSION:=\1/' "$HONK_MAKEFILE"

echo "[Honk] After:"
grep -E "^PKG_VERSION" "$HONK_MAKEFILE" || true

echo "[Honk] Fixed: honk package version normalized!"

