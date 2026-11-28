#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

# CI 与 diy.sh 均以 cwd=./wrt/package/ 调用；用绝对路径避免 cwd 变化后修补被守卫静默跳过
[ -d "$PKG_PATH" ] || PKG_PATH="$(pwd)"
PACKAGE_PATH="$PKG_PATH"
FEEDS_PATH="$PKG_PATH/../feeds"


FIX() {
	local NAME=$1
	local GUARD=$2
	shift 2

	[ -d "$GUARD" ] || return 0

	echo " "
	if "$@"; then
		echo "$NAME has been fixed!"
	else
		echo "$NAME fix failed; continuing!"
	fi
}

FIX "theme-argon" "$PACKAGE_PATH/luci-theme-argon" sed -i \
	"s/primary '.*'/primary '#31a1a1'/g; s/'0.2'/'0.5'/g; s/'none'/'bing'/g; s/'600'/'normal'/g" \
	"$PACKAGE_PATH/luci-theme-argon/luci-app-argon-config/root/etc/config/argon"

FIX "mini-diskmanager" "$PACKAGE_PATH/luci-app-mini-diskmanager" sed -i "s/services/system/g" \
	"$PACKAGE_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json"

#修复TailScale配置文件冲突
TS_FILE="$(find "$FEEDS_PATH/packages" -maxdepth 3 -type f -wholename '*/tailscale/Makefile' -print -quit 2>/dev/null)"
if [ -f "$TS_FILE" ]; then
	echo " "
	if sed -i '/\/files/d' "$TS_FILE"; then
		echo "tailscale has been fixed!"
	else
		echo "tailscale fix failed; continuing!"
	fi
fi

#修复miniupnpd的失效补丁
MINIUPNPD_DIR="$FEEDS_PATH/packages/net/miniupnpd"
MINIUPNPD_MK="$MINIUPNPD_DIR/Makefile"
MINIUPNPD_BAD_020_SHA="4e0f8ddf58cb130044a5f3b92bdf3a8859f8c15e0edbcbcb2b8df42f99e41da1"
if [ -f "$MINIUPNPD_MK" ] && [ -f "$MINIUPNPD_DIR/patches/020-descr-filter-fix.patch" ]; then
	echo " "
	MUPNP_VER="$(sed -n 's/^PKG_VERSION:=//p' "$MINIUPNPD_MK" | head -n 1 | tr -d '\r[:space:]')"
	if command -v sha256sum >/dev/null 2>&1; then
		MUPNP_SHA="$(sha256sum "$MINIUPNPD_DIR/patches/020-descr-filter-fix.patch" | cut -d' ' -f1)"
	else
		MUPNP_SHA="$(shasum -a 256 "$MINIUPNPD_DIR/patches/020-descr-filter-fix.patch" | cut -d' ' -f1)"
	fi
	if [ "$MUPNP_SHA" = "$MINIUPNPD_BAD_020_SHA" ] && [ -n "$MUPNP_VER" ] &&
		[ "$(printf '%s\n' "2.3.11" "$MUPNP_VER" | sort -V | head -n 1)" = "2.3.11" ]; then
		rm -rf "$MINIUPNPD_DIR/patches"
		echo "miniupnpd $MUPNP_VER: dropped stale patches (already merged upstream)!"
	else
		echo "miniupnpd ${MUPNP_VER:-unknown}: patches kept as is"
	fi
fi
