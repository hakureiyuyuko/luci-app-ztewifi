# Go backend of luci-app-ztewifi.
#
# Driven by the OpenWrt build system through luci.mk:
#   make -C $(PKG_BUILD_DIR)/src clean compile
#   make -C $(PKG_BUILD_DIR)/src DESTDIR=$(PKG_INSTALL_DIR) install
#
# GO_OS / GO_ARCH are forwarded from the top level Makefile, otherwise the
# build would target the build host instead of the router.
# The Go toolchain comes from the golang/host build dependency.

GO ?= go
BIN := ztewifi

GO_OS ?= linux
GO_ARCH ?= $(shell $(GO) env GOARCH)

all: compile

compile:
	GOOS=$(GO_OS) GOARCH=$(GO_ARCH) CGO_ENABLED=0 \
		$(GO) build -trimpath -ldflags "-s -w" -o $(BIN) .

install:
	mkdir -p $(DESTDIR)/usr/bin
	cp -f $(BIN) $(DESTDIR)/usr/bin/$(BIN)
	chmod 0755 $(DESTDIR)/usr/bin/$(BIN)

clean:
	rm -f $(BIN)

.PHONY: all compile install clean
