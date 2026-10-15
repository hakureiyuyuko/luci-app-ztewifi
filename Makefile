# SPDX-License-Identifier: MIT
#
# Copyright (C) 2026 luci-app-ztewifi contributors

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI support for ZTE portable WiFi hotspots
LUCI_DESCRIPTION:=Show signal, network and device information of a ZTE portable WiFi \
 (RedCap hotspot, e.g. MU3650 / F40) on the status overview page, plus a settings page \
 for the device address, login password and its wireless switch.
LUCI_DEPENDS:=+luci-base +rpcd

PKG_MAINTAINER:=luci-app-ztewifi contributors
PKG_LICENSE:=MIT
PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1

GO_PKG:=ztewifi

# golang-package.mk only defines variables and macros and does not pull in
# package.mk, so it is safe to include it before luci.mk (which includes
# package.mk itself).
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

# golang-values.mk unexports GOOS/GOARCH, so the target platform has to be
# forwarded to src/Makefile explicitly.
MAKE_VARS += \
	GO_OS="$(GO_OS)" \
	GO_ARCH="$(GO_ARCH)"

define Package/luci-app-ztewifi/conffiles
/etc/config/ztewifi
endef

include ../../luci.mk

# call BuildPackage - OpenWrt buildroot signature
