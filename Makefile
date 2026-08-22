APP_NAME    := easy_grbl
ARCH        := amd64
ifeq ($(OS),Windows_NT)
    VERSION := $(shell powershell -Command "(Get-Content pubspec.yaml | Select-String '^version:').ToString().Split(' ')[1].Split('+')[0]")
else
    VERSION := $(shell grep '^version:' pubspec.yaml | awk '{split($$2,a,"+"); print a[1]}')
endif
# msix_version needs 4 dot-separated components; pad the 3-part pubspec VERSION.
MSIX_VERSION := $(VERSION).0
BUILD_DIR   := build

# Linux paths
LINUX_RELEASE_DIR  := $(BUILD_DIR)/linux/x64/release/bundle
LINUX_DEBUG_DIR    := $(BUILD_DIR)/linux/x64/debug/bundle

# Windows paths (cross-compilation via flutter build windows requires Windows host
# or a configured cross-toolchain; set FLUTTER_WINE_EXEC if using Wine)
WIN_RELEASE_DIR    := $(BUILD_DIR)/windows/x64/runner/Release

# Linux packaging (.deb) paths. Debian package names may not contain
# underscores, so this is separate from APP_NAME (used for the binary,
# install dir, etc.) -- see packaging/linux/control.in's Package: field.
DEB_NAME     := easy-grbl
DIST_DIR     := dist
DEB_STAGING  := $(DIST_DIR)/deb-staging
DEB_FILE     := $(DIST_DIR)/$(DEB_NAME)_$(VERSION)_$(ARCH).deb

.PHONY: all help \
        linux linux-debug linux-release \
        windows windows-release \
        dist-linux dist-windows check-build-deps-linux check-dist-deps-linux \
        run clean clean-linux clean-windows \
        deps upgrade

# ─── default ──────────────────────────────────────────────────────────────────
all: linux-release

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  deps              Install / fetch Flutter dependencies"
	@echo "  upgrade           Upgrade Flutter dependencies"
	@echo ""
	@echo "  linux             Build Linux release (alias for linux-release)"
	@echo "  linux-debug       Build Linux debug"
	@echo "  linux-release     Build Linux release"
	@echo ""
	@echo "  windows           Build Windows release (alias for windows-release)"
	@echo "  windows-release   Build Windows release (requires Windows host or Wine)"
	@echo ""
	@echo "  dist-linux        Build a redistributable .deb under dist/"
	@echo "  dist-windows      Build a Windows MSIX installer (run on Windows)"
	@echo ""
	@echo "  run               Run app in debug mode on Linux"
	@echo ""
	@echo "  clean             Remove all build and dist artifacts"
	@echo "  clean-linux       Remove Linux build artifacts"
	@echo "  clean-windows     Remove Windows build artifacts"
	@echo ""
	@echo "  App: $(APP_NAME)  Version: $(VERSION)"

# ─── dependencies ─────────────────────────────────────────────────────────────
deps:
	flutter pub get

upgrade:
	flutter pub upgrade

# ─── linux ────────────────────────────────────────────────────────────────────
linux: linux-release

# Verifies the system packages the README's "Linux" requirements section
# documents (clang/ninja/cmake/pkg-config binaries, plus the GTK 3,
# libsecret and libserialport dev headers pkg-config needs to find). Checked
# up front so a missing package fails fast with the apt install line,
# instead of deep inside flutter/cmake's own configure step.
check-build-deps-linux:
	@missing=""; \
	for bin in clang clang++ ninja cmake pkg-config; do \
	  command -v $$bin >/dev/null 2>&1 || missing="$$missing $$bin"; \
	done; \
	for lib in gtk+-3.0 libsecret-1 libserialport; do \
	  pkg-config --exists $$lib 2>/dev/null || missing="$$missing lib:$$lib"; \
	done; \
	if [ -n "$$missing" ]; then \
	  echo "error: missing Linux build tools/libraries:$$missing" >&2; \
	  echo "Install with: sudo apt install clang ninja-build cmake pkg-config libgtk-3-dev libsecret-1-dev libserialport-dev" >&2; \
	  exit 1; \
	fi

linux-debug:
	flutter build linux --debug
	@echo "Debug build: $(LINUX_DEBUG_DIR)"

linux-release: check-build-deps-linux
	flutter build linux --release
	@echo "Release build: $(LINUX_RELEASE_DIR)"

# ─── windows ──────────────────────────────────────────────────────────────────
windows: windows-release

windows-release:
	flutter build windows --release
	@echo "Release build: $(WIN_RELEASE_DIR)"

# ─── dist ─────────────────────────────────────────────────────────────────────

# Verifies the extra tools dist-linux's packaging step needs on top of
# check-build-deps-linux (dpkg-shlibdeps to compute runtime deps, fakeroot
# and dpkg-deb to build the .deb).
check-dist-deps-linux:
	@missing=""; \
	for bin in dpkg-shlibdeps fakeroot dpkg-deb; do \
	  command -v $$bin >/dev/null 2>&1 || missing="$$missing $$bin"; \
	done; \
	if [ -n "$$missing" ]; then \
	  echo "error: missing Linux packaging tools:$$missing" >&2; \
	  echo "Install with: sudo apt install dpkg-dev fakeroot" >&2; \
	  exit 1; \
	fi

# Packages the release bundle as a .deb installing to /opt/easy_grbl, with a
# symlink on PATH and a desktop launcher entry. Runtime library dependencies
# are computed with dpkg-shlibdeps against the actual built binaries, so
# they match whatever distro/version this runs on rather than being
# hardcoded.
dist-linux: check-dist-deps-linux linux-release
	mkdir -p $(DIST_DIR)
	rm -rf $(DEB_STAGING)
	mkdir -p $(DEB_STAGING)/DEBIAN $(DEB_STAGING)/opt/$(APP_NAME) \
	         $(DEB_STAGING)/usr/local/bin $(DEB_STAGING)/usr/share/applications
	cp -r $(LINUX_RELEASE_DIR)/. $(DEB_STAGING)/opt/$(APP_NAME)/
	cp easygrbl.svg $(DEB_STAGING)/opt/$(APP_NAME)/
	ln -sf /opt/$(APP_NAME)/$(APP_NAME) $(DEB_STAGING)/usr/local/bin/$(APP_NAME)
	sed 's|@APP_NAME@|$(APP_NAME)|g' packaging/linux/easy_grbl.desktop.in \
	    > $(DEB_STAGING)/usr/share/applications/$(APP_NAME).desktop
	deps="$$(cd packaging/linux && dpkg-shlibdeps -O --ignore-missing-info \
	          $(CURDIR)/$(LINUX_RELEASE_DIR)/$(APP_NAME) $(CURDIR)/$(LINUX_RELEASE_DIR)/lib/*.so 2>/dev/null \
	          | sed -n 's/^shlibs:Depends=//p')"; \
	sed -e "s|@VERSION@|$(VERSION)|" -e "s|@DEPENDS@|$$deps|" \
	    packaging/linux/control.in > $(DEB_STAGING)/DEBIAN/control
	fakeroot dpkg-deb --build --root-owner-group $(DEB_STAGING) $(DEB_FILE)
	@echo
	@echo "Built $(DEB_FILE)"
	@echo "Install with: sudo apt install ./$(DEB_FILE)"

# Packages the release build as an MSIX installer (see msix_config in
# pubspec.yaml). Must run on Windows -- Flutter can't cross-compile the
# Windows build from Linux, and msix:create operates on that build output.
# Uses an auto-generated self-signed test certificate (no certificate_path
# configured), so Windows will show an "unknown publisher" warning until
# it's code-signed for wider distribution.
#
# --version overrides msix_config's msix_version for this run without
# touching pubspec.yaml (msix:create's own CLI flag, takes priority over
# the pubspec value -- see msix package's configuration.dart).
dist-windows: windows-release
	dart run msix:create --version=$(MSIX_VERSION)

# ─── run ──────────────────────────────────────────────────────────────────────
run:
	flutter run -d linux

# ─── clean ────────────────────────────────────────────────────────────────────
clean: clean-linux clean-windows
	rm -rf $(DIST_DIR)

clean-linux:
	rm -rf $(BUILD_DIR)/linux

clean-windows:
	rm -rf $(BUILD_DIR)/windows
