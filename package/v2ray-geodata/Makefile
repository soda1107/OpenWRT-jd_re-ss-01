#
# Copyright (C) 2015-2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=v2ray-geodata
PKG_VERSION:=$(shell date "+%Y.%m.%d")
PKG_RELEASE:=1

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

GEOIP_URL:=https://github.com/Loyalsoldier/geoip/releases/latest/download/geoip.dat
GEOSITE_URL:=https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat

define Build/Compile
	( \
		set -eu; \
		cd "$(PKG_BUILD_DIR)"; \
		curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 300 "$(GEOIP_URL)" -o geoip.dat.tmp --progress-bar; \
		curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 300 "$(GEOSITE_URL)" -o geosite.dat.tmp --progress-bar; \
		curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 300 "$(GEOIP_URL).sha256sum" -o geoip.dat.sha256sum.tmp; \
		curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 300 "$(GEOSITE_URL).sha256sum" -o geosite.dat.sha256sum.tmp; \
		geoip_sha256=$$(awk 'NR == 1 {print $$1; exit}' geoip.dat.sha256sum.tmp); \
		geosite_sha256=$$(awk 'NR == 1 {print $$1; exit}' geosite.dat.sha256sum.tmp); \
		case "$$geoip_sha256" in *[!0-9a-fA-F]*|'') echo "Invalid GeoIP checksum" >&2; exit 1;; esac; \
		case "$$geosite_sha256" in *[!0-9a-fA-F]*|'') echo "Invalid GeoSite checksum" >&2; exit 1;; esac; \
		[ "$${#geoip_sha256}" -eq 64 ] || { echo "Invalid GeoIP checksum length" >&2; exit 1; }; \
		[ "$${#geosite_sha256}" -eq 64 ] || { echo "Invalid GeoSite checksum length" >&2; exit 1; }; \
		printf '%s  %s\n' "$$geoip_sha256" geoip.dat.tmp | sha256sum -c -; \
		printf '%s  %s\n' "$$geosite_sha256" geosite.dat.tmp | sha256sum -c -; \
		mv geoip.dat.tmp geoip.dat; \
		mv geosite.dat.tmp geosite.dat; \
		rm -f geoip.dat.sha256sum.tmp geosite.dat.sha256sum.tmp; \
	)
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
