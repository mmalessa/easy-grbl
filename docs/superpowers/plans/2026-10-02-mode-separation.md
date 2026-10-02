# Mode Separation (Laser / Mill) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganise EasyGRBL so everything specific to Laser or Mill (settings, G-code strategy, settings UI, laser templates) lives in `lib/machines/<mode>/`, with shared geometry in `lib/geometry/`. Generated G-code, toolpath preview and persisted settings must stay byte-for-byte identical.

**Architecture:**
- `MachineSettings` becomes a composite: `machineType` + `CommonSettings` + `LaserSettings` + `MillSettings`. It flattens to today's `machine_<field>` preference keys.
- `GcodeGenerator` keeps the shared skeleton and delegates every mode difference to a `GcodeStrategy` (`LaserGcodeStrategy` / `MillGcodeStrategy`).
- The toolpath preview, the mock job animation and the Layer Settings hint use the same strategy as the generator.
- The Machine Settings dialog becomes a shell around per-mode `*SettingsForm` + `*SettingsSection` pairs.

**Tech Stack:** Flutter (Linux/Windows desktop), Dart 3, `flutter_test`, `shared_preferences`, `path_drawing`, `clipper2`.

**Spec:** `docs/superpowers/specs/2026-10-02-mode-separation-design.md`

## Global Constraints

- **No git commits.** Every task ends with a report to the user instead of a commit (user instruction).
- **Golden files are never regenerated during this plan.** They are created once in Task 0 from the unmodified code. Never run with `--dart-define=UPDATE_GOLDENS=true` after Task 0.
- `flutter analyze` must report `No issues found!` at the end of every task.
- `flutter test` must pass at the end of every task, except the known pre-existing failure `test/widget_test.dart` (RightPanel overflow in the 800×600 test window). That test is out of scope.
- `LayerSettings` stays a single shared class in `lib/models/layer_settings.dart`.
- Preference keys stay exactly: `machine_machineType`, `machine_laserMode`, `machine_sMax`, `machine_laserSpotSize`, `machine_maxSpindleSpeed`, `machine_maxFeedRate`, `machine_toolDiameter`, `machine_bladeAngle`, `machine_engravePower`, `machine_engraveSpeed`, `machine_cutPower`, `machine_cutSpeed`, `machine_fillPower`, `machine_fillSpeed`, `machine_engraveSpindleSpeed`, `machine_engraveFeedRate`, `machine_cutSpindleSpeed`, `machine_cutFeedRate`, `machine_fillSpindleSpeed`, `machine_fillFeedRate`, `machine_safeHeight`, `machine_travelFeedRate`, `machine_defaultBaudRate`.
- Defaults are preserved exactly, including constructor vs `fromMap` differences:
  - `maxSpindleSpeed` 1000 vs 24000,
  - `maxFeedRate` 10.0 vs 3000.0,
  - `toolDiameter` 2.0 vs 3.175.
- Mill keeps borrowing `laserMode` (M3/M4) and `laserSpotSize` (fill inset) from the laser settings. They are passed explicitly to `MillGcodeStrategy`.
- Code style: relative imports inside `lib/`, `package:easy_grbl/...` imports in `test/`. Match the surrounding comment density.
- **Deviation from spec, by design.** `MachineModeProfile` and `GcodeStrategy` are `abstract class`, not `sealed`. Dart requires sealed subclasses in the same library, but the spec puts each mode's subclass in its own directory.
- **Deviation from spec, by design.** `GcodeGenerator.computeActiveBounds` is deleted instead of moved, because nothing calls it.

## Review Focus

1. **Settings saved by the current version** (all `machine_*` keys present) load with identical values after the refactor. Covered by Task 0 *legacy prefs* test.
2. **A fresh install** (no stored keys) gets the first-run defaults (24000 RPM, 3000 feed, 3.175 mm tool), not the constructor defaults. Covered by Task 0 `fromMap({})` test.
3. **Opening Machine Settings and pressing Save without editing** returns exactly the settings it was opened with, in both Laser and Mill mode. Covered by Task 0 dialog test, re-run unchanged after Task 6.
4. **Switching mode with a file loaded:** the preview's cut offsets and fill insets follow the new mode exactly like G-code does. Covered by Task 0 toolpath goldens for both modes.
5. **Mill with the laser set to Dynamic (M4)** still starts the spindle with M4 (borrowed behaviour, no silent change to M3). Covered by Task 0 `mill_flat.gcode` golden, which uses `LaserMode.variable`.

---

## File Structure (end state)

| Path | Responsibility |
|---|---|
| `lib/machines/machine_mode.dart` | `MachineType` enum, abstract `MachineModeProfile`, `MachineType.profile` |
| `lib/machines/machine_settings.dart` | composite `MachineSettings` (map flatten/unflatten) |
| `lib/machines/common_settings.dart` | `CommonSettings` (baud rate) |
| `lib/machines/gcode/gcode_generator.dart` | shared SVG→G-code skeleton |
| `lib/machines/gcode/gcode_strategy.dart` | abstract `GcodeStrategy` + `GcodeStrategy.of` |
| `lib/machines/laser/laser_settings.dart` | `LaserMode`, `LaserSettings` |
| `lib/machines/laser/laser_mode_profile.dart` | `LaserModeProfile` |
| `lib/machines/laser/laser_gcode_strategy.dart` | `LaserGcodeStrategy` |
| `lib/machines/laser/widgets/laser_settings_section.dart` | `LaserSettingsForm`, `LaserSettingsSection` |
| `lib/machines/laser/templates/focus_test.dart` | `FocusTestConfig`, `buildFocusTestDocument` |
| `lib/machines/laser/templates/kerf_test.dart` | `KerfTestConfig`, `buildKerfTestDocument` |
| `lib/machines/laser/templates/spot_test.dart` | `SpotTestConfig`, `buildSpotTestDocument` |
| `lib/machines/laser/templates/test_session.dart` | `TestSession` (sealed, unchanged) |
| `lib/machines/laser/templates/laser_gcode_templates.dart` | `LaserGcodeTemplates` (was `GcodeTemplates`) |
| `lib/machines/laser/templates/widgets/*.dart` | focus/kerf/spot panels, `test_panel_common.dart` |
| `lib/machines/mill/mill_settings.dart` | `MillSettings` (+ `effectiveDiameterAt`) |
| `lib/machines/mill/mill_mode_profile.dart` | `MillModeProfile` |
| `lib/machines/mill/mill_gcode_strategy.dart` | `MillGcodeStrategy` |
| `lib/machines/mill/widgets/mill_settings_section.dart` | `MillSettingsForm`, `MillSettingsSection` |
| `lib/geometry/affine.dart`, `path_offset.dart`, `svg_node_walker.dart`, `svg_transform.dart` | moved unchanged |
| `lib/geometry/contour_sampler.dart` | `sampleContours` |
| `lib/geometry/fill_lines.dart` | `computeFillLines` |
| `lib/widgets/settings_form_fields.dart` | shared form-row builders for the settings dialog |
| `lib/widgets/machine_settings_dialog.dart` | dialog shell (status, section, connection, Save) |
| `test/support/sample_document.dart` | shared sample SVG document for regression tests |

---

### Task 0: Regression safety net

Capture today's behaviour as goldens and tests **before any production code changes**.

**Files:**
- Create: `test/support/sample_document.dart`
- Modify: `test/gcode_regression_test.dart`
- Create: `test/settings_regression_test.dart`
- Create: `test/toolpath_regression_test.dart`
- Create: `test/machine_settings_dialog_test.dart`
- Create (generated): `test/goldens/laser_m4.gcode`, `mill_flat.gcode`, `focus_test.gcode`, `focus_test_m4.gcode`, `kerf_test.gcode`, `spot_test.gcode`, `toolpath_laser.txt`, `toolpath_mill.txt`

**Interfaces:**
- Produces: `SvgDocument sampleDocument()` in `test/support/sample_document.dart`, plus golden files used unchanged by every later task.

- [ ] **Step 1: Extract the sample document**

Create `test/support/sample_document.dart`. Move `_sampleDocument()` out of `test/gcode_regression_test.dart` and make it public:

```dart
import 'dart:ui';

import 'package:easy_grbl/models/layer_settings.dart';
import 'package:easy_grbl/models/operation_type.dart';
import 'package:easy_grbl/models/svg_document.dart';
import 'package:easy_grbl/models/svg_node.dart';
import 'package:easy_grbl/models/svg_node_type.dart';

/// Covers every operation and cut side; shared by the regression tests.
SvgDocument sampleDocument() {
  const square = 'M 10,10 L 40,10 L 40,40 L 10,40 Z';
  return SvgDocument(
    viewBox: const Rect.fromLTWH(0, 0, 100, 60),
    roots: [
      SvgNode(
        id: 'engrave',
        label: 'Engrave',
        type: SvgNodeType.path,
        pathData: 'M 5,50 C 20,30 40,70 60,50',
        settings: LayerSettings(
            operationType: OperationType.engrave, powerPercent: 40, speedMmS: 30),
      ),
      SvgNode(
        id: 'cut_line',
        label: 'Cut line',
        type: SvgNodeType.path,
        pathData: square,
        settings: LayerSettings(
            operationType: OperationType.cut, passes: 2, cutDepthMm: 1.5),
      ),
      SvgNode(
        id: 'cut_outer',
        label: 'Cut outer',
        type: SvgNodeType.path,
        pathData: 'M 50,10 L 80,10 L 80,40 L 50,40 Z',
        settings: LayerSettings(
            operationType: OperationType.cut,
            cutSide: CutSide.outer,
            cutDepthMm: 2.0),
      ),
      SvgNode(
        id: 'cut_inner',
        label: 'Cut inner',
        type: SvgNodeType.path,
        pathData: 'M 60,15 L 70,15 L 70,25 L 60,25 Z',
        settings: LayerSettings(
            operationType: OperationType.cut, cutSide: CutSide.inner),
      ),
      SvgNode(
        id: 'fill',
        label: 'Fill',
        type: SvgNodeType.path,
        pathData: 'M 85,5 L 95,5 L 95,15 L 85,15 Z',
        settings: LayerSettings(
            operationType: OperationType.fill, linesPerMm: 2, fillOutline: true),
      ),
    ],
  );
}
```

- [ ] **Step 2: Extend the G-code regression test**

Replace `test/gcode_regression_test.dart` with:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/models/focus_test_config.dart';
import 'package:easy_grbl/models/kerf_test_config.dart';
import 'package:easy_grbl/models/machine_settings.dart';
import 'package:easy_grbl/models/spot_test_config.dart';
import 'package:easy_grbl/services/gcode_generator.dart';
import 'package:easy_grbl/services/gcode_templates.dart';

import 'support/sample_document.dart';

// Guards G-code output against unintended changes. Regenerate the golden files
// only for a deliberate output change:
//   flutter test test/gcode_regression_test.dart --dart-define=UPDATE_GOLDENS=true
const _updateGoldens = bool.fromEnvironment('UPDATE_GOLDENS');

void _expectGolden(String name, String actual) {
  final file = File('test/goldens/$name');
  if (_updateGoldens) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(actual);
    return;
  }
  expect(actual, file.readAsStringSync());
}

String _generate(MachineSettings s) =>
    GcodeGenerator.generate(sampleDocument(), 'sample.svg', s);

void main() {
  group('document G-code', () {
    test('laser M3', () {
      _expectGolden('laser.gcode', _generate(const MachineSettings()));
    });

    test('laser M4', () {
      _expectGolden(
          'laser_m4.gcode',
          _generate(const MachineSettings(
              laserMode: LaserMode.variable, sMax: 255, laserSpotSize: 0.2)));
    });

    test('mill V-bit', () {
      _expectGolden(
          'mill.gcode',
          _generate(const MachineSettings(
              machineType: MachineType.mill, bladeAngle: 60)));
    });

    test('mill flat bit, laser set to M4', () {
      _expectGolden(
          'mill_flat.gcode',
          _generate(const MachineSettings(
            machineType: MachineType.mill,
            laserMode: LaserMode.variable,
            maxSpindleSpeed: 24000,
            toolDiameter: 6.0,
            bladeAngle: 180.0,
            safeHeight: 3.0,
            travelFeedRate: 40.0,
          )));
    });
  });

  group('laser templates', () {
    test('focus', () {
      _expectGolden('focus_test.gcode',
          GcodeTemplates.focusTest(const FocusTestConfig(), const MachineSettings()));
    });

    test('focus M4', () {
      _expectGolden(
          'focus_test_m4.gcode',
          GcodeTemplates.focusTest(
              const FocusTestConfig(),
              const MachineSettings(laserMode: LaserMode.variable, sMax: 255)));
    });

    test('kerf', () {
      _expectGolden('kerf_test.gcode',
          GcodeTemplates.kerfTest(const KerfTestConfig(), const MachineSettings()));
    });

    test('spot', () {
      _expectGolden('spot_test.gcode',
          GcodeTemplates.spotTest(const SpotTestConfig(), const MachineSettings()));
    });
  });
}
```

- [ ] **Step 3: Write the toolpath regression test**

Create `test/toolpath_regression_test.dart`:

```dart
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/models/machine_settings.dart';
import 'package:easy_grbl/services/toolpath.dart';

import 'support/sample_document.dart';

// See gcode_regression_test.dart for how to regenerate goldens.
const _updateGoldens = bool.fromEnvironment('UPDATE_GOLDENS');

void _expectGolden(String name, String actual) {
  final file = File('test/goldens/$name');
  if (_updateGoldens) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(actual);
    return;
  }
  expect(actual, file.readAsStringSync());
}

/// Text dump of a toolpath: every contour sampled every 2 mm plus its end.
String _describe(ToolpathData? t) {
  if (t == null) return 'null';
  final b = StringBuffer();
  String fmt(Offset p) =>
      '${p.dx.toStringAsFixed(3)} ${p.dy.toStringAsFixed(3)}';
  void dump(String name, Path path) {
    b.writeln('# $name');
    for (final m in path.computeMetrics()) {
      b.writeln('contour len=${m.length.toStringAsFixed(3)}');
      for (var d = 0.0; d < m.length; d += 2.0) {
        final t = m.getTangentForOffset(d);
        if (t != null) b.writeln(fmt(t.position));
      }
      final end = m.getTangentForOffset(m.length);
      if (end != null) b.writeln('end ${fmt(end.position)}');
    }
  }

  dump('rapid', t.rapidPath);
  final colors = t.feeds.keys.toList()
    ..sort((a, c) => a.toARGB32().compareTo(c.toARGB32()));
  for (final c in colors) {
    dump('feed ${c.toARGB32().toRadixString(16)}', t.feeds[c]!);
  }
  return b.toString();
}

void main() {
  test('laser toolpath matches golden', () {
    _expectGolden('toolpath_laser.txt',
        _describe(computeToolpath(sampleDocument(), const MachineSettings())));
  });

  test('mill toolpath matches golden', () {
    _expectGolden(
        'toolpath_mill.txt',
        _describe(computeToolpath(sampleDocument(),
            const MachineSettings(machineType: MachineType.mill, bladeAngle: 60))));
  });
}
```

- [ ] **Step 4: Write the settings regression test**

Create `test/settings_regression_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easy_grbl/models/machine_settings.dart';
import 'package:easy_grbl/services/settings_service.dart';

const _constructorDefaults = <String, Object>{
  'machineType': 'laser',
  'laserMode': 'constant',
  'sMax': 1000,
  'laserSpotSize': 0.1,
  'maxSpindleSpeed': 1000,
  'maxFeedRate': 10.0,
  'toolDiameter': 2.0,
  'bladeAngle': 30.0,
  'engravePower': 60,
  'engraveSpeed': 3000,
  'cutPower': 100,
  'cutSpeed': 800,
  'fillPower': 80,
  'fillSpeed': 3000,
  'engraveSpindleSpeed': 12000,
  'engraveFeedRate': 20.0,
  'cutSpindleSpeed': 18000,
  'cutFeedRate': 30.0,
  'fillSpindleSpeed': 18000,
  'fillFeedRate': 50.0,
  'safeHeight': 5.0,
  'travelFeedRate': 25.0,
  'defaultBaudRate': 115200,
};

final _firstRunDefaults = <String, Object>{
  ..._constructorDefaults,
  'maxSpindleSpeed': 24000,
  'maxFeedRate': 3000.0,
  'toolDiameter': 3.175,
};

/// Every field differs from both default sets. Values are representable by
/// the Machine Settings dialog's text formatting (see dialog test).
const customSettingsMap = <String, Object>{
  'machineType': 'mill',
  'laserMode': 'variable',
  'sMax': 255,
  'laserSpotSize': 0.15,
  'maxSpindleSpeed': 12000,
  'maxFeedRate': 1500.5,
  'toolDiameter': 6.35,
  'bladeAngle': 90.0,
  'engravePower': 40,
  'engraveSpeed': 2500,
  'cutPower': 95,
  'cutSpeed': 600,
  'fillPower': 70,
  'fillSpeed': 4000,
  'engraveSpindleSpeed': 10000,
  'engraveFeedRate': 15.5,
  'cutSpindleSpeed': 16000,
  'cutFeedRate': 25.5,
  'fillSpindleSpeed': 17000,
  'fillFeedRate': 45.5,
  'safeHeight': 4.5,
  'travelFeedRate': 30.5,
  'defaultBaudRate': 250000,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('constructor defaults', () {
    expect(const MachineSettings().toMap(), _constructorDefaults);
  });

  test('first-run defaults (empty map)', () {
    expect(MachineSettings.fromMap(const {}).toMap(), _firstRunDefaults);
  });

  test('map round trip', () {
    expect(MachineSettings.fromMap(customSettingsMap).toMap(), customSettingsMap);
  });

  test('SettingsService stores machine_<field> keys', () async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.save(MachineSettings.fromMap(customSettingsMap));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(),
        customSettingsMap.keys.map((k) => 'machine_$k').toSet());
    expect((await SettingsService.load()).toMap(), customSettingsMap);
  });

  test('loads preferences saved by the previous version', () async {
    SharedPreferences.setMockInitialValues({
      for (final e in customSettingsMap.entries) 'machine_${e.key}': e.value,
    });
    expect((await SettingsService.load()).toMap(), customSettingsMap);
  });
}
```

- [ ] **Step 5: Write the Machine Settings dialog Save round-trip test**

Create `test/machine_settings_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/models/machine_settings.dart';
import 'package:easy_grbl/services/grbl_mock_service.dart';
import 'package:easy_grbl/widgets/machine_settings_dialog.dart';

import 'settings_regression_test.dart' show customSettingsMap;

Future<MachineSettings?> _openAndSave(
    WidgetTester tester, MachineSettings current) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final grbl = GrblMockService();
  addTearDown(grbl.dispose);
  MachineSettings? result;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showMachineSettingsDialog(context, current, grbl);
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('Save without edits keeps every value (mill)', (tester) async {
    final current = MachineSettings.fromMap(customSettingsMap);
    final result = await _openAndSave(tester, current);
    expect(find.text('MILL'), findsNothing); // dialog closed
    expect(result!.toMap(), customSettingsMap);
  });

  testWidgets('Save without edits keeps every value (laser)', (tester) async {
    final map = {...customSettingsMap, 'machineType': 'laser'};
    final result = await _openAndSave(tester, MachineSettings.fromMap(map));
    expect(result!.toMap(), map);
  });
}
```

- [ ] **Step 6: Generate goldens from the unmodified code**

Run: `flutter test test/gcode_regression_test.dart test/toolpath_regression_test.dart --dart-define=UPDATE_GOLDENS=true`

Expected: all pass. New files appear in `test/goldens/`. The existing `laser.gcode` and `mill.gcode` are rewritten with identical content. Check with `git diff --stat test/goldens`: there should be no diff for files that existed before.

- [ ] **Step 7: Run the full suite without the update flag**

Run: `flutter test`

Expected: everything passes except `test/widget_test.dart` (pre-existing). If a dialog test fails, the dialog does not preserve values on Save today. Stop and report it to the user before going further; it would be a pre-existing bug, not something to fix silently.

- [ ] **Step 8: Report** (no commit)

---

### Task 1: Split settings into Laser / Mill / Common parts

**Files:**
- Create: `lib/machines/machine_mode.dart`
- Create: `lib/machines/common_settings.dart`
- Create: `lib/machines/laser/laser_settings.dart`
- Create: `lib/machines/mill/mill_settings.dart`
- Create: `lib/machines/machine_settings.dart`
- Delete: `lib/models/machine_settings.dart`
- Modify (field access + imports):
  - `lib/services/gcode_generator.dart`, `toolpath.dart`, `grbl_mock_service.dart`, `grbl_serial_service.dart`, `grbl_service.dart`, `gcode_templates.dart`, `settings_service.dart`,
  - `lib/models/machine_mode_profile.dart`,
  - `lib/widgets/layer_settings_panel.dart`, `left_panel.dart`, `main_app_bar.dart`, `right_panel.dart`, `machine_settings_dialog.dart`,
  - `lib/screens/home/home_screen.dart`
- Modify tests: `test/gcode_regression_test.dart`, `test/toolpath_regression_test.dart`, `test/settings_regression_test.dart`, `test/machine_settings_dialog_test.dart`, `test/machine_mode_test.dart`
- Create test: `test/machine_settings_parts_test.dart`

**Interfaces:**
- Produces:
  - `enum MachineType { laser, mill }` in `lib/machines/machine_mode.dart`,
  - `enum LaserMode`, `extension LaserModeDisplay` (`label`, `gcode`), `class LaserSettings` in `lib/machines/laser/laser_settings.dart`,
  - `class MillSettings` with `double effectiveDiameterAt(double cutDepthMm)`,
  - `class CommonSettings { int defaultBaudRate }`,
  - `class MachineSettings { MachineType machineType; CommonSettings common; LaserSettings laser; MillSettings mill; }` with `copyWith`, `toMap`, `fromMap`, plus **temporary** `effectiveDiameterAt` / `cutOffsetDeltaFor` (removed in Task 5).

- [ ] **Step 1: Write the failing test for the parts**

Create `test/machine_settings_parts_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/machines/common_settings.dart';
import 'package:easy_grbl/machines/laser/laser_settings.dart';
import 'package:easy_grbl/machines/machine_mode.dart';
import 'package:easy_grbl/machines/machine_settings.dart';
import 'package:easy_grbl/machines/mill/mill_settings.dart';

void main() {
  test('each part owns only its keys', () {
    expect(const LaserSettings().toMap().keys.toSet(), {
      'laserMode', 'sMax', 'laserSpotSize', 'engravePower', 'engraveSpeed',
      'cutPower', 'cutSpeed', 'fillPower', 'fillSpeed',
    });
    expect(const MillSettings().toMap().keys.toSet(), {
      'maxSpindleSpeed', 'maxFeedRate', 'toolDiameter', 'bladeAngle',
      'safeHeight', 'travelFeedRate', 'engraveSpindleSpeed', 'engraveFeedRate',
      'cutSpindleSpeed', 'cutFeedRate', 'fillSpindleSpeed', 'fillFeedRate',
    });
    expect(const CommonSettings().toMap().keys.toSet(), {'defaultBaudRate'});
  });

  test('copyWith replaces only the given part', () {
    const s = MachineSettings();
    final m = s.copyWith(
        machineType: MachineType.mill, mill: const MillSettings(safeHeight: 9));
    expect(m.machineType, MachineType.mill);
    expect(m.mill.safeHeight, 9);
    expect(m.laser.toMap(), s.laser.toMap());
    expect(m.common.toMap(), s.common.toMap());
  });

  group('MillSettings.effectiveDiameterAt', () {
    test('straight bit keeps nominal diameter', () {
      const m = MillSettings(toolDiameter: 6, bladeAngle: 180);
      expect(m.effectiveDiameterAt(5), 6);
    });

    test('90° V-bit is 2×depth wide, clamped to nominal', () {
      const m = MillSettings(toolDiameter: 6, bladeAngle: 90);
      expect(m.effectiveDiameterAt(1), closeTo(2, 1e-9));
      expect(m.effectiveDiameterAt(10), 6);
    });
  });

  test('laser mode labels and codes', () {
    expect(LaserMode.constant.gcode, 'M3');
    expect(LaserMode.variable.gcode, 'M4');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/machine_settings_parts_test.dart`
Expected: compilation failure, `machines/common_settings.dart` not found.

- [ ] **Step 3: Create `lib/machines/machine_mode.dart`**

```dart
/// The app's working mode. Persisted as [MachineSettings.machineType].
enum MachineType { laser, mill }
```

- [ ] **Step 4: Create `lib/machines/common_settings.dart`**

```dart
/// Settings shared by every working mode.
class CommonSettings {
  final int defaultBaudRate;

  const CommonSettings({this.defaultBaudRate = 115200});

  CommonSettings copyWith({int? defaultBaudRate}) =>
      CommonSettings(defaultBaudRate: defaultBaudRate ?? this.defaultBaudRate);

  Map<String, Object> toMap() => {'defaultBaudRate': defaultBaudRate};

  factory CommonSettings.fromMap(Map<String, Object?> map) => CommonSettings(
        defaultBaudRate: map['defaultBaudRate'] as int? ?? 115200,
      );
}
```

- [ ] **Step 5: Create `lib/machines/laser/laser_settings.dart`**

```dart
enum LaserMode { constant, variable }

extension LaserModeDisplay on LaserMode {
  String get label => switch (this) {
        LaserMode.constant => 'Constant power (M3)',
        LaserMode.variable => 'Dynamic (M4)',
      };
  String get gcode => switch (this) {
        LaserMode.constant => 'M3',
        LaserMode.variable => 'M4',
      };
}

/// Laser engraver settings: power scaling ($30 → [sMax]), spot size and the
/// per-operation defaults applied when an operation is picked in Layer
/// Settings. Speeds are in mm/min.
///
/// Note: the `*Power` defaults are also used as the "Power %" default in Mill
/// mode, and Mill borrows [laserMode] and [laserSpotSize] for G-code (see
/// MillGcodeStrategy).
class LaserSettings {
  final LaserMode laserMode;
  final int sMax;
  final double laserSpotSize;
  final int engravePower;
  final int engraveSpeed;
  final int cutPower;
  final int cutSpeed;
  final int fillPower;
  final int fillSpeed;

  const LaserSettings({
    this.laserMode = LaserMode.constant,
    this.sMax = 1000,
    this.laserSpotSize = 0.1,
    this.engravePower = 60,
    this.engraveSpeed = 3000,
    this.cutPower = 100,
    this.cutSpeed = 800,
    this.fillPower = 80,
    this.fillSpeed = 3000,
  });

  LaserSettings copyWith({
    LaserMode? laserMode,
    int? sMax,
    double? laserSpotSize,
    int? engravePower,
    int? engraveSpeed,
    int? cutPower,
    int? cutSpeed,
    int? fillPower,
    int? fillSpeed,
  }) =>
      LaserSettings(
        laserMode: laserMode ?? this.laserMode,
        sMax: sMax ?? this.sMax,
        laserSpotSize: laserSpotSize ?? this.laserSpotSize,
        engravePower: engravePower ?? this.engravePower,
        engraveSpeed: engraveSpeed ?? this.engraveSpeed,
        cutPower: cutPower ?? this.cutPower,
        cutSpeed: cutSpeed ?? this.cutSpeed,
        fillPower: fillPower ?? this.fillPower,
        fillSpeed: fillSpeed ?? this.fillSpeed,
      );

  Map<String, Object> toMap() => {
        'laserMode': laserMode.name,
        'sMax': sMax,
        'laserSpotSize': laserSpotSize,
        'engravePower': engravePower,
        'engraveSpeed': engraveSpeed,
        'cutPower': cutPower,
        'cutSpeed': cutSpeed,
        'fillPower': fillPower,
        'fillSpeed': fillSpeed,
      };

  factory LaserSettings.fromMap(Map<String, Object?> map) => LaserSettings(
        laserMode: LaserMode.values.firstWhere(
          (m) => m.name == map['laserMode'],
          orElse: () => LaserMode.constant,
        ),
        sMax: map['sMax'] as int? ?? 1000,
        laserSpotSize: map['laserSpotSize'] as double? ?? 0.1,
        engravePower: map['engravePower'] as int? ?? 60,
        engraveSpeed: map['engraveSpeed'] as int? ?? 3000,
        cutPower: map['cutPower'] as int? ?? 100,
        cutSpeed: map['cutSpeed'] as int? ?? 800,
        fillPower: map['fillPower'] as int? ?? 80,
        fillSpeed: map['fillSpeed'] as int? ?? 3000,
      );
}
```

- [ ] **Step 6: Create `lib/machines/mill/mill_settings.dart`**

```dart
import 'dart:math' as math;

/// CNC mill settings: spindle, tool geometry, Z safety motion and the
/// per-operation defaults. Feed rates are in mm/s.
class MillSettings {
  final int maxSpindleSpeed;
  final double maxFeedRate;
  final double toolDiameter;
  final double bladeAngle;
  final double safeHeight;
  final double travelFeedRate;
  final int engraveSpindleSpeed;
  final double engraveFeedRate;
  final int cutSpindleSpeed;
  final double cutFeedRate;
  final int fillSpindleSpeed;
  final double fillFeedRate;

  const MillSettings({
    this.maxSpindleSpeed = 1000,
    this.maxFeedRate = 10.0,
    this.toolDiameter = 2.0,
    this.bladeAngle = 30.0,
    this.safeHeight = 5.0,
    this.travelFeedRate = 25.0,
    this.engraveSpindleSpeed = 12000,
    this.engraveFeedRate = 20.0,
    this.cutSpindleSpeed = 18000,
    this.cutFeedRate = 30.0,
    this.fillSpindleSpeed = 18000,
    this.fillFeedRate = 50.0,
  });

  /// Tool diameter (mm) at [cutDepthMm] below the surface. A 180° (straight)
  /// bit stays at its nominal diameter; a narrower Included angle is a cone,
  /// so the diameter at the tip is smaller than the nominal (widest) one.
  double effectiveDiameterAt(double cutDepthMm) {
    if (bladeAngle >= 179.99) return toolDiameter;
    final halfAngle = bladeAngle / 2 * math.pi / 180;
    final atDepth = 2 * cutDepthMm.abs() * math.tan(halfAngle);
    return atDepth.clamp(0.0, toolDiameter);
  }

  MillSettings copyWith({
    int? maxSpindleSpeed,
    double? maxFeedRate,
    double? toolDiameter,
    double? bladeAngle,
    double? safeHeight,
    double? travelFeedRate,
    int? engraveSpindleSpeed,
    double? engraveFeedRate,
    int? cutSpindleSpeed,
    double? cutFeedRate,
    int? fillSpindleSpeed,
    double? fillFeedRate,
  }) =>
      MillSettings(
        maxSpindleSpeed: maxSpindleSpeed ?? this.maxSpindleSpeed,
        maxFeedRate: maxFeedRate ?? this.maxFeedRate,
        toolDiameter: toolDiameter ?? this.toolDiameter,
        bladeAngle: bladeAngle ?? this.bladeAngle,
        safeHeight: safeHeight ?? this.safeHeight,
        travelFeedRate: travelFeedRate ?? this.travelFeedRate,
        engraveSpindleSpeed: engraveSpindleSpeed ?? this.engraveSpindleSpeed,
        engraveFeedRate: engraveFeedRate ?? this.engraveFeedRate,
        cutSpindleSpeed: cutSpindleSpeed ?? this.cutSpindleSpeed,
        cutFeedRate: cutFeedRate ?? this.cutFeedRate,
        fillSpindleSpeed: fillSpindleSpeed ?? this.fillSpindleSpeed,
        fillFeedRate: fillFeedRate ?? this.fillFeedRate,
      );

  Map<String, Object> toMap() => {
        'maxSpindleSpeed': maxSpindleSpeed,
        'maxFeedRate': maxFeedRate,
        'toolDiameter': toolDiameter,
        'bladeAngle': bladeAngle,
        'safeHeight': safeHeight,
        'travelFeedRate': travelFeedRate,
        'engraveSpindleSpeed': engraveSpindleSpeed,
        'engraveFeedRate': engraveFeedRate,
        'cutSpindleSpeed': cutSpindleSpeed,
        'cutFeedRate': cutFeedRate,
        'fillSpindleSpeed': fillSpindleSpeed,
        'fillFeedRate': fillFeedRate,
      };

  /// Missing entries fall back to realistic first-run values (a 24000 RPM
  /// router, 3000 feed, 1/8" bit) — intentionally different from the
  /// constructor's conservative placeholders for those three fields.
  factory MillSettings.fromMap(Map<String, Object?> map) => MillSettings(
        maxSpindleSpeed: map['maxSpindleSpeed'] as int? ?? 24000,
        maxFeedRate: map['maxFeedRate'] as double? ?? 3000.0,
        toolDiameter: map['toolDiameter'] as double? ?? 3.175,
        bladeAngle: map['bladeAngle'] as double? ?? 30.0,
        safeHeight: map['safeHeight'] as double? ?? 5.0,
        travelFeedRate: map['travelFeedRate'] as double? ?? 25.0,
        engraveSpindleSpeed: map['engraveSpindleSpeed'] as int? ?? 12000,
        engraveFeedRate: map['engraveFeedRate'] as double? ?? 20.0,
        cutSpindleSpeed: map['cutSpindleSpeed'] as int? ?? 18000,
        cutFeedRate: map['cutFeedRate'] as double? ?? 30.0,
        fillSpindleSpeed: map['fillSpindleSpeed'] as int? ?? 18000,
        fillFeedRate: map['fillFeedRate'] as double? ?? 50.0,
      );
}
```

- [ ] **Step 7: Create `lib/machines/machine_settings.dart` and delete the old file**

```dart
import '../models/layer_settings.dart';
import 'common_settings.dart';
import 'laser/laser_settings.dart';
import 'machine_mode.dart';
import 'mill/mill_settings.dart';

/// All machine configuration: the active [machineType] plus the settings of
/// every mode, so switching modes never loses the other mode's values.
class MachineSettings {
  final MachineType machineType;
  final CommonSettings common;
  final LaserSettings laser;
  final MillSettings mill;

  const MachineSettings({
    this.machineType = MachineType.laser,
    this.common = const CommonSettings(),
    this.laser = const LaserSettings(),
    this.mill = const MillSettings(),
  });

  // Temporary — replaced by GcodeStrategy (removed in Task 5).
  double effectiveDiameterAt(double cutDepthMm) =>
      machineType == MachineType.laser
          ? laser.laserSpotSize
          : mill.effectiveDiameterAt(cutDepthMm);

  // Temporary — replaced by GcodeStrategy (removed in Task 5).
  double cutOffsetDeltaFor(LayerSettings s) {
    final effDiam = effectiveDiameterAt(s.cutDepthMm);
    return switch (s.cutSide) {
      CutSide.line => 0.0,
      CutSide.outer => effDiam / 2,
      CutSide.inner => -effDiam / 2,
    };
  }

  MachineSettings copyWith({
    MachineType? machineType,
    CommonSettings? common,
    LaserSettings? laser,
    MillSettings? mill,
  }) =>
      MachineSettings(
        machineType: machineType ?? this.machineType,
        common: common ?? this.common,
        laser: laser ?? this.laser,
        mill: mill ?? this.mill,
      );

  /// Flat, storage-agnostic map (enums as their [.name]) with the same keys
  /// the app has always persisted — see [SettingsService].
  Map<String, Object> toMap() => {
        'machineType': machineType.name,
        ...common.toMap(),
        ...laser.toMap(),
        ...mill.toMap(),
      };

  /// Reconstructs settings from a map produced by [toMap] (or, for a fresh
  /// install, an empty map). Missing entries fall back to each part's
  /// `fromMap` defaults.
  factory MachineSettings.fromMap(Map<String, Object?> map) => MachineSettings(
        machineType: MachineType.values.firstWhere(
          (m) => m.name == map['machineType'],
          orElse: () => MachineType.laser,
        ),
        common: CommonSettings.fromMap(map),
        laser: LaserSettings.fromMap(map),
        mill: MillSettings.fromMap(map),
      );
}
```

Then: `git rm lib/models/machine_settings.dart`

- [ ] **Step 8: Update consumers (field access)**

Apply exactly these replacements. Imports: replace every `models/machine_settings.dart` import with `machines/machine_settings.dart` (same relative depth adjusted). Add `machines/machine_mode.dart` where `MachineType` is used and `machines/laser/laser_settings.dart` where `LaserMode`/`LaserSettings` is used.

`lib/services/gcode_generator.dart`:
- `settings.laserSpotSize` → `settings.laser.laserSpotSize`
- `settings.travelFeedRate` → `settings.mill.travelFeedRate` (2×)
- `settings.safeHeight` → `settings.mill.safeHeight` (all)
- `settings.laserMode.gcode` → `settings.laser.laserMode.gcode` (all)
- `_sMaxFor` body → `settings.machineType == MachineType.mill ? settings.mill.maxSpindleSpeed : settings.laser.sMax`

`lib/services/toolpath.dart`: `machineSettings.laserSpotSize` → `machineSettings.laser.laserSpotSize`

`lib/services/grbl_mock_service.dart`: `machineSettings.laserSpotSize` → `machineSettings.laser.laserSpotSize`

`lib/services/gcode_templates.dart`:
- the parameter type `MachineSettings s` → `LaserSettings s` in all three methods (bodies unchanged: `s.sMax`, `s.laserSpotSize`, `s.laserMode` exist on `LaserSettings`),
- import `../machines/laser/laser_settings.dart` instead of `machine_settings.dart`.

`lib/models/machine_mode_profile.dart`, `defaultSpeedMmS`:
- `s.engraveSpeed` → `s.laser.engraveSpeed`, `s.cutSpeed` → `s.laser.cutSpeed`, `s.fillSpeed` → `s.laser.fillSpeed`,
- `s.engraveFeedRate` → `s.mill.engraveFeedRate`, `s.cutFeedRate` → `s.mill.cutFeedRate`, `s.fillFeedRate` → `s.mill.fillFeedRate`,
- import `../machines/machine_mode.dart` and `../machines/machine_settings.dart`.

`lib/widgets/layer_settings_panel.dart`:
- `ms.engravePower` → `ms.laser.engravePower`, `ms.cutPower` → `ms.laser.cutPower`, `ms.fillPower` → `ms.laser.fillPower`,
- `widget.machineSettings.laserSpotSize` → `widget.machineSettings.laser.laserSpotSize` (both occurrences).

`lib/widgets/left_panel.dart`: `widget.machineSettings.laserSpotSize` → `widget.machineSettings.laser.laserSpotSize`

`lib/screens/home/home_screen.dart`:
- `_machineSettings.engravePower` → `_machineSettings.laser.engravePower` (3×),
- `_machineSettings.engraveSpeed` → `_machineSettings.laser.engraveSpeed` (3×),
- `_machineSettings.defaultBaudRate` → `_machineSettings.common.defaultBaudRate`,
- in `_startTestJob`: `GcodeTemplates.xTest(config, _machineSettings)` → `GcodeTemplates.xTest(config, _machineSettings.laser)` (3×).

`lib/widgets/machine_settings_dialog.dart`:
- in `initState`, read `s.laser.laserMode`, `s.laser.sMax`, `s.laser.laserSpotSize`, `s.laser.engravePower`, `s.laser.engraveSpeed`, `s.laser.cutPower`, `s.laser.cutSpeed`, `s.laser.fillPower`, `s.laser.fillSpeed`, `s.mill.<each mill field>`, `s.common.defaultBaudRate`,
- replace `_buildResult` with:

```dart
  MachineSettings _buildResult() {
    final cur = widget.current;
    final spot = double.tryParse(_spotCtrl.text.replaceAll(',', '.')) ??
        cur.laser.laserSpotSize;
    final sMax = int.tryParse(_sMaxCtrl.text.trim()) ?? cur.laser.sMax;
    final m = cur.mill;
    return cur.copyWith(
      common: CommonSettings(defaultBaudRate: _baudRate),
      laser: LaserSettings(
        laserMode: _laserMode,
        sMax: sMax.clamp(1, 100000),
        laserSpotSize: spot.clamp(0.01, 10.0),
        engravePower: _engravePower.round(),
        engraveSpeed: (_parseSpeed(_engraveSpeedCtrl) ?? cur.laser.engraveSpeed)
            .clamp(_kSpeedMin, _kSpeedMax),
        cutPower: _cutPower.round(),
        cutSpeed: (_parseSpeed(_cutSpeedCtrl) ?? cur.laser.cutSpeed)
            .clamp(_kSpeedMin, _kSpeedMax),
        fillPower: _fillPower.round(),
        fillSpeed: (_parseSpeed(_fillSpeedCtrl) ?? cur.laser.fillSpeed)
            .clamp(_kSpeedMin, _kSpeedMax),
      ),
      mill: MillSettings(
        maxSpindleSpeed: (_parsePositiveInt(_maxSpindleSpeedCtrl) ?? m.maxSpindleSpeed).clamp(1, 1000000),
        maxFeedRate: (_parsePositiveDouble(_maxFeedRateCtrl) ?? m.maxFeedRate).clamp(0.1, 100000.0),
        toolDiameter: (_parsePositiveDouble(_toolDiamCtrl) ?? m.toolDiameter).clamp(0.1, 100.0),
        bladeAngle: (_parsePositiveDouble(_bladeAngleCtrl) ?? m.bladeAngle).clamp(1.0, 180.0),
        safeHeight: (_parsePositiveDouble(_safeHeightCtrl) ?? m.safeHeight).clamp(0.1, 500.0),
        travelFeedRate: (_parsePositiveDouble(_travelFeedRateCtrl) ?? m.travelFeedRate).clamp(1.0, 100000.0),
        engraveSpindleSpeed: (_parsePositiveInt(_engraveSpindleCtrl) ?? m.engraveSpindleSpeed).clamp(1, 1000000),
        engraveFeedRate: (_parsePositiveDouble(_engraveFeedCtrl) ?? m.engraveFeedRate).clamp(0.1, 10000.0),
        cutSpindleSpeed: (_parsePositiveInt(_cutSpindleCtrl) ?? m.cutSpindleSpeed).clamp(1, 1000000),
        cutFeedRate: (_parsePositiveDouble(_cutFeedCtrl) ?? m.cutFeedRate).clamp(0.1, 10000.0),
        fillSpindleSpeed: (_parsePositiveInt(_fillSpindleCtrl) ?? m.fillSpindleSpeed).clamp(1, 1000000),
        fillFeedRate: (_parsePositiveDouble(_fillFeedCtrl) ?? m.fillFeedRate).clamp(0.1, 10000.0),
      ),
    );
  }
```

(The clamp bounds and fallbacks are copied 1:1 from the current `_buildResult`.)

`lib/services/grbl_service.dart`, `grbl_serial_service.dart`, `settings_service.dart`, `lib/widgets/main_app_bar.dart`, `right_panel.dart`: import changes only.

- [ ] **Step 9: Update test construction syntax (goldens untouched)**

- `test/gcode_regression_test.dart`:
  - `const MachineSettings(laserMode: LaserMode.variable, sMax: 255, laserSpotSize: 0.2)` → `const MachineSettings(laser: LaserSettings(laserMode: LaserMode.variable, sMax: 255, laserSpotSize: 0.2))`
  - `const MachineSettings(machineType: MachineType.mill, bladeAngle: 60)` → `const MachineSettings(machineType: MachineType.mill, mill: MillSettings(bladeAngle: 60))`
  - the mill-flat settings → `const MachineSettings(machineType: MachineType.mill, laser: LaserSettings(laserMode: LaserMode.variable), mill: MillSettings(maxSpindleSpeed: 24000, toolDiameter: 6.0, bladeAngle: 180.0, safeHeight: 3.0, travelFeedRate: 40.0))`
  - templates: second argument `const MachineSettings()` → `const LaserSettings()`, and `const MachineSettings(laserMode: LaserMode.variable, sMax: 255)` → `const LaserSettings(laserMode: LaserMode.variable, sMax: 255)`
- `test/toolpath_regression_test.dart`: mill settings → `const MachineSettings(machineType: MachineType.mill, mill: MillSettings(bladeAngle: 60))`
- All tests: imports `package:easy_grbl/models/machine_settings.dart` → `package:easy_grbl/machines/machine_settings.dart`, plus `machines/machine_mode.dart`, `machines/laser/laser_settings.dart`, `machines/mill/mill_settings.dart` where used.

- [ ] **Step 10: Run analyzer and tests**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`; all tests pass except `test/widget_test.dart`. All goldens unchanged.

- [ ] **Step 11: Report** (no commit)

---

### Task 2: Move files into `machines/` and `geometry/`

Pure moves, the profile split and one class rename. No logic changes.

**Files:**
- Modify: `lib/machines/machine_mode.dart` (add abstract profile + extension)
- Create: `lib/machines/laser/laser_mode_profile.dart`, `lib/machines/mill/mill_mode_profile.dart`
- Delete: `lib/models/machine_mode_profile.dart`
- Move (git mv):

| From | To |
|---|---|
| `lib/services/affine.dart` | `lib/geometry/affine.dart` |
| `lib/services/path_offset.dart` | `lib/geometry/path_offset.dart` |
| `lib/services/svg_node_walker.dart` | `lib/geometry/svg_node_walker.dart` |
| `lib/services/svg_transform.dart` | `lib/geometry/svg_transform.dart` |
| `lib/services/gcode_generator.dart` | `lib/machines/gcode/gcode_generator.dart` |
| `lib/services/gcode_templates.dart` | `lib/machines/laser/templates/laser_gcode_templates.dart` |
| `lib/models/focus_test_config.dart` | `lib/machines/laser/templates/focus_test.dart` |
| `lib/models/kerf_test_config.dart` | `lib/machines/laser/templates/kerf_test.dart` |
| `lib/models/spot_test_config.dart` | `lib/machines/laser/templates/spot_test.dart` |
| `lib/models/test_session.dart` | `lib/machines/laser/templates/test_session.dart` |
| `lib/widgets/test_panel_common.dart` | `lib/machines/laser/templates/widgets/test_panel_common.dart` |
| `lib/widgets/focus_test_panel.dart` | `lib/machines/laser/templates/widgets/focus_test_panel.dart` |
| `lib/widgets/kerf_test_panel.dart` | `lib/machines/laser/templates/widgets/kerf_test_panel.dart` |
| `lib/widgets/spot_test_panel.dart` | `lib/machines/laser/templates/widgets/spot_test_panel.dart` |

**Interfaces:**
- Produces:
  - `abstract class MachineModeProfile` and `extension MachineTypeProfile on MachineType { MachineModeProfile get profile }` in `lib/machines/machine_mode.dart`,
  - `LaserModeProfile`, `MillModeProfile` in their mode directories,
  - class `LaserGcodeTemplates` (renamed from `GcodeTemplates`; same static methods `focusTest`, `kerfTest`, `spotTest`).

- [ ] **Step 1: Split the mode profile**

Replace `lib/machines/machine_mode.dart` with:

```dart
import 'package:flutter/material.dart';
import '../models/operation_type.dart';
import 'laser/laser_mode_profile.dart';
import 'machine_settings.dart';
import 'mill/mill_mode_profile.dart';

/// The app's working mode. Persisted as [MachineSettings.machineType].
enum MachineType { laser, mill }

/// UI-facing facts about the app's working mode (Laser engraver / CNC mill):
/// how the mode is named and which mode-dependent controls are shown. Widgets
/// ask the profile instead of comparing [MachineType] directly.
///
/// G-code differences live in GcodeStrategy, not here.
abstract class MachineModeProfile {
  const MachineModeProfile();

  String get displayName;
  String get badgeLabel;
  IconData get icon;

  /// Whether the laser test templates (Focus / Kerf / Spot Size) apply.
  bool get supportsTemplates;

  /// Whether Cut layers expose a cut depth (real Z motion).
  bool get showsCutDepth;

  /// Default layer speed (mm/s) applied when an operation is picked.
  double defaultSpeedMmS(OperationType op, MachineSettings settings);
}

extension MachineTypeProfile on MachineType {
  MachineModeProfile get profile => switch (this) {
        MachineType.laser => const LaserModeProfile(),
        MachineType.mill => const MillModeProfile(),
      };
}
```

Create `lib/machines/laser/laser_mode_profile.dart`:

```dart
import 'package:flutter/material.dart';
import '../../models/operation_type.dart';
import '../machine_mode.dart';
import '../machine_settings.dart';

class LaserModeProfile extends MachineModeProfile {
  const LaserModeProfile();

  @override
  String get displayName => 'Laser engraver';
  @override
  String get badgeLabel => 'LASER ENGRAVER';
  @override
  IconData get icon => Icons.flare;
  @override
  bool get supportsTemplates => true;
  @override
  bool get showsCutDepth => false;

  // Laser defaults are stored in mm/min.
  @override
  double defaultSpeedMmS(OperationType op, MachineSettings s) => switch (op) {
        OperationType.engrave => s.laser.engraveSpeed / 60.0,
        OperationType.cut => s.laser.cutSpeed / 60.0,
        OperationType.fill => s.laser.fillSpeed / 60.0,
        OperationType.skip => 0,
      };
}
```

Create `lib/machines/mill/mill_mode_profile.dart`:

```dart
import 'package:flutter/material.dart';
import '../../models/operation_type.dart';
import '../machine_mode.dart';
import '../machine_settings.dart';

class MillModeProfile extends MachineModeProfile {
  const MillModeProfile();

  @override
  String get displayName => 'CNC mill';
  @override
  String get badgeLabel => 'CNC MILL';
  @override
  IconData get icon => Icons.precision_manufacturing_outlined;
  @override
  bool get supportsTemplates => false;
  @override
  bool get showsCutDepth => true;

  // Mill feed rates are stored in mm/s.
  @override
  double defaultSpeedMmS(OperationType op, MachineSettings s) => switch (op) {
        OperationType.engrave => s.mill.engraveFeedRate,
        OperationType.cut => s.mill.cutFeedRate,
        OperationType.fill => s.mill.fillFeedRate,
        OperationType.skip => 0,
      };
}
```

Then `git rm lib/models/machine_mode_profile.dart`.

- [ ] **Step 2: Write the move + import-rewrite script**

Create `<scratchpad>/move_dart.py` (scratchpad = session scratchpad directory):

```python
#!/usr/bin/env python3
"""git-mv Dart files and rewrite every import that pointed at them."""
import os
import re
import subprocess

ROOT = '/home/projects/mmalessa/easy-grbl'
MOVES = {
    'lib/services/affine.dart': 'lib/geometry/affine.dart',
    'lib/services/path_offset.dart': 'lib/geometry/path_offset.dart',
    'lib/services/svg_node_walker.dart': 'lib/geometry/svg_node_walker.dart',
    'lib/services/svg_transform.dart': 'lib/geometry/svg_transform.dart',
    'lib/services/gcode_generator.dart': 'lib/machines/gcode/gcode_generator.dart',
    'lib/services/gcode_templates.dart': 'lib/machines/laser/templates/laser_gcode_templates.dart',
    'lib/models/focus_test_config.dart': 'lib/machines/laser/templates/focus_test.dart',
    'lib/models/kerf_test_config.dart': 'lib/machines/laser/templates/kerf_test.dart',
    'lib/models/spot_test_config.dart': 'lib/machines/laser/templates/spot_test.dart',
    'lib/models/test_session.dart': 'lib/machines/laser/templates/test_session.dart',
    'lib/widgets/test_panel_common.dart': 'lib/machines/laser/templates/widgets/test_panel_common.dart',
    'lib/widgets/focus_test_panel.dart': 'lib/machines/laser/templates/widgets/focus_test_panel.dart',
    'lib/widgets/kerf_test_panel.dart': 'lib/machines/laser/templates/widgets/kerf_test_panel.dart',
    'lib/widgets/spot_test_panel.dart': 'lib/machines/laser/templates/widgets/spot_test_panel.dart',
}
# Deleted files whose importers must point somewhere else.
REDIRECTS = {
    'lib/models/machine_mode_profile.dart': 'lib/machines/machine_mode.dart',
}

os.chdir(ROOT)
for old, new in MOVES.items():
    os.makedirs(os.path.dirname(new), exist_ok=True)
    subprocess.run(['git', 'mv', old, new], check=True)

target = {**MOVES, **REDIRECTS}
old_of = {new: old for old, new in MOVES.items()}
IMPORT = re.compile(r"^(import|export) '([^']+)'(.*);$", re.M)
PKG = 'package:easy_grbl/'

for base in ('lib', 'test'):
    for dirpath, _, files in os.walk(base):
        for name in files:
            if not name.endswith('.dart'):
                continue
            path = os.path.join(dirpath, name)
            orig_dir = os.path.dirname(old_of.get(path, path))
            src = open(path).read()

            def fix(m):
                kw, uri, rest = m.groups()
                if uri.startswith('dart:'):
                    return m.group(0)
                if uri.startswith(PKG):
                    t = 'lib/' + uri[len(PKG):]
                    return f"{kw} '{PKG}{target.get(t, t)[len('lib/'):]}'{rest};"
                if uri.startswith('package:'):
                    return m.group(0)
                t = os.path.normpath(os.path.join(orig_dir, uri))
                t = target.get(t, t)
                rel = os.path.relpath(t, os.path.dirname(path))
                return f"{kw} '{rel}'{rest};"

            out, seen = [], set()
            for line in IMPORT.sub(fix, src).split('\n'):
                if IMPORT.match(line):
                    if line in seen:
                        continue  # duplicate created by a redirect
                    seen.add(line)
                out.append(line)
            new_src = '\n'.join(out)
            if new_src != src:
                open(path, 'w').write(new_src)
                print('rewrote', path)
```

- [ ] **Step 3: Run the script**

Run: `python3 <scratchpad>/move_dart.py`
Expected: 14 `git mv` operations succeed, followed by a list of `rewrote …` lines.

- [ ] **Step 4: Rename `GcodeTemplates` → `LaserGcodeTemplates`**

Run:
```bash
cd /home/projects/mmalessa/easy-grbl
sed -i 's/\bGcodeTemplates\b/LaserGcodeTemplates/g' \
  lib/machines/laser/templates/laser_gcode_templates.dart \
  lib/screens/home/home_screen.dart \
  test/gcode_regression_test.dart
grep -rn "GcodeTemplates" lib test | grep -v LaserGcodeTemplates
```
Expected: the final grep prints nothing.

- [ ] **Step 5: Run analyzer and tests**

Run: `dart format --output=none --set-exit-if-changed lib/machines/machine_mode.dart lib/machines/*/[a-z]*_mode_profile.dart; flutter analyze && flutter test`
Expected: `No issues found!`; tests pass (except `widget_test.dart`); goldens unchanged. `ls lib/models` now shows only `job_state, layer_settings, machine_state, operation_type, svg_document, svg_node, svg_node_type`.

- [ ] **Step 6: Report** (no commit)

---

### Task 3: Shared geometry (fill lines + contour sampler)

**Files:**
- Create: `lib/geometry/fill_lines.dart`, `lib/geometry/contour_sampler.dart`
- Modify:
  - `lib/machines/gcode/gcode_generator.dart`: remove `computeFillLines`, `_crossingsX`, `_crossingsY`, `computeActiveBounds`; use the sampler in `_pathToGcode`,
  - `lib/services/toolpath.dart`: use `computeFillLines` and `sampleContours`,
  - `lib/services/grbl_mock_service.dart`: use `computeFillLines`.
- Test: `test/geometry_test.dart`

**Interfaces:**
- Produces:
  - `List<(Offset, Offset)> computeFillLines(Path path, FillDirection direction, double linesPerMm, {double inset = 0.0})`,
  - `List<List<Offset>> sampleContours(String pathData, {required double step, required double minDistSq, required Offset Function(Offset) map})`.

- [ ] **Step 1: Write the failing tests**

Create `test/geometry_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/geometry/contour_sampler.dart';
import 'package:easy_grbl/geometry/fill_lines.dart';
import 'package:easy_grbl/models/layer_settings.dart';

void main() {
  group('sampleContours', () {
    test('samples every step plus the end, without duplicates', () {
      final c = sampleContours('M 0,0 L 1,0',
          step: 0.5, minDistSq: 1e-6, map: (p) => p);
      expect(c, [
        [const Offset(0, 0), const Offset(0.5, 0), const Offset(1, 0)],
      ]);
    });

    test('applies the mapping', () {
      final c = sampleContours('M 0,0 L 1,0',
          step: 1, minDistSq: 1e-6, map: (p) => Offset(p.dx + 10, -p.dy));
      expect(c.single.first, const Offset(10, 0));
    });

    test('one list per contour; unparseable data yields none', () {
      final two = sampleContours('M 0,0 L 1,0 M 5,5 L 6,5',
          step: 1, minDistSq: 1e-6, map: (p) => p);
      expect(two.length, 2);
      expect(sampleContours('not a path',
          step: 1, minDistSq: 1e-6, map: (p) => p), isEmpty);
    });
  });

  test('computeFillLines hatches a square boustrophedon-style', () {
    final square = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
    final lines = computeFillLines(square, FillDirection.horizontal, 1);
    expect(lines.length, 10);
    expect(lines.first.$1.dy, 0.5);
    expect(lines.first.$1.dx, lessThan(lines.first.$2.dx));
    expect(lines[1].$1.dx, greaterThan(lines[1].$2.dx));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/geometry_test.dart`
Expected: compilation failure (`geometry/contour_sampler.dart` not found).

- [ ] **Step 3: Create `lib/geometry/fill_lines.dart`**

Move `computeFillLines`, `_crossingsX`, `_crossingsY` out of `GcodeGenerator` verbatim, as top-level functions. The only changes: drop `static`, and rename the sampling constant to `_sampleStep`:

```dart
import 'dart:ui';
import '../models/layer_settings.dart';

const double _sampleStep = 0.1; // mm per sample along contour edges

/// Computes fill line segments in SVG space using scanline intersection.
/// Returns pairs (start, end) in alternating directions (boustrophedon).
/// Handles compound paths (e.g. shapes with holes) correctly via even-odd rule.
///
/// [inset] shrinks each line segment by this amount on both ends and narrows
/// the scanline band accordingly — use spotSize/2 to avoid double-burning
/// when an outline pass is also generated.
List<(Offset, Offset)> computeFillLines(
  Path path,
  FillDirection direction,
  double linesPerMm, {
  double inset = 0.0,
}) {
  // … body copied verbatim from GcodeGenerator.computeFillLines,
  //   with `_step` replaced by `_sampleStep` …
}

/// Finds all X intersections of a horizontal scanline at [y] with [contours].
List<double> _crossingsX(List<List<Offset>> contours, double y) {
  // … verbatim …
}

/// Finds all Y intersections of a vertical scanline at [x] with [contours].
List<double> _crossingsY(List<List<Offset>> contours, double x) {
  // … verbatim …
}
```

(The bodies are the exact current code from `lib/machines/gcode/gcode_generator.dart`. Copy-paste them without edits other than `_step` → `_sampleStep`.)

- [ ] **Step 4: Create `lib/geometry/contour_sampler.dart`**

```dart
import 'dart:ui';
import 'package:path_drawing/path_drawing.dart';

/// Samples every contour of [pathData] every [step] mm (plus its end point),
/// maps each sample through [map] and drops a point when it is within
/// sqrt([minDistSq]) of the previous kept one. Contours shorter than
/// 0.001 mm or with fewer than two kept points are skipped; unparseable path
/// data yields no contours.
List<List<Offset>> sampleContours(
  String pathData, {
  required double step,
  required double minDistSq,
  required Offset Function(Offset) map,
}) {
  final Path path;
  try {
    path = parseSvgPathData(pathData);
  } catch (_) {
    return const [];
  }
  final contours = <List<Offset>>[];
  for (final metric in path.computeMetrics()) {
    if (metric.length < 0.001) continue;
    final pts = <Offset>[];
    void add(Tangent? t) {
      if (t == null) return;
      final p = map(t.position);
      if (pts.isEmpty || (p - pts.last).distanceSquared > minDistSq) pts.add(p);
    }

    for (var d = 0.0; d <= metric.length; d += step) {
      add(metric.getTangentForOffset(d));
    }
    add(metric.getTangentForOffset(metric.length));
    if (pts.length >= 2) contours.add(pts);
  }
  return contours;
}
```

- [ ] **Step 5: Use the geometry in the generator**

In `lib/machines/gcode/gcode_generator.dart`:
- delete `computeFillLines`, `_crossingsX`, `_crossingsY`, and `computeActiveBounds` together with its `// ── Bounds` header (no callers: `grep -rn computeActiveBounds lib test` is empty),
- add imports `../../geometry/contour_sampler.dart` and `../../geometry/fill_lines.dart`,
- in `_fillToGcode`, `computeFillLines(...)` now resolves to the top-level function (no change in the call),
- in `_pathToGcode`, replace everything from `final metrics = path.computeMetrics();` up to and including the `if (offsetDeltaMm != 0) { … }` block with:

```dart
    final sMax = _sMaxFor(settings);
    final sPower = (powerPct / 100.0 * sMax).round().clamp(0, sMax);
    final travelF = (settings.mill.travelFeedRate * 60).round(); // mm/s -> mm/min
    final contours = sampleContours(pathData, step: _step, minDistSq: 1e-6,
        map: (p) {
      final tp = xform.apply(p);
      return Offset(tp.dx - vb.left, vb.bottom - tp.dy);
    });

    for (var pts in contours) {
      if (offsetDeltaMm != 0) {
        pts = PathOffset.offsetClosedContour(pts, offsetDeltaMm);
      }
```

and delete the now-unused `final Path path; try { path = parseSvgPathData(pathData); } catch (_) { return; }` at the top of `_pathToGcode`. The loop body from `buf.writeln('M5 S0');` onward stays unchanged.

- [ ] **Step 6: Use the geometry in toolpath and mock**

`lib/services/toolpath.dart`:
- `GcodeGenerator.computeFillLines(` → `computeFillLines(`,
- import `../geometry/fill_lines.dart` and `../geometry/contour_sampler.dart`; remove the `gcode_generator.dart` import,
- replace `_samplePath`'s body with:

```dart
  for (var pts in sampleContours(pathData,
      step: _step, minDistSq: 0.04, map: xform.apply)) {
    if (offsetDeltaMm != 0) {
      pts = PathOffset.offsetClosedContour(pts, offsetDeltaMm);
    }
    addContour(pts, color);
  }
```

- remove the `path_drawing` import if `parseSvgPathData` is no longer used there (`_sampleFill` still uses it, so it most likely stays).

`lib/services/grbl_mock_service.dart`:
- `GcodeGenerator.computeFillLines(` → `computeFillLines(`,
- import `../geometry/fill_lines.dart`; remove the `gcode_generator.dart` import.

- [ ] **Step 7: Run analyzer and tests**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`. `geometry_test.dart` passes, and every G-code and toolpath golden stays unchanged. A golden diff means the sampler call does not reproduce the original loop. Fix the call, never the golden.

- [ ] **Step 8: Report** (no commit)

---

### Task 4: G-code skeleton + Laser/Mill strategies

**Files:**
- Create: `lib/machines/gcode/gcode_strategy.dart`
- Create: `lib/machines/laser/laser_gcode_strategy.dart`
- Create: `lib/machines/mill/mill_gcode_strategy.dart`
- Rewrite: `lib/machines/gcode/gcode_generator.dart`
- Test: `test/gcode_strategy_test.dart`

**Interfaces:**
- Consumes: `sampleContours`, `computeFillLines` (Task 3); `LaserSettings`, `MillSettings`, `MachineSettings` (Task 1).
- Produces:
  - `abstract class GcodeStrategy` with:
    - `factory GcodeStrategy.of(MachineSettings)`,
    - `int get sMax`,
    - `String get spindleOnCode`,
    - `double effectiveDiameterAt(double cutDepthMm)`,
    - `double cutOffsetDelta(LayerSettings s)`,
    - `double fillInset(LayerSettings s)`,
    - `double? plungeDepth(OperationType op, LayerSettings s)`,
    - `void writeContourStart(StringBuffer buf, Offset start, int sPower, double? plungeDepth)`,
    - `void writeContourEnd(StringBuffer buf, double? plungeDepth)`,
    - `void writeFooterMoves(StringBuffer buf)`;
  - `LaserGcodeStrategy(LaserSettings settings)`;
  - `MillGcodeStrategy(MillSettings settings, {required LaserMode laserMode, required double laserSpotSize})`;
  - `GcodeGenerator.generate(SvgDocument, String, MachineSettings)`, signature unchanged.

- [ ] **Step 1: Write the failing strategy tests**

Create `test/gcode_strategy_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/machines/gcode/gcode_strategy.dart';
import 'package:easy_grbl/machines/laser/laser_gcode_strategy.dart';
import 'package:easy_grbl/machines/laser/laser_settings.dart';
import 'package:easy_grbl/machines/machine_mode.dart';
import 'package:easy_grbl/machines/machine_settings.dart';
import 'package:easy_grbl/machines/mill/mill_gcode_strategy.dart';
import 'package:easy_grbl/machines/mill/mill_settings.dart';
import 'package:easy_grbl/models/layer_settings.dart';
import 'package:easy_grbl/models/operation_type.dart';

String _write(void Function(StringBuffer) f) {
  final b = StringBuffer();
  f(b);
  return b.toString();
}

void main() {
  test('GcodeStrategy.of picks the mode and passes borrowed laser values', () {
    const s = MachineSettings(
      machineType: MachineType.mill,
      laser: LaserSettings(laserMode: LaserMode.variable, laserSpotSize: 0.3),
    );
    final strategy = GcodeStrategy.of(s) as MillGcodeStrategy;
    expect(strategy.laserMode, LaserMode.variable);
    expect(strategy.laserSpotSize, 0.3);
    expect(GcodeStrategy.of(const MachineSettings()), isA<LaserGcodeStrategy>());
  });

  group('laser', () {
    const strategy = LaserGcodeStrategy(
        LaserSettings(sMax: 255, laserSpotSize: 0.2, laserMode: LaserMode.variable));

    test('scaling, offsets, no plunge', () {
      expect(strategy.sMax, 255);
      expect(strategy.spindleOnCode, 'M4');
      expect(strategy.cutOffsetDelta(LayerSettings(cutSide: CutSide.outer)), 0.1);
      expect(strategy.cutOffsetDelta(LayerSettings(cutSide: CutSide.inner)), -0.1);
      expect(strategy.fillInset(LayerSettings(fillOutline: true)), 0.1);
      expect(strategy.fillInset(LayerSettings(fillOutline: false)), 0.0);
      expect(strategy.plungeDepth(OperationType.cut, LayerSettings()), isNull);
    });

    test('contour start and footer', () {
      expect(
          _write((b) => strategy.writeContourStart(b, const Offset(1, 2), 128, null)),
          'G0 X1.000 Y2.000\nM4 S128\n');
      expect(_write((b) => strategy.writeContourEnd(b, null)), '');
      expect(_write(strategy.writeFooterMoves), 'G0 X0 Y0 Z0 ; HOME\n');
    });
  });

  group('mill', () {
    const strategy = MillGcodeStrategy(
      MillSettings(
          maxSpindleSpeed: 24000, toolDiameter: 6, bladeAngle: 90,
          safeHeight: 3, travelFeedRate: 10),
      laserMode: LaserMode.constant,
      laserSpotSize: 0.2,
    );

    test('scaling, V-bit offset, plunge only for cut', () {
      expect(strategy.sMax, 24000);
      expect(strategy.effectiveDiameterAt(1), closeTo(2, 1e-9));
      expect(
          strategy.cutOffsetDelta(
              LayerSettings(cutSide: CutSide.outer, cutDepthMm: 1)),
          closeTo(1, 1e-9));
      expect(strategy.fillInset(LayerSettings(fillOutline: true)), 0.1);
      expect(strategy.plungeDepth(OperationType.cut, LayerSettings(cutDepthMm: 2)), 2);
      expect(strategy.plungeDepth(OperationType.engrave, LayerSettings()), isNull);
    });

    test('plunging contour start/end and footer', () {
      expect(
          _write((b) => strategy.writeContourStart(b, const Offset(1, 2), 500, 1.5)),
          'G1 Z3.000 F600\nG1 X1.000 Y2.000 F600\nM3 S500\nG1 Z-1.500 F600\n');
      expect(_write((b) => strategy.writeContourEnd(b, 1.5)), 'G1 Z3.000 F600\n');
      expect(
          _write((b) => strategy.writeContourStart(b, const Offset(1, 2), 500, null)),
          'G0 X1.000 Y2.000\nM3 S500\n');
      expect(
          _write(strategy.writeFooterMoves),
          'G1 Z3.000 F600 ; retract to safe height\n'
          'G0 X0 Y0 ; XY HOME\n'
          'G1 Z0 F600 ; Z HOME\n');
    });
  });
}
```

Before running, confirm the number format by reading `lib/services/gcode_format.dart` (`formatGcodeNumber`). The goldens show `X5.000`, i.e. 3 decimals. If the format differs, adjust only the expected strings in this test.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/gcode_strategy_test.dart`
Expected: compilation failure (`gcode_strategy.dart` not found).

- [ ] **Step 3: Create `lib/machines/gcode/gcode_strategy.dart`**

```dart
import 'dart:ui';
import '../../models/layer_settings.dart';
import '../../models/operation_type.dart';
import '../laser/laser_gcode_strategy.dart';
import '../machine_mode.dart';
import '../machine_settings.dart';
import '../mill/mill_gcode_strategy.dart';

/// Everything about G-code that differs between working modes. The shared
/// skeleton lives in GcodeGenerator; the toolpath preview, the mock job
/// animation and Layer Settings use the same strategy so they always agree
/// with the generated G-code.
abstract class GcodeStrategy {
  const GcodeStrategy();

  factory GcodeStrategy.of(MachineSettings s) => switch (s.machineType) {
        MachineType.laser => LaserGcodeStrategy(s.laser),
        MachineType.mill => MillGcodeStrategy(
            s.mill,
            laserMode: s.laser.laserMode,
            laserSpotSize: s.laser.laserSpotSize,
          ),
      };

  /// Ceiling for `S<value>`: a layer's Power % maps to 0..[sMax].
  int get sMax;

  /// `M3`/`M4` — switches the laser or spindle on.
  String get spindleOnCode;

  /// Tool/spot diameter (mm) at [cutDepthMm] below the surface.
  double effectiveDiameterAt(double cutDepthMm);

  /// Signed XY offset (mm) for a Cut layer's toolpath: outer grows, inner
  /// shrinks, by half the effective diameter at the layer's cut depth.
  double cutOffsetDelta(LayerSettings s) {
    final d = effectiveDiameterAt(s.cutDepthMm);
    return switch (s.cutSide) {
      CutSide.line => 0.0,
      CutSide.outer => d / 2,
      CutSide.inner => -d / 2,
    };
  }

  /// How far fill lines stay away from the outline when an outline pass is
  /// also burned.
  double fillInset(LayerSettings s);

  /// Depth (mm, positive) to plunge to for [op], or null for no Z motion.
  double? plungeDepth(OperationType op, LayerSettings s);

  /// Written after a contour's leading `M5 S0`: move to [start] with the tool
  /// off and switch it on at [sPower], plunging to [plungeDepth] if given.
  void writeContourStart(
      StringBuffer buf, Offset start, int sPower, double? plungeDepth);

  /// Written after a contour's trailing `M5 S0`.
  void writeContourEnd(StringBuffer buf, double? plungeDepth);

  /// End-of-program moves back to the origin (before `M5`/`M2`).
  void writeFooterMoves(StringBuffer buf);
}
```

- [ ] **Step 4: Create `lib/machines/laser/laser_gcode_strategy.dart`**

```dart
import 'dart:ui';
import '../../models/layer_settings.dart';
import '../../models/operation_type.dart';
import '../../services/gcode_format.dart';
import '../gcode/gcode_strategy.dart';
import 'laser_settings.dart';

class LaserGcodeStrategy extends GcodeStrategy {
  final LaserSettings settings;

  const LaserGcodeStrategy(this.settings);

  @override
  int get sMax => settings.sMax;

  @override
  String get spindleOnCode => settings.laserMode.gcode;

  // A laser beam doesn't taper with depth.
  @override
  double effectiveDiameterAt(double cutDepthMm) => settings.laserSpotSize;

  @override
  double fillInset(LayerSettings s) =>
      s.fillOutline ? settings.laserSpotSize / 2 : 0.0;

  @override
  double? plungeDepth(OperationType op, LayerSettings s) => null;

  @override
  void writeContourStart(
      StringBuffer buf, Offset start, int sPower, double? plungeDepth) {
    buf.writeln('G0 X${formatGcodeNumber(start.dx)} Y${formatGcodeNumber(start.dy)}');
    buf.writeln('$spindleOnCode S$sPower');
  }

  @override
  void writeContourEnd(StringBuffer buf, double? plungeDepth) {}

  @override
  void writeFooterMoves(StringBuffer buf) => buf.writeln('G0 X0 Y0 Z0 ; HOME');
}
```

- [ ] **Step 5: Create `lib/machines/mill/mill_gcode_strategy.dart`**

```dart
import 'dart:ui';
import '../../models/layer_settings.dart';
import '../../models/operation_type.dart';
import '../../services/gcode_format.dart';
import '../gcode/gcode_strategy.dart';
import '../laser/laser_settings.dart';
import 'mill_settings.dart';

class MillGcodeStrategy extends GcodeStrategy {
  final MillSettings settings;

  // Borrowed from the laser settings to keep today's output: the spindle is
  // started with the laser's M3/M4 choice and fill inset uses the laser spot
  // size (spec Follow-ups 1 and 2).
  final LaserMode laserMode;
  final double laserSpotSize;

  const MillGcodeStrategy(
    this.settings, {
    required this.laserMode,
    required this.laserSpotSize,
  });

  int get _travelF => (settings.travelFeedRate * 60).round(); // mm/s -> mm/min

  @override
  int get sMax => settings.maxSpindleSpeed;

  @override
  String get spindleOnCode => laserMode.gcode;

  @override
  double effectiveDiameterAt(double cutDepthMm) =>
      settings.effectiveDiameterAt(cutDepthMm);

  @override
  double fillInset(LayerSettings s) => s.fillOutline ? laserSpotSize / 2 : 0.0;

  // Only Cut has real Z motion; Engrave and Fill stay at Z0 (Follow-up 7).
  @override
  double? plungeDepth(OperationType op, LayerSettings s) =>
      op == OperationType.cut ? s.cutDepthMm : null;

  @override
  void writeContourStart(
      StringBuffer buf, Offset start, int sPower, double? plungeDepth) {
    if (plungeDepth == null) {
      buf.writeln('G0 X${formatGcodeNumber(start.dx)} Y${formatGcodeNumber(start.dy)}');
      buf.writeln('$spindleOnCode S$sPower');
      return;
    }
    // Rise to safe height before any horizontal travel, move to the next cut
    // position at that height, then plunge to depth.
    buf.writeln('G1 Z${formatGcodeNumber(settings.safeHeight)} F$_travelF');
    buf.writeln('G1 X${formatGcodeNumber(start.dx)} Y${formatGcodeNumber(start.dy)} F$_travelF');
    buf.writeln('$spindleOnCode S$sPower');
    buf.writeln('G1 Z${formatGcodeNumber(-plungeDepth)} F$_travelF');
  }

  @override
  void writeContourEnd(StringBuffer buf, double? plungeDepth) {
    if (plungeDepth != null) {
      buf.writeln('G1 Z${formatGcodeNumber(settings.safeHeight)} F$_travelF');
    }
  }

  @override
  void writeFooterMoves(StringBuffer buf) {
    buf
      ..writeln('G1 Z${formatGcodeNumber(settings.safeHeight)} F$_travelF ; retract to safe height')
      ..writeln('G0 X0 Y0 ; XY HOME')
      ..writeln('G1 Z0 F$_travelF ; Z HOME');
  }
}
```

- [ ] **Step 6: Rewrite `lib/machines/gcode/gcode_generator.dart`**

```dart
import 'dart:ui';
import 'package:path_drawing/path_drawing.dart';
import '../../geometry/affine.dart';
import '../../geometry/contour_sampler.dart';
import '../../geometry/fill_lines.dart';
import '../../geometry/path_offset.dart';
import '../../geometry/svg_node_walker.dart';
import '../../models/layer_settings.dart';
import '../../models/operation_type.dart';
import '../../models/svg_document.dart';
import '../../models/svg_node.dart';
import '../../services/gcode_format.dart';
import '../machine_settings.dart';
import 'gcode_strategy.dart';

/// SVG → G-code. This is the mode-agnostic skeleton (header, SVG walk,
/// passes, sampling, Y flip, feed deduplication); everything that differs
/// between Laser and Mill is delegated to a [GcodeStrategy].
class GcodeGenerator {
  static const double _step = 0.1; // mm per sample along curves

  static String generate(
    SvgDocument doc,
    String filename,
    MachineSettings settings,
  ) {
    final strategy = GcodeStrategy.of(settings);
    final buf = StringBuffer();
    final vb = doc.viewBox;

    buf
      ..writeln('; Generated by EasyGRBL')
      ..writeln('; Source: $filename')
      ..writeln('; Work area: ${formatGcodeNumber(vb.width)} x ${formatGcodeNumber(vb.height)} mm')
      ..writeln('; Assumption: 1 SVG unit = 1 mm')
      ..writeln('; Y-axis: flipped (SVG Y-down → G-code Y-up)')
      ..writeln()
      ..writeln('G21 ; metric')
      ..writeln('G90 ; absolute positioning')
      ..writeln('M5 S0 ; laser off')
      ..writeln('G0 X0 Y0 Z0 ; HOME')
      ..writeln();

    walkSvgNodes(doc.roots, (node, transform, effectiveOp, effectiveSettings) {
      _writeNode(node, transform, vb, effectiveOp, effectiveSettings, strategy, buf);
    });

    buf.writeln();
    strategy.writeFooterMoves(buf);
    buf
      ..writeln('M5 S0 ; laser off')
      ..writeln('M2 ; end of program');

    return buf.toString();
  }

  static void _writeNode(
    SvgNode node,
    SvgAffine transform,
    Rect vb,
    OperationType? effectiveOp,
    LayerSettings effectiveSettings,
    GcodeStrategy strategy,
    StringBuffer buf,
  ) {
    if (!isActiveOp(node.pathData, effectiveOp)) return;
    final op = effectiveOp!;
    final s = effectiveSettings;

    final feedRateMmMin = (s.speedMmS * 60).round(); // mm/s -> mm/min for F
    final sMax = strategy.sMax;
    final sPower = (s.powerPercent / 100.0 * sMax).round().clamp(0, sMax);

    if (op == OperationType.fill) {
      final inset = strategy.fillInset(s);
      buf.writeln(
        '; --- ${node.label} [Fill]'
        '  power:${s.powerPercent}%  speed:${s.speedMmS.toStringAsFixed(1)} mm/s'
        '  lines/mm:${s.linesPerMm.toStringAsFixed(1)}'
        '  dir:${s.fillDirection.name}'
        '${s.fillOutline ? '  outline:yes  inset:${inset.toStringAsFixed(3)}mm' : ''} ---',
      );
      _fillToGcode(node.pathData!, transform, vb, sPower, feedRateMmMin,
          s.fillDirection, s.linesPerMm, strategy, buf,
          inset: inset);
      if (s.fillOutline) {
        buf.writeln('; outline pass');
        _pathToGcode(
            node.pathData!, transform, vb, sPower, feedRateMmMin, strategy, buf);
      }
    } else {
      final isCut = op == OperationType.cut;
      final offsetDelta = isCut ? strategy.cutOffsetDelta(s) : 0.0;
      final plungeZ = strategy.plungeDepth(op, s);

      buf.writeln(
        '; --- ${node.label} [${op.label}]'
        '  power:${s.powerPercent}%  speed:${s.speedMmS.toStringAsFixed(1)} mm/s'
        '  passes:${s.passes}'
        '${offsetDelta != 0 ? '  side:${s.cutSide.name} offset:${offsetDelta.toStringAsFixed(3)}mm' : ''}'
        '${plungeZ != null ? '  Z:-${plungeZ.toStringAsFixed(3)}mm' : ''} ---',
      );
      for (var pass = 0; pass < s.passes; pass++) {
        if (s.passes > 1) buf.writeln('; pass ${pass + 1}/${s.passes}');
        _pathToGcode(
            node.pathData!, transform, vb, sPower, feedRateMmMin, strategy, buf,
            offsetDeltaMm: offsetDelta, plungeZMm: plungeZ);
      }
    }
  }

  // ── Outline (engrave / cut) ────────────────────────────────────────────────

  static void _pathToGcode(
    String pathData,
    SvgAffine xform,
    Rect vb,
    int sPower,
    int feedRate,
    GcodeStrategy strategy,
    StringBuffer buf, {
    double offsetDeltaMm = 0.0,
    double? plungeZMm,
  }) {
    final contours = sampleContours(pathData, step: _step, minDistSq: 1e-6,
        map: (p) {
      final tp = xform.apply(p);
      return Offset(tp.dx - vb.left, vb.bottom - tp.dy);
    });

    for (var pts in contours) {
      if (offsetDeltaMm != 0) {
        pts = PathOffset.offsetClosedContour(pts, offsetDeltaMm);
      }

      buf.writeln('M5 S0');
      strategy.writeContourStart(buf, pts.first, sPower, plungeZMm);

      // lastF resets per contour: the travel/plunge moves above (Mill) leave
      // the machine's modal feed at the travel feed, so the first cutting move
      // must always re-assert feedRate rather than assume it's still active.
      int? lastF;
      for (var i = 1; i < pts.length; i++) {
        final fTag = (lastF == feedRate) ? '' : ' F$feedRate';
        buf.writeln('G1 X${formatGcodeNumber(pts[i].dx)} Y${formatGcodeNumber(pts[i].dy)}$fTag');
        lastF = feedRate;
      }

      buf.writeln('M5 S0');
      strategy.writeContourEnd(buf, plungeZMm);
    }
  }

  // ── Fill (scanline hatch) ──────────────────────────────────────────────────

  static void _fillToGcode(
    String pathData,
    SvgAffine xform,
    Rect vb,
    int sPower,
    int feedRate,
    FillDirection direction,
    double linesPerMm,
    GcodeStrategy strategy,
    StringBuffer buf, {
    double inset = 0.0,
  }) {
    final Path rawPath;
    try {
      rawPath = parseSvgPathData(pathData);
    } catch (_) {
      return;
    }

    // Apply transform in SVG space, then compute fill lines
    final path = rawPath.transform(xform.toFloat64());
    final lines = computeFillLines(path, direction, linesPerMm, inset: inset);
    if (lines.isEmpty) return;

    int? lastF;
    for (final line in lines) {
      // Flip Y for G-code coordinate system
      final x1 = line.$1.dx - vb.left;
      final y1 = vb.bottom - line.$1.dy;
      final x2 = line.$2.dx - vb.left;
      final y2 = vb.bottom - line.$2.dy;

      buf.writeln('M5 S0');
      buf.writeln('G0 X${formatGcodeNumber(x1)} Y${formatGcodeNumber(y1)}');
      buf.writeln('${strategy.spindleOnCode} S$sPower');
      final fTag = (lastF == feedRate) ? '' : ' F$feedRate';
      buf.writeln('G1 X${formatGcodeNumber(x2)} Y${formatGcodeNumber(y2)}$fTag');
      lastF = feedRate;
      buf.writeln('M5 S0');
    }
  }
}
```

- [ ] **Step 7: Run analyzer and tests**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`. `gcode_strategy_test.dart` passes, and **all 8 G-code goldens are unchanged**. If a golden differs, compare it to `git show HEAD:lib/services/gcode_generator.dart` and fix the strategy. Do not touch the golden.

- [ ] **Step 8: Report** (no commit)

---

### Task 5: Toolpath, mock and Layer Settings use the strategy

**Files:**
- Modify:
  - `lib/services/toolpath.dart`,
  - `lib/services/grbl_mock_service.dart`,
  - `lib/widgets/layer_settings_panel.dart`,
  - `lib/machines/machine_settings.dart`: remove `effectiveDiameterAt`, `cutOffsetDeltaFor` and the `layer_settings.dart` import.

**Interfaces:**
- Consumes: `GcodeStrategy.of`, `cutOffsetDelta`, `fillInset`, `effectiveDiameterAt` (Task 4).

- [ ] **Step 1: Toolpath**

In `computeToolpath`, add `final strategy = GcodeStrategy.of(machineSettings);` before `walkSvgNodes`, and replace the visitor body's branch with:

```dart
    if (op == OperationType.fill) {
      _sampleFill(node.pathData!, transform, effectiveSettings,
          strategy.fillInset(effectiveSettings), addContour);
    } else {
      final offsetDelta = op == OperationType.cut
          ? strategy.cutOffsetDelta(effectiveSettings)
          : 0.0;
```

Change `_sampleFill`'s parameter `double spotSize` to `double inset`, and delete its line `final inset = settings.fillOutline ? spotSize / 2 : 0.0;`. Import `../machines/gcode/gcode_strategy.dart`.

- [ ] **Step 2: Mock job animation**

In `GrblMockService._collectSteps`:
- add `final strategy = GcodeStrategy.of(machineSettings);` at the top,
- replace `machineSettings.cutOffsetDeltaFor(effSettings)` with `strategy.cutOffsetDelta(effSettings)`,
- call `_sampleFill(n.pathData!, m, doc.viewBox, effSettings, strategy.fillInset(effSettings))`.

In `_sampleFill`, add the parameter `double inset` after `LayerSettings settings`, and delete `final inset = settings.fillOutline ? machineSettings.laserSpotSize / 2 : 0.0;`. Import `../machines/gcode/gcode_strategy.dart`.

- [ ] **Step 3: Layer Settings hint**

In `lib/widgets/layer_settings_panel.dart`, replace:

```dart
  double get _effectiveDiam =>
      widget.machineSettings.effectiveDiameterAt(_cutDepthMm);
```
with
```dart
  double get _effectiveDiam => GcodeStrategy.of(widget.machineSettings)
      .effectiveDiameterAt(_cutDepthMm);
```
and import `../machines/gcode/gcode_strategy.dart`.

- [ ] **Step 4: Remove the temporary composite methods**

Delete `effectiveDiameterAt` and `cutOffsetDeltaFor` (and the import of `../models/layer_settings.dart`) from `lib/machines/machine_settings.dart`.

Run: `grep -rn "cutOffsetDeltaFor\|machineSettings.effectiveDiameterAt\|\.laserSpotSize" lib`
Expected matches only in:
- `machines/laser/*`, `machines/gcode/gcode_strategy.dart`, `machines/mill/mill_gcode_strategy.dart` (field `laserSpotSize`), `machines/laser/templates/*`,
- `widgets/layer_settings_panel.dart` (`_autoLinesPerMm` and `spotSize:`, which stay laser-based per Follow-up 2),
- `widgets/left_panel.dart` (Spot test panel),
- `widgets/machine_settings_dialog.dart`.

- [ ] **Step 5: Run analyzer and tests**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`; toolpath goldens unchanged (Review Focus 4).

- [ ] **Step 6: Report** (no commit)

---

### Task 6: UI — per-mode settings sections and laser templates

**Files:**
- Create: `lib/widgets/settings_form_fields.dart`
- Create: `lib/machines/laser/widgets/laser_settings_section.dart`
- Create: `lib/machines/mill/widgets/mill_settings_section.dart`
- Rewrite: `lib/widgets/machine_settings_dialog.dart`
- Modify:
  - `lib/machines/laser/templates/focus_test.dart`, `kerf_test.dart`, `spot_test.dart`: add document builders,
  - `lib/screens/home/home_screen.dart`: remove the `_build*TestDocument` methods and call the builders.
- Test: `test/laser_templates_test.dart`; re-run `test/machine_settings_dialog_test.dart` unchanged.

**Interfaces:**
- Produces:
  - `LaserSettingsForm(LaserSettings)` (ChangeNotifier) with `bool get isValid`, `LaserSettings result(LaserSettings fallback)`, `dispose()`, and `LaserSettingsSection({required LaserSettingsForm form})`;
  - `MillSettingsForm(MillSettings)` / `MillSettingsSection` with the same shape;
  - `SvgDocument buildFocusTestDocument(FocusTestConfig)`, `SvgDocument buildKerfTestDocument(KerfTestConfig)`, `SvgDocument buildSpotTestDocument()`.

- [ ] **Step 1: Write the failing template-builder test**

Create `test/laser_templates_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/machines/laser/templates/focus_test.dart';
import 'package:easy_grbl/machines/laser/templates/kerf_test.dart';
import 'package:easy_grbl/machines/laser/templates/spot_test.dart';
import 'package:easy_grbl/models/operation_type.dart';

void main() {
  test('focus test document: middle line is Z=0 and cut', () {
    final doc = buildFocusTestDocument(const FocusTestConfig());
    expect(doc.roots.length, 9);
    expect(doc.roots[4].label, 'Z=0.0');
    expect(doc.roots[4].settings.operationType, OperationType.cut);
    expect(doc.roots[0].settings.operationType, OperationType.engrave);
    expect(doc.viewBox, const Rect.fromLTWH(0, 0, 9, 8));
  });

  test('kerf test document: one line per power level', () {
    final doc = buildKerfTestDocument(const KerfTestConfig());
    expect(doc.roots.map((n) => n.label).toList(), [
      '10% power', '30% power', '50% power', '70% power', '90% power', '100% power',
    ]);
    expect(doc.viewBox, const Rect.fromLTWH(0, 0, 10, 10));
  });

  test('spot test document: three bands', () {
    final doc = buildSpotTestDocument();
    expect(doc.roots.map((n) => n.label).toList(), ['−0.1 mm', 'exact', '+0.1 mm']);
    expect(doc.viewBox, const Rect.fromLTWH(0, 0, 9, 9));
  });
}
```

Run: `flutter test test/laser_templates_test.dart`
Expected: FAIL, `buildFocusTestDocument` isn't defined.

- [ ] **Step 2: Move the builders next to their configs**

Append each builder to its template file, moved verbatim from `HomeScreen` (`_buildFocusTestDocument` → `buildFocusTestDocument`, etc.).

In `focus_test.dart`:
```dart
import 'dart:ui';
import '../../../models/layer_settings.dart';
import '../../../models/operation_type.dart';
import '../../../models/svg_document.dart';
import '../../../models/svg_node.dart';
import '../../../models/svg_node_type.dart';

// … FocusTestConfig unchanged …

/// Preview document for the Focus Test: one line per Z step, the Z=0 line
/// marked as Cut so it stands out.
SvgDocument buildFocusTestDocument(FocusTestConfig cfg) {
  final nodes = <SvgNode>[];
  final half = ((cfg.lineCount - 1) / 2).floor();
  for (var i = 0; i < cfg.lineCount; i++) {
    final svgY = (cfg.lineCount - 1) - i;
    final z = (i - half) * cfg.zStep;
    nodes.add(SvgNode(
      id: 'line_$i',
      label: 'Z=${z.toStringAsFixed(1)}',
      type: SvgNodeType.path,
      pathData: 'M 0,$svgY L ${cfg.widthMm},$svgY',
      settings: LayerSettings(
        operationType: z == 0 ? OperationType.cut : OperationType.engrave,
      ),
    ));
  }
  final h = cfg.lineCount - 1.0;
  return SvgDocument(
    roots: nodes,
    viewBox: Rect.fromLTWH(0, 0, cfg.widthMm, h),
  );
}
```

In `kerf_test.dart` (same imports):
```dart
/// Preview document for the Kerf Test: one line per power level.
SvgDocument buildKerfTestDocument(KerfTestConfig cfg) {
  final powers = cfg.powerLevels;
  final nodes = <SvgNode>[];
  for (var i = 0; i < cfg.lineCount; i++) {
    final svgY = (cfg.lineCount - 1 - i) * cfg.lineSpacing.toInt();
    final pct = powers[i];
    nodes.add(SvgNode(
      id: 'line_$i',
      label: '$pct% power',
      type: SvgNodeType.path,
      pathData: 'M 0,$svgY L ${cfg.widthMm},$svgY',
      settings: LayerSettings(
        operationType: OperationType.engrave,
      ),
    ));
  }
  final h = (cfg.lineCount - 1) * cfg.lineSpacing;
  return SvgDocument(
    roots: nodes,
    viewBox: Rect.fromLTWH(0, 0, cfg.widthMm, h),
  );
}
```

In `spot_test.dart` (same imports):
```dart
/// Preview document for the Spot Size Test: three 3 mm bands of a 9 mm
/// square. Its geometry doesn't depend on the config.
SvgDocument buildSpotTestDocument() {
  const labels = ['−0.1 mm', 'exact', '+0.1 mm'];
  const bandH = 3.0;
  const w = 9.0;
  final h = bandH * 3;
  final nodes = <SvgNode>[];
  for (var i = 0; i < 3; i++) {
    final svgY = (2 - i) * bandH;
    nodes.add(SvgNode(
      id: 'band_$i',
      label: labels[i],
      type: SvgNodeType.path,
      pathData:
          'M 0,$svgY L $w,$svgY L $w,${svgY + bandH} L 0,${svgY + bandH} Z',
      settings: LayerSettings(operationType: OperationType.engrave),
    ));
  }
  return SvgDocument(
    roots: nodes,
    viewBox: Rect.fromLTWH(0, 0, w, h),
  );
}
```

In `home_screen.dart`, delete the three `_build*TestDocument` methods and replace the calls:
- `_buildFocusTestDocument(cfg)` → `buildFocusTestDocument(cfg)` (2×),
- `_buildKerfTestDocument(cfg)` → `buildKerfTestDocument(cfg)` (2×),
- `_buildSpotTestDocument(cfg)` → `buildSpotTestDocument()`.

Remove imports that `home_screen.dart` no longer needs (`svg_node_type.dart`, possibly `layer_settings.dart`, `operation_type.dart`). The analyzer reports which ones.

Run: `flutter test test/laser_templates_test.dart` → PASS.

- [ ] **Step 3: Create `lib/widgets/settings_form_fields.dart`**

Move these private builders out of `_MachineSettingsDialogState` into top-level public functions, with bodies unchanged except the renames listed:

| Old (dialog) | New (top-level) |
|---|---|
| `_sectionHeader(title, cs)` | `settingsSectionHeader(String title, ColorScheme cs)` |
| `_fieldLabel(text, cs)` | `settingsFieldLabel(String text, ColorScheme cs)` |
| `_opTypeHeader(type, cs, {bottomPadding})` | `settingsOpTypeHeader(OperationType type, ColorScheme cs, {required double bottomPadding})` |
| `_steppedNumberField({...})` | `steppedNumberField({...})`, same named parameters |
| `_compactFieldDecoration(valid, cs)` | `compactFieldDecoration(bool valid, ColorScheme cs)` |
| `_numericSettingRow(label, ctrl, {...})` | `numericSettingRow(String label, TextEditingController ctrl, {...})`, same named parameters |
| `_numericField(ctrl, {...})` | `numericField(TextEditingController ctrl, {...})` |
| `_parsePositiveInt(ctrl)` | `parsePositiveInt(TextEditingController ctrl)` |
| `_parsePositiveDouble(ctrl)` | `parsePositiveDouble(TextEditingController ctrl)` |

Inside the moved bodies, update internal calls to the new names (e.g. `numericSettingRow` calls `settingsFieldLabel` and `numericField`; `steppedNumberField` calls `compactFieldDecoration`).

Also add the DEFAULTS box, extracted from the dialog's inline `Container`:

```dart
/// The bordered box that groups the per-operation default rows.
Widget settingsGroupBox(ColorScheme cs, List<Widget> children) => Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
```

Imports: `package:flutter/material.dart`, `../models/operation_type.dart`, `icon_stepper_button.dart`.

- [ ] **Step 4: Create `lib/machines/laser/widgets/laser_settings_section.dart`**

```dart
import 'package:flutter/material.dart';
import '../../../models/operation_type.dart';
import '../../../widgets/settings_form_fields.dart';
import '../laser_settings.dart';

const _kSpeedMin = 100;
const _kSpeedMax = 30000;

/// Editable state of the laser part of Machine Settings. Notifies on every
/// change so the dialog can re-validate.
class LaserSettingsForm extends ChangeNotifier {
  LaserSettingsForm(LaserSettings s)
      : _laserMode = s.laserMode,
        sMaxCtrl = TextEditingController(text: '${s.sMax}'),
        spotCtrl =
            TextEditingController(text: s.laserSpotSize.toStringAsFixed(2)),
        _engravePower = s.engravePower.toDouble(),
        engraveSpeedCtrl = TextEditingController(text: '${s.engraveSpeed}'),
        _cutPower = s.cutPower.toDouble(),
        cutSpeedCtrl = TextEditingController(text: '${s.cutSpeed}'),
        _fillPower = s.fillPower.toDouble(),
        fillSpeedCtrl = TextEditingController(text: '${s.fillSpeed}') {
    for (final c in _controllers) {
      c.addListener(notifyListeners);
    }
  }

  final TextEditingController sMaxCtrl;
  final TextEditingController spotCtrl;
  final TextEditingController engraveSpeedCtrl;
  final TextEditingController cutSpeedCtrl;
  final TextEditingController fillSpeedCtrl;
  LaserMode _laserMode;
  double _engravePower;
  double _cutPower;
  double _fillPower;

  List<TextEditingController> get _controllers =>
      [sMaxCtrl, spotCtrl, engraveSpeedCtrl, cutSpeedCtrl, fillSpeedCtrl];

  LaserMode get laserMode => _laserMode;
  set laserMode(LaserMode v) {
    _laserMode = v;
    notifyListeners();
  }

  double powerFor(OperationType op) => switch (op) {
        OperationType.engrave => _engravePower,
        OperationType.cut => _cutPower,
        OperationType.fill => _fillPower,
        OperationType.skip => 0,
      };

  void setPower(OperationType op, double v) {
    switch (op) {
      case OperationType.engrave:
        _engravePower = v;
      case OperationType.cut:
        _cutPower = v;
      case OperationType.fill:
        _fillPower = v;
      case OperationType.skip:
        return;
    }
    notifyListeners();
  }

  TextEditingController speedCtrlFor(OperationType op) => switch (op) {
        OperationType.engrave => engraveSpeedCtrl,
        OperationType.cut => cutSpeedCtrl,
        _ => fillSpeedCtrl,
      };

  static int? parseSpeed(TextEditingController ctrl) {
    final v = int.tryParse(ctrl.text.trim());
    if (v == null || v < _kSpeedMin || v > _kSpeedMax) return null;
    return v;
  }

  bool get isValid =>
      parseSpeed(engraveSpeedCtrl) != null &&
      parseSpeed(cutSpeedCtrl) != null &&
      parseSpeed(fillSpeedCtrl) != null;

  /// Clamp bounds and fallbacks copied 1:1 from the original dialog.
  LaserSettings result(LaserSettings fallback) {
    final spot = double.tryParse(spotCtrl.text.replaceAll(',', '.')) ??
        fallback.laserSpotSize;
    final sMax = int.tryParse(sMaxCtrl.text.trim()) ?? fallback.sMax;
    return LaserSettings(
      laserMode: _laserMode,
      sMax: sMax.clamp(1, 100000),
      laserSpotSize: spot.clamp(0.01, 10.0),
      engravePower: _engravePower.round(),
      engraveSpeed: (parseSpeed(engraveSpeedCtrl) ?? fallback.engraveSpeed)
          .clamp(_kSpeedMin, _kSpeedMax),
      cutPower: _cutPower.round(),
      cutSpeed: (parseSpeed(cutSpeedCtrl) ?? fallback.cutSpeed)
          .clamp(_kSpeedMin, _kSpeedMax),
      fillPower: _fillPower.round(),
      fillSpeed: (parseSpeed(fillSpeedCtrl) ?? fallback.fillSpeed)
          .clamp(_kSpeedMin, _kSpeedMax),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }
}

/// LASER and DEFAULTS sections of the Machine Settings dialog.
class LaserSettingsSection extends StatelessWidget {
  final LaserSettingsForm form;

  const LaserSettingsSection({super.key, required this.form});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        settingsSectionHeader('LASER', cs),
        _laserModeSelector(cs),
        const SizedBox(height: 14),
        numericSettingRow(
          'Max laser power (S max)', form.sMaxCtrl,
          cs: cs, width: 70, decimal: false,
          hint: 'Must match parameter \$30 in GRBL controller',
        ),
        const SizedBox(height: 14),
        numericSettingRow(
          'Laser spot size', form.spotCtrl,
          cs: cs, width: 64, decimal: true, unit: 'mm',
        ),
        const SizedBox(height: 20),
        settingsSectionHeader('DEFAULTS', cs),
        settingsGroupBox(cs, [
          _defaultRow(OperationType.cut, cs),
          const SizedBox(height: 10),
          _defaultRow(OperationType.fill, cs),
          const SizedBox(height: 10),
          _defaultRow(OperationType.engrave, cs),
        ]),
      ],
    );
  }

  // Body moved verbatim from the dialog's _laserModeSelector, with
  // `_laserMode` → `form.laserMode` and
  // `setState(() => _laserMode = m)` → `form.laserMode = m`.
  Widget _laserModeSelector(ColorScheme cs) => /* moved code */;

  // Body moved verbatim from the dialog's _defaultRow(type, power, speedCtrl,
  // onPowerChanged, cs), with:
  //   power          → form.powerFor(type)
  //   speedCtrl      → form.speedCtrlFor(type)
  //   onPowerChanged → (v) => form.setPower(type, v)
  //   _parseSpeed    → LaserSettingsForm.parseSpeed
  //   _opTypeHeader  → settingsOpTypeHeader, _steppedNumberField → steppedNumberField
  //   _kSpeedMin/_kSpeedMax stay (file-level constants above).
  Widget _defaultRow(OperationType type, ColorScheme cs) => /* moved code */;
}
```

The two `/* moved code */` bodies are cut-and-pasted from `machine_settings_dialog.dart` with exactly the renames listed in the comments. Delete the comments once the code is in place.

- [ ] **Step 5: Create `lib/machines/mill/widgets/mill_settings_section.dart`**

```dart
import 'package:flutter/material.dart';
import '../../../models/operation_type.dart';
import '../../../widgets/settings_form_fields.dart';
import '../mill_settings.dart';

/// Editable state of the mill part of Machine Settings. Notifies on every
/// change so the dialog can re-validate.
class MillSettingsForm extends ChangeNotifier {
  MillSettingsForm(MillSettings s)
      : maxSpindleSpeedCtrl = TextEditingController(text: '${s.maxSpindleSpeed}'),
        maxFeedRateCtrl = TextEditingController(text: s.maxFeedRate.toStringAsFixed(1)),
        toolDiamCtrl = TextEditingController(text: s.toolDiameter.toStringAsFixed(3)),
        bladeAngleCtrl = TextEditingController(text: s.bladeAngle.toStringAsFixed(1)),
        safeHeightCtrl = TextEditingController(text: s.safeHeight.toStringAsFixed(1)),
        travelFeedRateCtrl = TextEditingController(text: s.travelFeedRate.toStringAsFixed(1)),
        engraveSpindleCtrl = TextEditingController(text: '${s.engraveSpindleSpeed}'),
        engraveFeedCtrl = TextEditingController(text: s.engraveFeedRate.toStringAsFixed(1)),
        cutSpindleCtrl = TextEditingController(text: '${s.cutSpindleSpeed}'),
        cutFeedCtrl = TextEditingController(text: s.cutFeedRate.toStringAsFixed(1)),
        fillSpindleCtrl = TextEditingController(text: '${s.fillSpindleSpeed}'),
        fillFeedCtrl = TextEditingController(text: s.fillFeedRate.toStringAsFixed(1)) {
    for (final c in _controllers) {
      c.addListener(notifyListeners);
    }
  }

  final TextEditingController maxSpindleSpeedCtrl;
  final TextEditingController maxFeedRateCtrl;
  final TextEditingController toolDiamCtrl;
  final TextEditingController bladeAngleCtrl;
  final TextEditingController safeHeightCtrl;
  final TextEditingController travelFeedRateCtrl;
  final TextEditingController engraveSpindleCtrl;
  final TextEditingController engraveFeedCtrl;
  final TextEditingController cutSpindleCtrl;
  final TextEditingController cutFeedCtrl;
  final TextEditingController fillSpindleCtrl;
  final TextEditingController fillFeedCtrl;

  List<TextEditingController> get _controllers => [
        maxSpindleSpeedCtrl, maxFeedRateCtrl, toolDiamCtrl, bladeAngleCtrl,
        safeHeightCtrl, travelFeedRateCtrl, engraveSpindleCtrl, engraveFeedCtrl,
        cutSpindleCtrl, cutFeedCtrl, fillSpindleCtrl, fillFeedCtrl,
      ];

  bool get isValid =>
      parsePositiveInt(maxSpindleSpeedCtrl) != null &&
      parsePositiveDouble(maxFeedRateCtrl) != null &&
      parsePositiveDouble(toolDiamCtrl) != null &&
      parsePositiveDouble(bladeAngleCtrl) != null &&
      parsePositiveDouble(safeHeightCtrl) != null &&
      parsePositiveDouble(travelFeedRateCtrl) != null &&
      parsePositiveInt(cutSpindleCtrl) != null &&
      parsePositiveDouble(cutFeedCtrl) != null &&
      parsePositiveInt(fillSpindleCtrl) != null &&
      parsePositiveDouble(fillFeedCtrl) != null &&
      parsePositiveInt(engraveSpindleCtrl) != null &&
      parsePositiveDouble(engraveFeedCtrl) != null;

  /// Clamp bounds and fallbacks copied 1:1 from the original dialog.
  MillSettings result(MillSettings f) => MillSettings(
        maxSpindleSpeed: (parsePositiveInt(maxSpindleSpeedCtrl) ?? f.maxSpindleSpeed).clamp(1, 1000000),
        maxFeedRate: (parsePositiveDouble(maxFeedRateCtrl) ?? f.maxFeedRate).clamp(0.1, 100000.0),
        toolDiameter: (parsePositiveDouble(toolDiamCtrl) ?? f.toolDiameter).clamp(0.1, 100.0),
        bladeAngle: (parsePositiveDouble(bladeAngleCtrl) ?? f.bladeAngle).clamp(1.0, 180.0),
        safeHeight: (parsePositiveDouble(safeHeightCtrl) ?? f.safeHeight).clamp(0.1, 500.0),
        travelFeedRate: (parsePositiveDouble(travelFeedRateCtrl) ?? f.travelFeedRate).clamp(1.0, 100000.0),
        engraveSpindleSpeed: (parsePositiveInt(engraveSpindleCtrl) ?? f.engraveSpindleSpeed).clamp(1, 1000000),
        engraveFeedRate: (parsePositiveDouble(engraveFeedCtrl) ?? f.engraveFeedRate).clamp(0.1, 10000.0),
        cutSpindleSpeed: (parsePositiveInt(cutSpindleCtrl) ?? f.cutSpindleSpeed).clamp(1, 1000000),
        cutFeedRate: (parsePositiveDouble(cutFeedCtrl) ?? f.cutFeedRate).clamp(0.1, 10000.0),
        fillSpindleSpeed: (parsePositiveInt(fillSpindleCtrl) ?? f.fillSpindleSpeed).clamp(1, 1000000),
        fillFeedRate: (parsePositiveDouble(fillFeedCtrl) ?? f.fillFeedRate).clamp(0.1, 10000.0),
      );

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }
}

/// MILL and DEFAULTS sections of the Machine Settings dialog.
class MillSettingsSection extends StatelessWidget {
  final MillSettingsForm form;

  const MillSettingsSection({super.key, required this.form});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        settingsSectionHeader('MILL', cs),
        numericSettingRow('Max spindle speed', form.maxSpindleSpeedCtrl,
            cs: cs, width: 80, decimal: false, unit: 'RPM',
            isValid: parsePositiveInt(form.maxSpindleSpeedCtrl) != null),
        const SizedBox(height: 14),
        numericSettingRow('Max feed rate', form.maxFeedRateCtrl,
            cs: cs, width: 80, decimal: true, unit: 'mm/s',
            isValid: parsePositiveDouble(form.maxFeedRateCtrl) != null),
        const SizedBox(height: 14),
        numericSettingRow('Tool diameter', form.toolDiamCtrl,
            cs: cs, width: 72, decimal: true, unit: 'mm',
            hint: 'Diameter of the cutting bit at its widest point',
            isValid: parsePositiveDouble(form.toolDiamCtrl) != null),
        const SizedBox(height: 14),
        numericSettingRow('Included angle', form.bladeAngleCtrl,
            cs: cs, width: 72, decimal: true, unit: '°',
            hint: 'Between the two cutting edges',
            isValid: parsePositiveDouble(form.bladeAngleCtrl) != null),
        const SizedBox(height: 14),
        numericSettingRow('Safe height', form.safeHeightCtrl,
            cs: cs, width: 72, decimal: true, unit: 'mm',
            hint: 'Z clearance for rapid moves above the material',
            isValid: parsePositiveDouble(form.safeHeightCtrl) != null),
        const SizedBox(height: 14),
        numericSettingRow('Travel feed rate', form.travelFeedRateCtrl,
            cs: cs, width: 72, decimal: true, unit: 'mm/s',
            hint: 'Speed for non-cutting moves (retract / travel / plunge)',
            isValid: parsePositiveDouble(form.travelFeedRateCtrl) != null),
        const SizedBox(height: 20),
        settingsSectionHeader('DEFAULTS', cs),
        settingsGroupBox(cs, [
          _millDefaultRow(OperationType.cut, form.cutSpindleCtrl, form.cutFeedCtrl, cs),
          const SizedBox(height: 10),
          _millDefaultRow(OperationType.fill, form.fillSpindleCtrl, form.fillFeedCtrl, cs),
          const SizedBox(height: 10),
          _millDefaultRow(OperationType.engrave, form.engraveSpindleCtrl, form.engraveFeedCtrl, cs),
        ]),
      ],
    );
  }

  // Body moved verbatim from the dialog's _millDefaultRow, with
  // _parsePositiveInt/_parsePositiveDouble → parsePositiveInt/parsePositiveDouble,
  // _opTypeHeader → settingsOpTypeHeader, _steppedNumberField → steppedNumberField.
  Widget _millDefaultRow(OperationType type, TextEditingController spindleCtrl,
          TextEditingController feedCtrl, ColorScheme cs) =>
      /* moved code */;
}
```

(The row labels, widths, units, hints and validity checks above are copied from the dialog's `_maxSpindleSpeedRow` … `_travelFeedRateRow`.)

- [ ] **Step 6: Rewrite the dialog as a shell**

`lib/widgets/machine_settings_dialog.dart` keeps `showMachineSettingsDialog`, `_kBaudRates`, the device query, `_connectionStatusRow` and `_baudRateRow` (with `_fieldLabel` → `settingsFieldLabel`). Everything else moved out in Steps 3–5. The state becomes:

```dart
class _MachineSettingsDialogState extends State<_MachineSettingsDialog> {
  // The working mode is changed only via Machine → Mode, not in this dialog.
  late final MachineType _machineType = widget.current.machineType;
  late final LaserSettingsForm _laserForm = LaserSettingsForm(widget.current.laser);
  late final MillSettingsForm _millForm = MillSettingsForm(widget.current.mill);
  late int _baudRate = widget.current.common.defaultBaudRate;

  bool _queryingDevice = false;
  MachineType? _deviceMachineType;

  @override
  void initState() {
    super.initState();
    if (widget.grbl.connected) {
      _queryingDevice = true;
      widget.grbl.queryMachineType().then((type) {
        if (!mounted) return;
        setState(() {
          _deviceMachineType = type;
          _queryingDevice = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _laserForm.dispose();
    _millForm.dispose();
    super.dispose();
  }

  bool get _isValid => _machineType == MachineType.laser
      ? _laserForm.isValid
      : _millForm.isValid;

  // Both parts are rebuilt from their forms (as the original dialog did), so
  // the inactive mode's values round-trip through the same parse/clamp.
  MachineSettings _buildResult() => widget.current.copyWith(
        common: CommonSettings(defaultBaudRate: _baudRate),
        laser: _laserForm.result(widget.current.laser),
        mill: _millForm.result(widget.current.mill),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([_laserForm, _millForm]),
      builder: (context, _) => AlertDialog(
        title: Row(children: [
          Icon(Icons.settings, size: 18, color: cs.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text('Machine Settings',
              style: TextStyle(color: cs.onSurface, fontSize: 15)),
        ]),
        content: SizedBox(
          width: 570,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _connectionStatusRow(cs),
                const SizedBox(height: 20),
                if (_machineType == MachineType.laser)
                  LaserSettingsSection(form: _laserForm)
                else
                  MillSettingsSection(form: _millForm),
                const SizedBox(height: 20),
                settingsSectionHeader('CONNECTION', cs),
                _baudRateRow(cs),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed:
                _isValid ? () => Navigator.pop(context, _buildResult()) : null,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // _connectionStatusRow(cs) and _baudRateRow(cs): unchanged from the current file.
}
```

Imports:
- `package:flutter/material.dart`,
- `../machines/common_settings.dart`, `../machines/machine_mode.dart`, `../machines/machine_settings.dart`,
- `../machines/laser/widgets/laser_settings_section.dart`, `../machines/mill/widgets/mill_settings_section.dart`,
- `../services/grbl_service.dart`, `settings_form_fields.dart`.

- [ ] **Step 7: Run analyzer and tests**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`; all tests pass except `widget_test.dart`. In particular, `machine_settings_dialog_test.dart` passes **unchanged** (Review Focus 3), and every golden is unchanged.

Check sizes: `wc -l lib/widgets/machine_settings_dialog.dart` should now be roughly 200 lines (was ~880).

- [ ] **Step 8: Manual smoke check**

Run: `flutter build linux --debug`, then start `build/linux/x64/debug/bundle/easy_grbl`. Do these steps:
1. Open Machine → Settings… in both modes.
2. Check that the LASER/MILL and DEFAULTS sections look the same as before.
3. Change one value, Save, reopen, and check the value persisted.
4. In laser mode, open File → Templates → Focus Test and check the preview draws.

- [ ] **Step 9: Final report** (no commit)

Report to the user:
- per-task summary,
- test counts,
- the before/after `lib/` tree,
- the spec's *Follow-ups* list (7 behaviour changes), each to be decided separately.

---

## Self-Review Notes

- **Spec coverage:**
  - settings split → Task 1,
  - moves → Task 2,
  - shared geometry → Task 3,
  - skeleton + strategy → Task 4,
  - toolpath/mock/Layer Settings agreement → Task 5,
  - UI sections, templates, builders → Task 6,
  - safety net → Task 0,
  - Follow-ups → final report.
- **Spec deviations:** see Global Constraints (abstract instead of sealed; `computeActiveBounds` deleted as dead code; template files named `focus_test.dart` etc. as the spec's target structure suggests).
- **Type consistency:**
  - `GcodeStrategy` method names are identical in Tasks 4, 5 and the tests,
  - `LaserSettingsForm.result` / `MillSettingsForm.result` take the fallback part,
  - `buildSpotTestDocument()` takes no arguments in both the test and `HomeScreen`.
