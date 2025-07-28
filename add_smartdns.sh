#!/bin/bash
# Add SmartDNS to OpenWrt build environment
cd ./wrt/
#./scripts/feeds update -a
WORKINGDIR="`pwd`/feeds/packages/net/smartdns"
mkdir $WORKINGDIR -p
rm $WORKINGDIR/* -fr
mkdir $WORKINGDIR/plugin -p
wget https://github.com/pymumu/openwrt-smartdns/archive/master.zip -O $WORKINGDIR/master.zip
unzip $WORKINGDIR/master.zip -d $WORKINGDIR
mv $WORKINGDIR/openwrt-smartdns-master/* $WORKINGDIR/
cd $WORKINGDIR/plugin
git clone https://github.com/pymumu/smartdns-webui.git smartdns-ui
rmdir $WORKINGDIR/openwrt-smartdns-master
rm $WORKINGDIR/master.zip
sed -i 's#^\s*include \.\./\.\./lang/rust/rust-package.mk#include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk#' $WORKINGDIR/Makefile

LUCIBRANCH="master" #更换此变量
WORKINGDIR="`pwd`/feeds/luci/applications/luci-app-smartdns"
mkdir $WORKINGDIR -p
rm $WORKINGDIR/* -fr
wget https://github.com/pymumu/luci-app-smartdns/archive/${LUCIBRANCH}.zip -O $WORKINGDIR/${LUCIBRANCH}.zip
unzip $WORKINGDIR/${LUCIBRANCH}.zip -d $WORKINGDIR
mv $WORKINGDIR/luci-app-smartdns-${LUCIBRANCH}/* $WORKINGDIR/
rmdir $WORKINGDIR/luci-app-smartdns-${LUCIBRANCH}
rm $WORKINGDIR/${LUCIBRANCH}.zip

#WORKINGDIR="`pwd`/packages/new/“
#mkdir $WORKINGDIR -p
git clone https://$github/JohnsonRan/InfinityDuck package/new/InfinityDuck --depth=1
echo "src/gz infsubs https://opkg.ihtw.moe/openwrt-24.10/$arch/InfinitySubstance" >>files/etc/opkg/customfeeds.conf


