#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) ImmortalWrt.org

DEFAULT_COLOR="\033[0m"
BLUE_COLOR="\033[36m"
GREEN_COLOR="\033[32m"
RED_COLOR="\033[31m"
YELLOW_COLOR="\033[33m"

function __error_msg() {
	echo -e "${RED_COLOR}[ERROR]${DEFAULT_COLOR} $*"
}

function __info_msg() {
	echo -e "${BLUE_COLOR}[INFO]${DEFAULT_COLOR} $*"
}

function __success_msg() {
	echo -e "${GREEN_COLOR}[SUCCESS]${DEFAULT_COLOR} $*"
}

function __warning_msg() {
	echo -e "${YELLOW_COLOR}[WARNING]${DEFAULT_COLOR} $*"
}

# 关键步骤显式失败；不全局开 -e，避免 apt 抖动直接废掉构建
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

CHN_NET=""
VERSION_CODENAME=""
UBUNTU_CODENAME=""
GCC_VERSION=""
LLVM_VERSION=""
NODE_DISTRO=""
NODE_KEY=""
NODE_VERSION=""
VERSION_PACKAGE=""
DISTRO_PREFIX=""
DISTRO_SECUTIRY_PATH=""
APT_COMP=""
BPO_FLAG=""
BPO_DISTRO_PREFIX=""

# 统一 curl：重试 + 硬超时
CURL_OPTS=(-fsSL --retry 3 --retry-delay 5 --connect-timeout 15 --max-time 600)

function __die_msg() {
	__error_msg "$*"
	exit 1
}

function check_system() {
	__info_msg "Checking system info..."

	VERSION_CODENAME="$(source /etc/os-release; echo "$VERSION_CODENAME")"

	case "$VERSION_CODENAME" in
	"bionic")
		GCC_VERSION="9"
		LLVM_VERSION="18"
		NODE_DISTRO="$VERSION_CODENAME"
		NODE_KEY="nodesource.gpg.key"
		NODE_VERSION="18"
		UBUNTU_CODENAME="$VERSION_CODENAME"
		VERSION_PACKAGE="libpython3.6-dev python2.7 python3.6"
		;;
	"buster")
		DISTRO_PREFIX="debian-archive/"
		DISTRO_SECUTIRY_PATH="buster/updates"
		GCC_VERSION="9"
		LLVM_VERSION="18"
		UBUNTU_CODENAME="bionic"
		VERSION_PACKAGE="python2"
		;;
	"focal")
		GCC_VERSION="10"
		LLVM_VERSION="18"
		UBUNTU_CODENAME="$VERSION_CODENAME"
		VERSION_PACKAGE="python2"
		;;
	"bullseye")
		BPO_FLAG="-t $VERSION_CODENAME-backports"
		BPO_DISTRO_PREFIX="debian-archive/"
		GCC_VERSION="10"
		LLVM_VERSION="18"
		UBUNTU_CODENAME="focal"
		VERSION_PACKAGE="python2"
		;;
	"jammy")
		GCC_VERSION="10"
		LLVM_VERSION="18"
		UBUNTU_CODENAME="$VERSION_CODENAME"
		VERSION_PACKAGE="python2"
		;;
	"bookworm")
		APT_COMP="non-free-firmware"
		BPO_FLAG="-t $VERSION_CODENAME-backports"
		GCC_VERSION="12"
		LLVM_VERSION="18"
		UBUNTU_CODENAME="jammy"
		;;
	"noble")
		GCC_VERSION="13"
		LLVM_VERSION="18"
		UBUNTU_CODENAME="$VERSION_CODENAME"
		;;
	"trixie")
		APT_COMP="non-free-firmware"
		BPO_FLAG="-t $VERSION_CODENAME-backports"
		GCC_VERSION="13"
		LLVM_VERSION="18"
		UBUNTU_CODENAME="noble"
		;;
	*)
		__error_msg "Unsupported OS, use Ubuntu 20.04 instead."
		exit 1
		;;
	esac

	[ "$(uname -m)" == "x86_64" ] || { __error_msg "Unsupported architecture, use AMD64 instead." && exit 1; }

	[ "$(whoami)" == "root" ] || { __error_msg "You must run this script as root." && exit 1; }
}

function check_network() {
	__info_msg "Checking network..."

	if curl -s --connect-timeout 10 --max-time 20 --retry 2 "myip.ipip.net" 2>/dev/null | grep -qo "中国"; then
		CHN_NET=1
	fi
	curl -s --connect-timeout 10 --max-time 30 "baidu.com" > "/dev/null" 2>&1 || { __warning_msg "Your network is not suitable for compiling OpenWrt!"; }
	curl -s --connect-timeout 10 --max-time 30 "google.com" > "/dev/null" 2>&1 || { __warning_msg "Your network is not suitable for compiling OpenWrt!"; }
}

function update_apt_source() {
	__info_msg "Updating apt source lists..."

	apt update -y
	apt install -y apt-transport-https gnupg2

	mkdir -p "/etc/apt/keyrings"
	mkdir -p "/etc/apt/sources.list.d"
	mkdir -p "/etc/apt/trusted.gpg.d"

	if [ -n "$CHN_NET" ]; then
		for f in /etc/apt/sources.list /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/ubuntu.sources; do
			if [ -e "$f" ]; then
				mv -f "$f" "$f.bak"
			fi
		done

		if [ "$VERSION_CODENAME" == "$UBUNTU_CODENAME" ]; then
			cat <<-EOF >"/etc/apt/sources.list"
				deb https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME main restricted universe multiverse
				deb-src https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME main restricted universe multiverse

				deb https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-security main restricted universe multiverse
				deb-src https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-security main restricted universe multiverse

				deb https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-updates main restricted universe multiverse
				deb-src https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-updates main restricted universe multiverse

				# deb https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-proposed main restricted universe multiverse
				# deb-src https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-proposed main restricted universe multiverse

				deb https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-backports main restricted universe multiverse
				deb-src https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-backports main restricted universe multiverse
			EOF
		elif [ "$VERSION_CODENAME" == "buster" ]; then
			cat <<-EOF > "/etc/apt/sources.list"
			deb https://mirrors.tuna.tsinghua.edu.cn/debian-elts $VERSION_CODENAME main contrib non-free
			EOF
			curl -fsL "https://deb.freexian.com/extended-lts/archive-key.gpg" -o "/etc/apt/trusted.gpg.d/extended-lts.gpg"
		else
			cat <<-EOF > "/etc/apt/sources.list"
				deb https://mirrors.cloud.tencent.com/${DISTRO_PREFIX}debian/ $VERSION_CODENAME main contrib non-free${APT_COMP:+ $APT_COMP}
				deb-src https://mirrors.cloud.tencent.com/${DISTRO_PREFIX}debian/ $VERSION_CODENAME main contrib non-free${APT_COMP:+ $APT_COMP}

				deb https://mirrors.cloud.tencent.com/${DISTRO_PREFIX}debian-security ${DISTRO_SECUTIRY_PATH:-$VERSION_CODENAME-security} main contrib non-free${APT_COMP:+ $APT_COMP}
				deb-src https://mirrors.cloud.tencent.com/${DISTRO_PREFIX}debian-security ${DISTRO_SECUTIRY_PATH:-$VERSION_CODENAME-security} main contrib non-free${APT_COMP:+ $APT_COMP}

				deb https://mirrors.cloud.tencent.com/${DISTRO_PREFIX}debian/ $VERSION_CODENAME-updates main contrib non-free${APT_COMP:+ $APT_COMP}
				deb-src https://mirrors.cloud.tencent.com/${DISTRO_PREFIX}debian/ $VERSION_CODENAME-updates main contrib non-free${APT_COMP:+ $APT_COMP}

				deb https://mirrors.cloud.tencent.com/${BPO_DISTRO_PREFIX:-$DISTRO_PREFIX}debian/ $VERSION_CODENAME-backports main contrib non-free${APT_COMP:+ $APT_COMP}
				deb-src https://mirrors.cloud.tencent.com/${BPO_DISTRO_PREFIX:-$DISTRO_PREFIX}debian/ $VERSION_CODENAME-backports main contrib non-free${APT_COMP:+ $APT_COMP}
			EOF
		fi
	else
		if [ "$VERSION_CODENAME" == "buster" ]; then
			mv "/etc/apt/sources.list" "/etc/apt/sources.list.bak"
			cat <<-EOF > "/etc/apt/sources.list"
			deb https://deb.freexian.com/extended-lts $VERSION_CODENAME main contrib non-free
			EOF
			curl -fsL "https://deb.freexian.com/extended-lts/archive-key.gpg" -o "/etc/apt/trusted.gpg.d/extended-lts.gpg"
		fi
	fi

	cat <<-EOF >"/etc/apt/sources.list.d/nodesource.list"
		deb https://deb.nodesource.com/node_${NODE_VERSION:-22}.x ${NODE_DISTRO:-nodistro} main
	EOF
	curl -fsL "https://deb.nodesource.com/gpgkey/${NODE_KEY:-nodesource-repo.gpg.key}" -o "/etc/apt/trusted.gpg.d/nodesource.asc"

	cat <<-EOF >"/etc/apt/sources.list.d/yarn.list"
		deb https://dl.yarnpkg.com/debian/ stable main
	EOF
	curl -fsL "https://dl.yarnpkg.com/debian/pubkey.gpg" -o "/etc/apt/trusted.gpg.d/yarn.asc"

	case "$VERSION_CODENAME" in
	"bionic"|"buster")
		cat <<-EOF >"/etc/apt/sources.list.d/gcc-toolchain.list"
			deb https://ppa.launchpadcontent.net/ubuntu-toolchain-r/test/ubuntu $UBUNTU_CODENAME main
			deb-src https://ppa.launchpadcontent.net/ubuntu-toolchain-r/test/ubuntu $UBUNTU_CODENAME main
		EOF
		curl -fsL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x1e9377a2ba9ef27f" -o "/etc/apt/trusted.gpg.d/gcc-toolchain.asc"
		;;
	esac

	cat <<-EOF >"/etc/apt/sources.list.d/git-core-ubuntu-ppa.list"
		deb https://ppa.launchpadcontent.net/git-core/ppa/ubuntu $UBUNTU_CODENAME main
		deb-src https://ppa.launchpadcontent.net/git-core/ppa/ubuntu $UBUNTU_CODENAME main
	EOF
	curl -fsL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf911ab184317630c59970973e363c90f8f1b6217" -o "/etc/apt/trusted.gpg.d/git-core-ubuntu-ppa.asc"

	cat <<-EOF >"/etc/apt/sources.list.d/llvm-toolchain.list"
		deb https://apt.llvm.org/$VERSION_CODENAME/ llvm-toolchain-$VERSION_CODENAME-$LLVM_VERSION main
		deb-src https://apt.llvm.org/$VERSION_CODENAME/ llvm-toolchain-$VERSION_CODENAME-$LLVM_VERSION main
	EOF
	curl -fsL "https://apt.llvm.org/llvm-snapshot.gpg.key" -o "/etc/apt/trusted.gpg.d/llvm-toolchain.asc"

	# 不再加 golang PPA：Go 由 actions/setup-go 提供

	cat <<-EOF >"/etc/apt/sources.list.d/github-cli.list"
		deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main
	EOF
	curl -fsL "https://cli.github.com/packages/githubcli-archive-keyring.gpg" -o "/etc/apt/keyrings/githubcli-archive-keyring.gpg"

	if [ -n "$CHN_NET" ]; then
		sed -i -e "s,apt.llvm.org,mirrors.tuna.tsinghua.edu.cn/llvm-apt,g" -e "s,^deb-src,# deb-src,g" "/etc/apt/sources.list.d/llvm-toolchain.list"
		sed -i "s,ppa.launchpadcontent.net,launchpad.proxy.ustclug.org,g" "/etc/apt/sources.list.d"/*
	fi

	apt update -y $BPO_FLAG || { __warning_msg "apt update 失败，重试一次"; sleep 5; apt update -y $BPO_FLAG || __warning_msg "apt update 仍然失败，继续"; }
}
function install_dependencies() {
	__info_msg "Installing dependencies..."

	apt install -y $BPO_FLAG ack antlr3 asciidoc autoconf automake autopoint binutils bison \
		build-essential bzip2 ccache cmake cpio curl device-tree-compiler ecj fakeroot \
		fastjar flex gawk gettext genisoimage gnutls-dev gperf haveged help2man intltool \
		irqbalance jq lib32gcc-s1 libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev \
		libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libreadline-dev libssl-dev \
		libtool libyaml-dev libz-dev lrzsz msmtp nano ninja-build p7zip p7zip-full patch \
		pkgconf libpython3-dev python3 python3-pip python3-cryptography python3-docutils \
		python3-ply python3-pyelftools python3-requests qemu-utils quilt re2c rsync scons \
		sharutils squashfs-tools subversion swig texinfo uglifyjs unzip vim wget xmlto \
		zlib1g-dev zstd xxd $VERSION_PACKAGE || __die_msg "安装编译依赖失败"

	if [ -n "$CHN_NET" ]; then
		pip3 config set global.index-url "https://mirrors.aliyun.com/pypi/simple/"
		pip3 config set install.trusted-host "https://mirrors.aliyun.com"
	fi

	apt install -y git || __die_msg "安装 git 失败"

	apt install -y $BPO_FLAG "gcc-$GCC_VERSION" "g++-$GCC_VERSION" "gcc-$GCC_VERSION-multilib" "g++-$GCC_VERSION-multilib" \
		|| __die_msg "安装 gcc-$GCC_VERSION 失败"
	for i in "gcc-$GCC_VERSION" "g++-$GCC_VERSION" "gcc-ar-$GCC_VERSION" "gcc-nm-$GCC_VERSION" "gcc-ranlib-$GCC_VERSION"; do
		ln -svf "$i" "/usr/bin/${i%-$GCC_VERSION}"
	done
	ln -svf "/usr/bin/g++" "/usr/bin/c++"
	[ -e "/usr/include/asm" ] || ln -svf "/usr/include/$(gcc -dumpmachine)/asm" "/usr/include/asm"

	apt install -y $BPO_FLAG "clang-$LLVM_VERSION" "libclang-$LLVM_VERSION-dev" "lld-$LLVM_VERSION" "liblld-$LLVM_VERSION-dev" "llvm-$LLVM_VERSION" \
		|| __die_msg "安装 clang-$LLVM_VERSION 失败"
	for i in "/usr/lib/llvm-$LLVM_VERSION/bin"/*; do
		ln -svf "$i" "/usr/bin/${i##*/}"
	done
	ln -svf "/usr/lib/llvm-$LLVM_VERSION" "/usr/lib/llvm"

	apt install -y $BPO_FLAG nodejs yarn || __die_msg "安装 nodejs/yarn 失败"
	if [ -n "$CHN_NET" ]; then
		npm config set registry "https://registry.npmmirror.com" --global
		yarn config set registry "https://registry.npmmirror.com" --global
	fi


	apt install gh -y || __die_msg "安装 gh 失败"

	apt clean -y

	if TMP_DIR="$(mktemp -d)"; then
		pushd "$TMP_DIR"
	else
		__error_msg "Failed to create a tmp directory."
		exit 1
	fi

	UPX_REV="5.0.2"
	curl "${CURL_OPTS[@]}" -o "upx-$UPX_REV-amd64_linux.tar.xz" \
		"https://github.com/upx/upx/releases/download/v${UPX_REV}/upx-$UPX_REV-amd64_linux.tar.xz" \
		|| __die_msg "下载 upx 失败"
	tar -Jxf "upx-$UPX_REV-amd64_linux.tar.xz" || __die_msg "解压 upx 失败"
	rm -rf "/usr/bin/upx" "/usr/bin/upx-ucl"
	cp -fp "upx-$UPX_REV-amd64_linux/upx" "/usr/bin/upx-ucl" || __die_msg "安装 upx 失败"
	chmod 0755 "/usr/bin/upx-ucl"
	ln -svf "/usr/bin/upx-ucl" "/usr/bin/upx"

	curl "${CURL_OPTS[@]}" -o "padjffs2.c" \
		"https://raw.githubusercontent.com/openwrt/openwrt/main/tools/padjffs2/src/padjffs2.c" \
		|| __die_msg "下载 padjffs2.c 失败"
	gcc -Wall -Werror -o "padjffs2" "padjffs2.c" || __die_msg "编译 padjffs2 失败"
	strip "padjffs2"
	rm -rf "padjffs2.c" "/usr/bin/padjffs2"
	cp -fp "padjffs2" "/usr/bin/padjffs2"

	local cloned=0
	for i in 1 2 3; do
		rm -rf "po2lmo"
		if git clone --filter=blob:none --no-checkout "https://github.com/openwrt/luci.git" "po2lmo"; then
			cloned=1
			break
		fi
		__warning_msg "克隆 luci 失败，5 秒后重试（$i/3）"
		sleep 5
	done
	[ "$cloned" = "1" ] || __die_msg "克隆 luci 失败（已重试 3 次）"
	pushd "po2lmo"
	git config core.sparseCheckout true
	echo "modules/luci-base/src" >> ".git/info/sparse-checkout"
	git checkout || __die_msg "luci sparse checkout 失败"
	cd "modules/luci-base/src"
	make po2lmo || __die_msg "编译 po2lmo 失败"
	strip "po2lmo"
	rm -rf "/usr/bin/po2lmo"
	cp -fp "po2lmo" "/usr/bin/po2lmo"
	popd

	curl "${CURL_OPTS[@]}" -o "/usr/bin/modify-firmware" \
		"https://build-scripts.immortalwrt.org/modify-firmware.sh" \
		|| __die_msg "下载 modify-firmware 失败"
	[ -s "/usr/bin/modify-firmware" ] || __die_msg "modify-firmware 是空文件"
	chmod 0755 "/usr/bin/modify-firmware"

	popd
	rm -rf "$TMP_DIR"

	__success_msg "All dependencies have been installed."
}
function main() {
	check_system
	check_network
	update_apt_source
	install_dependencies
}

main
