#
# luci-app-ztewifi —— ZTE 随身WiFi 状态与设置（LuCI 应用 + Go 后端）
#
# 说明: 本 Makefile 供 OpenWrt/ImmortalWrt buildroot 集成使用。
#       产物包含 /usr/bin/ztewifi（Go 交叉编译）与 LuCI 菜单/ACL/视图文件。
#       本地免 buildroot 的安装方式见 install.sh 与 deploy.ps1。
#
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ztewifi
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1

GO_PKG:=ztewifi
GO_PKG_BUILD_PKG:=ztewifi
GO_PKG_LDFLAGS:=-s -w
GO_PKG_LDFLAGS_X:=

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/luci-app-ztewifi
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=ZTE portable WiFi (随身WiFi) status & settings
  DEPENDS:=$(GO_ARCH_DEPENDS) +luci-base +rpcd
  PKGARCH:=$(GO_ARCH)
endef

define Package/luci-app-ztewifi/description
  LuCI app for ZTE portable WiFi hotspots (RedCap Mobile Hotspot,
  model MU3650 / market name F40 and compatible firmware).

  - Adds a "ZTE 随身WiFi" panel to Status -> Overview showing signal bars,
    RSRP/RSRQ/SINR, radio band, carrier, WAN IP, device model and battery.
  - Adds a settings page to configure the device IP and admin password.
  - Backend is a small Go binary talking to the device's built-in
    /goform/goform_get_cmd_process web API (no external dependencies).
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/. $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(call GoPackage/Build/Compile)
endef

define Package/luci-app-ztewifi/install
	$(call GoPackage/Package/Install/Bin,$(PKG_INSTALL_DIR))

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/ztewifi $(1)/etc/config/ztewifi

	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/*.json $(1)/usr/share/luci/menu.d/

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/*.json $(1)/usr/share/rpcd/acl.d/

	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/ztewifi
	$(INSTALL_DATA) ./root/www/luci-static/resources/view/ztewifi/*.js $(1)/www/luci-static/resources/view/ztewifi/

	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/status/include
	$(INSTALL_DATA) ./root/www/luci-static/resources/view/status/include/*.js $(1)/www/luci-static/resources/view/status/include/
endef

define Package/luci-app-ztewifi/conffiles
/etc/config/ztewifi
endef

define Package/luci-app-ztewifi/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/rpcd restart >/dev/null 2>&1
	rm -f /tmp/luci-indexcache* 2>/dev/null
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-ztewifi))
