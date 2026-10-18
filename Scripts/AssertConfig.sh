#!/bin/bash
# SPDX-License-Identifier: MIT
# 断言核心插件与 eBPF 前置条件已进产物（cwd 需为源码树根目录）

set -uo pipefail

CONFIG_FILE="${1:-.config}"
if [ ! -f "$CONFIG_FILE" ]; then
	echo "::error::找不到 $CONFIG_FILE，请在 OpenWrt 源码树根目录运行"
	exit 1
fi

THEME="${WRT_THEME:-argon}"
fail=0

has_sym() {
	grep -qx "$1" "$CONFIG_FILE"
}

echo "===== 1) 核心插件必须存在 ====="
REQUIRED="
CONFIG_PACKAGE_dae
CONFIG_PACKAGE_luci-app-dae
CONFIG_PACKAGE_honk
CONFIG_PACKAGE_luci-app-honk
CONFIG_PACKAGE_v2ray-geoip
CONFIG_PACKAGE_v2ray-geosite
CONFIG_PACKAGE_v2ray-geodata-updater
CONFIG_PACKAGE_luci-theme-$THEME
CONFIG_PACKAGE_luci-app-$THEME-config
"
for sym in $REQUIRED; do
	if has_sym "$sym=y"; then
		echo "  OK    $sym"
	else
		echo "::error::$sym 未进入 $CONFIG_FILE —— 对应包源可能克隆失败或依赖未满足"
		fail=$((fail + 1))
	fi
done

echo "===== 2) 内核侧 eBPF/BTF 前置条件 ====="
# 这些选项由 cat_kernel_config() 写入 config-default，不在 .config 里
KFRAG="target/linux/qualcommax/ipq60xx/config-default"
if [ -f "$KFRAG" ]; then
	for pat in \
		'CONFIG_BPF=y' \
		'CONFIG_BPF_SYSCALL=y' \
		'CONFIG_BPF_JIT=y' \
		'CONFIG_DEBUG_INFO_BTF=y' \
		'CONFIG_BPF_EVENTS=y' \
		'CONFIG_NET_CLS_BPF=[ym]' \
		'CONFIG_NET_SCH_INGRESS=[ym]' \
		'CONFIG_CGROUPS=y'; do
		if grep -qxE "$pat" "$KFRAG"; then
			echo "  OK    $pat"
		else
			echo "::error::$KFRAG 缺少 $pat —— cat_kernel_config 没生效，dae 将无法启动"
			fail=$((fail + 1))
		fi
	done
else
	echo "::error::找不到内核 fragment $KFRAG —— 内核 BPF 配置没有被写入，dae 将无法启动"
	fail=$((fail + 1))
fi

echo "===== 3) 软性检查（只告警） ====="
for sym in \
	CONFIG_KERNEL_DEBUG_INFO_BTF \
	CONFIG_KERNEL_BPF_EVENTS \
	CONFIG_PACKAGE_kmod-sched-bpf \
	CONFIG_PACKAGE_kmod-veth \
	CONFIG_PACKAGE_dae-geoip \
	CONFIG_PACKAGE_dae-geosite; do
	has_sym "$sym=y" || echo "::warning::$sym 不在 .config 中（符号可能不存在，或包未启用）"
done

if [[ "${WRT_CONFIG:-}" == *"NOWIFI"* ]]; then
	for sym in CONFIG_PACKAGE_wpad-openssl CONFIG_PACKAGE_hostapd-common CONFIG_PACKAGE_kmod-ath11k; do
		if has_sym "$sym=y"; then
			echo "::warning::$WRT_CONFIG 是 NOWIFI 配置，但 $sym 仍被启用（remove_wifi 可能没覆盖到）"
		fi
	done
	if [ -d "package/network/services/hostapd" ] || [ -d "package/firmware/ipq-wifi" ]; then
		echo "::warning::remove_wifi 应该删除 hostapd / ipq-wifi 目录，但源码树里仍存在"
	fi
fi

echo "===== 断言结果：$fail 项失败 ====="
if [ "$fail" -ne 0 ]; then
	echo "::error::配置断言失败（$fail 项），中止构建以免产出缺功能的固件"
	exit 1
fi
echo "配置断言通过"
