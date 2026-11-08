#
# Copyright (C) 2015-2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=v2ray-geodata
PKG_VERSION:=2026.11.07
PKG_RELEASE:=1

# 单一来源：rules.zip 里同时含 geoip.dat 与 geosite.dat。
# 固定 tag + PKG_HASH，交给 OpenWrt 下载器缓存/重试，构建期不再联网抓 latest。
PKG_SOURCE:=rules.zip
PKG_SOURCE_URL:=https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/202611072203/
PKG_HASH:=c71313870a21d8a4466b532a5a360c9c5b61bdcae12b09a7f5724ec2460a324d

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=sbwml <admin@cooluc.com>

include $(INCLUDE_DIR)/package.mk

define Package/v2ray-geodata/default
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=IP Addresses and Names
  URL:=https://www.v2fly.org
  PKGARCH:=all
endef

define Package/v2ray-geoip
  $(call Package/v2ray-geodata/default)
  TITLE:=GeoIP List for V2Ray
  LICENSE:=CC-BY-SA-4.0
endef

define Package/v2ray-geosite
  $(call Package/v2ray-geodata/default)
  TITLE:=Geosite List for V2Ray
  LICENSE:=GPL-3.0
endef

define Package/v2ray-geodata-updater
  $(call Package/v2ray-geodata/default)
  TITLE:=Geodata Updater for V2Ray
  LICENSE:=GPL-3.0
endef

define Build/Prepare
	rm -rf $(PKG_BUILD_DIR)
	mkdir -p $(PKG_BUILD_DIR)
	unzip -o -j $(DL_DIR)/$(PKG_SOURCE) geoip.dat geosite.dat -d $(PKG_BUILD_DIR)
	test -s $(PKG_BUILD_DIR)/geoip.dat
	test -s $(PKG_BUILD_DIR)/geosite.dat
endef

define Build/Compile
endef

define Package/v2ray-geoip/install
	$(INSTALL_DIR) $(1)/usr/share/v2ray
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/geoip.dat $(1)/usr/share/v2ray/geoip.dat
endef

define Package/v2ray-geosite/install
	$(INSTALL_DIR) $(1)/usr/share/v2ray
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/geosite.dat $(1)/usr/share/v2ray/geosite.dat
endef

define Package/v2ray-geodata-updater/install
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) ./v2ray-geodata-updater $(1)/bin/
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./init.sh $(1)/etc/uci-defaults/xxx-v2ray-geodata-updater
endef

$(eval $(call BuildPackage,v2ray-geoip))
$(eval $(call BuildPackage,v2ray-geosite))
$(eval $(call BuildPackage,v2ray-geodata-updater))
