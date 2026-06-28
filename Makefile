APP_NAME    := easy_grbl
ifeq ($(OS),Windows_NT)
    VERSION := $(shell powershell -Command "(Get-Content pubspec.yaml | Select-String '^version:').ToString().Split(' ')[1].Split('+')[0]")
else
    VERSION := $(shell grep '^version:' pubspec.yaml | awk '{split($$2,a,"+"); print a[1]}')
endif
BUILD_DIR   := build

# Linux paths
LINUX_RELEASE_DIR  := $(BUILD_DIR)/linux/x64/release/bundle
LINUX_DEBUG_DIR    := $(BUILD_DIR)/linux/x64/debug/bundle

# Windows paths (cross-compilation via flutter build windows requires Windows host
# or a configured cross-toolchain; set FLUTTER_WINE_EXEC if using Wine)
WIN_RELEASE_DIR    := $(BUILD_DIR)/windows/x64/runner/Release

.PHONY: all help \
        linux linux-debug linux-release \
        windows windows-release \
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
	@echo "  run               Run app in debug mode on Linux"
	@echo ""
	@echo "  clean             Remove all build artifacts"
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

linux-debug:
	flutter build linux --debug
	@echo "Debug build: $(LINUX_DEBUG_DIR)"

linux-release:
	flutter build linux --release
	@echo "Release build: $(LINUX_RELEASE_DIR)"

# ─── windows ──────────────────────────────────────────────────────────────────
windows: windows-release

windows-release:
	flutter build windows --release
	@echo "Release build: $(WIN_RELEASE_DIR)"

# ─── run ──────────────────────────────────────────────────────────────────────
run:
	flutter run -d linux

# ─── clean ────────────────────────────────────────────────────────────────────
clean: clean-linux clean-windows

clean-linux:
	rm -rf $(BUILD_DIR)/linux

clean-windows:
	rm -rf $(BUILD_DIR)/windows
