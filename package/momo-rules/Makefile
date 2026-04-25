include $(TOPDIR)/rules.mk

PKG_NAME:=momo-rules
PKG_VERSION:=1
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/momo-rules
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Momo sing-box rules updater
  DEPENDS:=
endef

define Package/momo-rules/install
    $(INSTALL_DIR) $(1)/usr/bin
    $(INSTALL_BIN) ./update-momo-rules.sh $(1)/usr/bin/update-momo-rules.sh

    $(INSTALL_DIR) $(1)/etc/init.d
    $(INSTALL_BIN) ./momo-rules $(1)/etc/init.d/momo-rules

    $(INSTALL_DIR) $(1)/etc/uci-defaults
    $(INSTALL_BIN) ./99-momo-rules $(1)/etc/uci-defaults/99-momo-rules
endef

$(eval $(call BuildPackage,momo-rules))
