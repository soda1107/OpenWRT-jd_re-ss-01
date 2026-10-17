#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#本脚本由 CI 以 cwd=./wrt/package/ 调用，diy.sh 亦同；
#这里沿用上游的绝对路径写法，避免调用点变化后所有修补被守卫静默跳过。
PKG_PATH="${GITHUB_WORKSPACE:+$GITHUB_WORKSPACE/wrt/package}"
[ -d "$PKG_PATH" ] || PKG_PATH="$(pwd)"
PACKAGE_PATH="$PKG_PATH"
#注意：wrt/package/feeds 是指向 wrt/feeds 的符号链接，而 find 默认(-P)不跟随符号链接，
#必须用 ../feeds 这个真实路径，否则 tailscale 的 find 永远找不到文件。
FEEDS_PATH="$PKG_PATH/../feeds"

#修补命令统一入口：FIX <名称> <守卫目录> <命令...>
#守卫目录不存在时直接跳过，保证在 bash -e 下不中断
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

#修改argon主题字体和颜色
FIX "theme-argon" "$PACKAGE_PATH/luci-theme-argon" sed -i \
	"s/primary '.*'/primary '#31a1a1'/g; s/'0.2'/'0.5'/g; s/'none'/'bing'/g; s/'600'/'normal'/g" \
	"$PACKAGE_PATH/luci-theme-argon/luci-app-argon-config/root/etc/config/argon"

#修改aurora菜单式样
FIX "theme-aurora" "$PACKAGE_PATH/luci-app-aurora-config" find \
	"$PACKAGE_PATH/luci-app-aurora-config/root/usr/share/aurora/" -type f -name '*.template' -exec sed -i \
	"s/nav_type '.*'/nav_type 'dropdown'/g; s/struct_radius_base '.*'/struct_radius_base '0.125rem'/g" {} +

#修改mini-diskmanager菜单位置
FIX "mini-diskmanager" "$PACKAGE_PATH/luci-app-mini-diskmanager" sed -i "s/services/system/g" \
	"$PACKAGE_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json"

#修改natmapt菜单位置
FIX "natmapt" "$PACKAGE_PATH/luci-app-natmapt" sed -i "s/network/services/g" \
	"$PACKAGE_PATH/luci-app-natmapt/root/usr/share/luci/menu.d/luci-app-natmap.json"

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

#修复Rust编译失败
FIX "rust" "$FEEDS_PATH/packages/lang/rust" sed -i 's/ci-llvm=true/ci-llvm=false/g' \
	"$FEEDS_PATH/packages/lang/rust/Makefile"

#修复miniupnpd的失效补丁
MINIUPNPD_DIR="$FEEDS_PATH/packages/net/miniupnpd"
MINIUPNPD_MK="$MINIUPNPD_DIR/Makefile"
#已知坏快照：immortalwrt/packages 2026-10-16 的 "Merge Official Source" 把 miniupnpd 2.3.11
#合了进来，却把 openwrt 早已删掉的旧补丁又带了回来。这些补丁对应的代码 2.3.11 已经自带
#（已核对 upnppermissions.c 里 iseol / get_sep / get_addr 与 const char * 签名全在），
#重打必然 Hunk FAILED，整个 world 编译直接中断。openwrt/packages 在 2.3.11 上已不带任何
#补丁，这里对齐它的状态。
#用补丁指纹做守卫：上游一旦真正修好（补丁内容变了），指纹对不上就自动跳过，不会误删。
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