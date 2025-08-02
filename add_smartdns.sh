#!/bin/bash
set -x
# Add SmartDNS to OpenWrt build environment
cd ./wrt/
./scripts/feeds update -a
MAKEFILE_PATH="feeds/packages/net/smartdns/Makefile"
WORKINGDIR="`pwd`/feeds/packages/net/smartdns"
mkdir $WORKINGDIR -p
rm $WORKINGDIR/* -fr
#mkdir $WORKINGDIR/plugin -p
wget https://github.com/pymumu/openwrt-smartdns/archive/master.zip -O $WORKINGDIR/master.zip
unzip $WORKINGDIR/master.zip -d $WORKINGDIR
mv $WORKINGDIR/openwrt-smartdns-master/* $WORKINGDIR/
#cd $WORKINGDIR/plugin
#git clone https://github.com/pymumu/smartdns-webui.git smartdns-ui
rmdir $WORKINGDIR/openwrt-smartdns-master
rm $WORKINGDIR/master.zip
if [ ! -f "$MAKEFILE_PATH" ]; then
    echo "错误：Makefile文件未找到，请检查路径是否正确。"
    exit 1
fi
sed -i 's#^\s*include \.\./\.\./lang/rust/rust-package.mk#include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk#' $WORKINGDIR/Makefile
sed -i '/define Package\/smartdns-ui/a\\ \ DEPENDS_IGNORE:=libc.so.6 libm.so.6' "$MAKEFILE_PATH"


# shellcheck disable=SC2016
sed -i '/^  DEPENDS:=+smartdns $(RUST_ARCH_DEPENDS)/ s/$/ +libc +libm/' "$MAKEFILE_PATH"
sed -i '/define Build\/Compile\/smartdns-ui/,/endef/ {
        /^\s*RUSTFLAGS=/ s/\"$/ -C prefer-dynamic -C link-arg=-lc -C link-arg=-lm\"/
    }' "$MAKEFILE_PATH"
echo "已修改 Makefile，这是 smartdns-ui 部分的新内容："
sed -n '/define Package\/smartdns-ui/,/endef/p' "$MAKEFILE_PATH"


LUCIBRANCH="master" #更换此变量
WORKINGDIR="`pwd`/feeds/luci/applications/luci-app-smartdns"
mkdir $WORKINGDIR -p
rm $WORKINGDIR/* -fr
wget https://github.com/pymumu/luci-app-smartdns/archive/${LUCIBRANCH}.zip -O $WORKINGDIR/${LUCIBRANCH}.zip
unzip $WORKINGDIR/${LUCIBRANCH}.zip -d $WORKINGDIR
mv $WORKINGDIR/luci-app-smartdns-${LUCIBRANCH}/* $WORKINGDIR/
rmdir $WORKINGDIR/luci-app-smartdns-${LUCIBRANCH}
rm $WORKINGDIR/${LUCIBRANCH}.zip



