#
# luci-app-ztewifi - ZTE portable WiFi status and settings
#
# The LuCI part (htdocs/, root/, po/) is handled entirely by luci.mk, which
# also generates the luci-i18n-ztewifi-<lang> translation packages from po/.
#
# The Go backend in ./src is built through the standard "src/Makefile" hook.
# When src/Makefile is present luci.mk runs
#     make -C $(PKG_BUILD_DIR)/src clean compile
#     make -C $(PKG_BUILD_DIR)/src DESTDIR=$(PKG_INSTALL_DIR) install
# and installs everything under $(PKG_INSTALL_DIR).
#
# Because src/Makefile exists, luci.mk leaves LUCI_PKGARCH empty, so this
# package is architecture specific (it ships a compiled Go binary) - which
# is what we want.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ztewifi
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1

GO_PKG:=ztewifi

LUCI_TITLE:=ZTE portable WiFi status and settings
LUCI_DESCRIPTION:=Show signal, network and device information of a ZTE portable WiFi \
 (RedCap hotspot, e.g. MU3650 / F40) on the LuCI overview page, plus a settings page \
 for the device address, login password and its WiFi switch. \
 The backend is a dependency-free Go binary talking to the device's built-in web API.
LUCI_DEPENDS:=+luci-base +rpcd

include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

# Cross compilation settings, passed down to src/Makefile.
# (golang-values.mk unexports GOOS/GOARCH, so they must be forwarded explicitly.)
MAKE_VARS += \
	GO_OS="$(GO_OS)" \
	GO_ARCH="$(GO_ARCH)"

include $(TOPDIR)/feeds/luci/luci.mk
