# EasyGRBL

Desktop application for controlling CNC and laser machines via the GRBL firmware. Designed for Linux and Windows.

Built with Flutter.

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
```

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
| `make run` | Run in debug mode on Linux |
| `make deps` | `flutter pub get` |
| `make upgrade` | `flutter pub upgrade` |
| `make clean` | Remove all build artifacts |
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
