# EasyGRBL

> ⚠️ **Unstable / early development.** This project is under active development and has not been thoroughly tested. It controls real CNC/laser hardware — bugs can cause unexpected machine movement, tool plunges, or damage to your machine, tooling, or workpiece. **Use at your own risk.**

Desktop application for controlling CNC and laser machines via the GRBL firmware. Designed for Linux and Windows.

<img width="1282" height="745" alt="Image" src="https://github.com/user-attachments/assets/28d3ade3-6e16-412c-a525-5cceb7c56235" />

---

## Features

- Connect to GRBL controller via serial port (USB)
- Load and preview SVG files as layer tree
- Per-layer operation settings (laser power, feed rate, passes)
- Generate G-code from SVG layers
- Jog control panel with configurable step sizes
- Machine position readout (WCS / MCS)
- Focus test, spot test, kerf test routines
- Machine settings (workspace size, serial parameters)
- Mock mode for development without hardware

---

## Requirements

### Linux

- Flutter SDK 3.x
- `libserialport` (`sudo apt install libserialport-dev`)
- The Linux desktop build also needs a C++ toolchain and a couple of dev
  headers Flutter's Linux embedder links against:

  ```bash
  sudo apt install clang ninja-build cmake pkg-config libgtk-3-dev libsecret-1-dev
  ```

  `make dist-linux` additionally needs `fakeroot` and `dpkg-dev` (for
  `dpkg-deb`/`dpkg-shlibdeps`) to build the `.deb` package.

### Windows

- Flutter SDK 3.x (Windows host)
- Visual Studio 2022 with "Desktop development with C++" workload

---

## Build

```bash
# Install dependencies
make deps

# Build Linux release → build/linux/x64/release/bundle/
make linux

# Build Linux debug
make linux-debug

# Build Windows release (requires Windows host)
make windows

# Build a redistributable .deb under dist/, installs to /opt/easy_grbl
make dist-linux

# Build a Windows MSIX installer (requires Windows host)
make dist-windows
```

`dist-linux` computes the package's runtime library dependencies with
`dpkg-shlibdeps` against the actual built binaries (not hardcoded), so it
stays correct across distro versions. Install with:

```bash
sudo apt install ./dist/easy-grbl_<version>_amd64.deb
```

`dist-windows` packages an MSIX installer via the `msix` pub package
(config in `pubspec.yaml` under `msix_config:`). It must run on an actual
Windows machine (or CI) — Flutter can't cross-compile the Windows build
from Linux. No `certificate_path` is configured, so it signs with an
auto-generated test certificate; Windows will show an "unknown publisher"
warning on install until it's properly code-signed.

---

## Run (development)

```bash
make run
# or
flutter run -d linux
```

---

## Make targets

| Target | Description |
|---|---|
| `make` | Build Linux release (default) |
| `make linux` | Build Linux release |
| `make linux-debug` | Build Linux debug |
| `make windows` | Build Windows release |
| `make dist-linux` | Build a redistributable .deb under `dist/` |
| `make dist-windows` | Build a Windows MSIX installer (run on Windows) |
| `make run` | Run in debug mode on Linux |
| `make deps` | `flutter pub get` |
| `make upgrade` | `flutter pub upgrade` |
| `make clean` | Remove all build and dist artifacts |
| `make clean-linux` | Remove Linux build artifacts |
| `make clean-windows` | Remove Windows build artifacts |

---

## Project structure

```
lib/
  main.dart
  models/          # Data models (SVG nodes, layer settings, machine settings)
  screens/         # Top-level screens (home, SVG viewer)
  services/        # Business logic (GRBL communication, SVG parser, G-code generator)
  widgets/         # UI components (panels, dialogs, painters)
```

---

## License

MIT
