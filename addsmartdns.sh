#!/bin/bash
set -x
# Add SmartDNS to OpenWrt build environment
cd ./wrt/
#./scripts/feeds update -a
MAKEFILE_PATH="feeds/packages/net/smartdns/Makefile"
WORKINGDIR="`pwd`/feeds/packages/net/smartdns"
MAKEFILE=$(find wrt/feeds/packages/net/smartdns/ -name Makefile | head -n1)
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
sed -i '/define Build\/Compile\/smartdns-ui/,/endef/ {
    /^\s*RUSTFLAGS=/ s/\"$/ -C prefer-dynamic -C link-arg=-lc -C link-arg=-lm\"/
}' "$MAKEFILE_PATH"
#sed -i '/^  DEPENDS:=+smartdns/ s/$/ +libc:0 +libm:0/' "$MAKEFILE_PATH"
sed -i '/Build\/Compile\/smartdns-ui/,/endef/ {
      s|make -C .*||g
      a \
export PATH=\$\$PATH:\$(CARGO_HOME)/bin ; \\
export CC=\$(TARGET_CC) ; \\
export CXX=\$(TARGET_CXX) ; \\
export AR=\$(TARGET_AR) ; \\
export RUSTFLAGS="-C linker=\$(TARGET_CC)" ; \\
cargo build --release --target aarch64-unknown-linux-musl \\
  --manifest-path=\$(PKG_BUILD_DIR)/plugin/smartdns-ui/Cargo.toml
    }' "$MAKEFILE"
echo "已修改 Makefile，以下是 smartdns 相关部分的新内容："
sed -n '/define Package\/smartdns/,/endef/p' "$MAKEFILE_PATH"


LUCIBRANCH="master" #更换此变量
WORKINGDIR="`pwd`/feeds/luci/applications/luci-app-smartdns"
mkdir $WORKINGDIR -p
rm $WORKINGDIR/* -fr
wget https://github.com/pymumu/luci-app-smartdns/archive/${LUCIBRANCH}.zip -O $WORKINGDIR/${LUCIBRANCH}.zip
unzip $WORKINGDIR/${LUCIBRANCH}.zip -d $WORKINGDIR
mv $WORKINGDIR/luci-app-smartdns-${LUCIBRANCH}/* $WORKINGDIR/
rmdir $WORKINGDIR/luci-app-smartdns-${LUCIBRANCH}
rm $WORKINGDIR/${LUCIBRANCH}.zip



