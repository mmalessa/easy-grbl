# Mode Separation (Laser / Mill) — Design

Date: 2026-10-02
Status: approved in conversation, awaiting written-spec review
Builds on: `2026-10-02-machine-mode-ui-design.md` (Machine → Mode, `MachineModeProfile`)

## Goal

Make the code organised around the two working modes, **Laser engraver** and
**CNC mill**, so that everything specific to one mode lives in that mode's own
directory: settings, G-code generation, mode-specific widgets and templates.
Shared code (SVG model, geometry, GRBL communication, common panels) stays mode-agnostic.

This is a **pure refactor**: no change in generated G-code, toolpath preview,
persisted settings or visible behaviour, except where a later, separately approved
follow-up says otherwise.

## Decisions (from the user)

- Directory layout **by mode**: `lib/machines/laser/`, `lib/machines/mill/`.
- `LayerSettings` (per-SVG-node settings) **stays a single shared class** in this
  refactor (option "a"). Mode-dependent fields are only documented as such.
- No commits; each stage is reported and the user decides when to commit.
- Behaviour changes found along the way are listed, not applied (see *Follow-ups*).

## Current problems

1. `MachineSettings` (23 fields) mixes laser fields, mill fields and one common
   field, with two sets of defaults (constructor vs `fromMap`).
2. `GcodeGenerator` is one class with `machineType == mill` branches (plunge Z,
   footer, `_sMaxFor`) and also owns fill geometry (`computeFillLines`) used by
   `toolpath.dart` and `grbl_mock_service.dart`.
3. SVG path sampling is implemented separately in the generator (step 0.1 mm),
   in `toolpath.dart` (step 0.5 mm) and in the mock's job animation (20 fixed points).
4. Laser-only templates (Focus / Kerf / Spot: configs, `GcodeTemplates`, panels,
   document builders in `HomeScreen`) sit in shared `models/`, `services/`,
   `widgets/`, `screens/`.
5. `machine_settings_dialog.dart` (~880 lines) switches LASER/MILL sections internally.

## Target structure

```
lib/
  machines/
    machine_mode.dart              MachineType, MachineModeProfile (sealed), .profile
    machine_settings.dart          composite: machineType + common + laser + mill
    common_settings.dart           CommonSettings (defaultBaudRate)
    gcode/
      gcode_generator.dart         shared skeleton; picks the strategy from machineType
      gcode_strategy.dart          GcodeStrategy interface
    laser/
      laser_settings.dart          LaserSettings
      laser_mode_profile.dart      LaserModeProfile
      laser_gcode_strategy.dart    LaserGcodeStrategy
      templates/
        focus_test.dart            FocusTestConfig + document builder
        kerf_test.dart             KerfTestConfig + document builder
        spot_test.dart             SpotTestConfig + document builder
        test_session.dart          TestSession (sealed)
        laser_gcode_templates.dart (current GcodeTemplates)
        widgets/                   focus/kerf/spot panels, test_panel_common
      widgets/
        laser_settings_section.dart
    mill/
      mill_settings.dart           MillSettings (+ effectiveDiameterAt)
      mill_mode_profile.dart       MillModeProfile
      mill_gcode_strategy.dart     MillGcodeStrategy
      widgets/
        mill_settings_section.dart
  geometry/
    contour_sampler.dart           shared outline sampling (generator + toolpath)
    fill_lines.dart                computeFillLines (moved out of GcodeGenerator)
    path_offset.dart, affine.dart, svg_node_walker.dart, svg_transform.dart (moved)
  models/      SVG model, LayerSettings, OperationType, machine/job state (shared)
  services/    GRBL services, SVG parser, settings persistence, toolpath, comm log
  widgets/     shared panels; machine_settings_dialog.dart becomes a thin shell
  screens/
```

Exact file names may be adjusted during implementation if a split turns out more
natural; the rule is: mode-specific → `machines/<mode>/`, mode-agnostic geometry →
`geometry/`, everything else stays where it is.

## Design

### 1. Settings

```dart
class LaserSettings {
  laserMode, sMax, laserSpotSize,
  engravePower, engraveSpeed, cutPower, cutSpeed, fillPower, fillSpeed
}

class MillSettings {
  maxSpindleSpeed, maxFeedRate, toolDiameter, bladeAngle, safeHeight, travelFeedRate,
  engraveSpindleSpeed, engraveFeedRate, cutSpindleSpeed, cutFeedRate,
  fillSpindleSpeed, fillFeedRate
  double effectiveDiameterAt(double cutDepthMm)
}

class CommonSettings { defaultBaudRate }

class MachineSettings {
  final MachineType machineType;
  final CommonSettings common;
  final LaserSettings laser;
  final MillSettings mill;
  copyWith(...), toMap(), fromMap(...)
}
```

- Each class is immutable with `copyWith`, `toMap`, `fromMap`.
- **Field ownership note.** `engravePower`, `cutPower` and `fillPower` are laser
  fields today but are also used as the "Power %" default in Mill. That cross-use
  stays as is; see *Follow-ups*.
- **Defaults are preserved exactly**, including the existing constructor vs `fromMap`
  differences (`maxSpindleSpeed` 1000 vs 24000, `maxFeedRate` 10 vs 3000,
  `toolDiameter` 2.0 vs 3.175).
- **Persistence is unchanged.** `MachineSettings.toMap()` flattens the parts into
  exactly today's keys (`machineType`, `laserMode`, `sMax`, …), so `SettingsService`
  keeps working without modification and existing saved settings load as before.
- `cutOffsetDeltaFor(LayerSettings)` and `effectiveDiameterAt` move behind the
  strategy (see 2); `MillSettings.effectiveDiameterAt` holds the V-bit maths.
- Consumers (widgets, `HomeScreen`, services) are updated to
  `settings.laser.x` / `settings.mill.x` / `settings.common.x`.
  `LayerSettingsPanel`'s "Effective Ø" hint uses the strategy's effective diameter,
  so it follows the same rule as the generator. Laser templates take `LaserSettings`.

### 2. G-code generation: skeleton + strategy

`GcodeGenerator.generate(doc, filename, settings)` keeps its signature. Internally:

- **Shared skeleton** (`machines/gcode/gcode_generator.dart`):
  - header,
  - SVG walk via `walkSvgNodes`,
  - per-node comment line,
  - passes loop,
  - outline sampling via `contour_sampler`,
  - fill lines via `fill_lines`,
  - Y flip, `F` deduplication, footer call.
- **`GcodeStrategy`** (one instance per mode, built from `MachineSettings`):
  - `int get sMax`: laser `$30` vs spindle max RPM,
  - `double effectiveDiameterAt(double cutDepthMm)`: laser spot size, or the mill
    V-bit diameter at that depth,
  - `double cutOffsetDelta(LayerSettings)`: ± half of the effective diameter, by cut side,
  - `double fillInset(LayerSettings)`,
  - `double? plungeDepth(OperationType, LayerSettings)`: null for laser,
  - `void writeContour(buf, pts, sPower, feedRate)`: the per-contour emission,
    i.e. laser `G0 → M3/M4 S → G1… → M5` or mill `retract → travel → spindle → plunge → cut → retract`,
  - `void writeFillLine(...)`,
  - `void writeFooter(buf)`.
- `LaserGcodeStrategy` gets `LaserSettings`. `MillGcodeStrategy` gets
  `MillSettings` **plus the values it borrows today** (`laserMode` for M3/M4,
  `laserSpotSize` for fill inset), passed explicitly so the borrowing is visible
  in the constructor. See *Follow-ups*.
- `computeActiveBounds` moves to `geometry/` (it is mode-agnostic).

The byte-for-byte G-code goldens are the acceptance criterion for this part.

### 3. Shared geometry

- `fill_lines.dart`: `computeFillLines`, `_crossingsX`, `_crossingsY` moved verbatim.
- `contour_sampler.dart`: one function that samples each contour of an SVG path
  with a given `step` and a dedupe distance, applies the transform, and optionally
  offsets closed contours.
  - Used by the generator (0.1 mm, after the Y flip, as today) and by `toolpath.dart`
    (0.5 mm, in SVG space, as today).
  - Its parameters reproduce each current call site exactly. If a call site can't be
    reproduced byte-for-byte, it keeps its own loop.
- The mock's job-animation sampling (20 evenly spaced points, subsampled fill)
  serves a different purpose and stays in `grbl_mock_service.dart`, but uses the
  strategy for offset and inset instead of reading `MachineSettings` directly.

### 4. Toolpath preview and mock

`toolpath.dart` and `grbl_mock_service.dart` take Cut offset and Fill inset from
the strategy (`GcodeStrategy.cutOffsetDelta` / `fillInset`), so preview, animation
and G-code always agree.

### 5. UI

- `machine_settings_dialog.dart` keeps the dialog shell: connection status, DEFAULTS
  container, CONNECTION section, validation and result assembly.
- `LaserSettingsSection` and `MillSettingsSection` (in `machines/<mode>/widgets/`)
  own their fields, controllers, validation (`isValid`) and produce
  `LaserSettings` / `MillSettings`.
- Laser templates move to `machines/laser/templates/`. The three
  `_build*TestDocument` methods move out of `HomeScreen` next to their configs.
  `HomeScreen` keeps only session state and callbacks.
- `MachineModeProfile` moves to `machines/machine_mode.dart` (profile classes in
  each mode's directory).

## Stages

Each stage: implement → `flutter analyze` + `flutter test` → report.

0. **Safety net.** Extend regression tests before touching code:
   - G-code goldens: laser M3 (exists), laser M4, mill (exists), mill with a
     different tool/angle/safe height, Focus, Kerf and Spot template output,
   - `MachineSettings.toMap()` key set and values equal today's, and
     `fromMap(toMap(x))` round-trips,
   - `fromMap({})` equals today's first-run defaults,
   - toolpath preview: sampled points of `computeToolpath` paths for laser and mill
     equal a captured golden.
1. **Settings split.** `LaserSettings`, `MillSettings`, `CommonSettings`, composite
   `MachineSettings`; update all consumers.
2. **Move files** into `machines/…` and `geometry/`. Moves and imports only.
3. **Shared geometry.** `fill_lines.dart`, `contour_sampler.dart`.
4. **Generator.** Skeleton + `LaserGcodeStrategy` + `MillGcodeStrategy`.
5. **Toolpath and mock** use the strategy.
6. **UI.** Settings sections per mode, laser templates directory, document builders
   out of `HomeScreen`.

## Follow-ups (behaviour changes, NOT part of this refactor)

To be presented after stage 6, each for a separate decision:

1. Mill uses the laser's `laserMode` (M3/M4) to start the spindle. Should it have its
   own spindle direction (default M3)?
2. Mill Fill uses `laserSpotSize` for inset and `linesPerMm` (auto = 1/spot) for line
   spacing. Should it be tool-diameter based (stepover)?
3. Mill G-code header and footer contain `; laser off` comments.
4. Mill "Power %" defaults come from laser `*Power` fields. Should it use the unused
   per-operation `*SpindleSpeed` fields instead (RPM)?
5. Constructor vs `fromMap` defaults differ for three mill fields. Unify?
6. `maxFeedRate` and `*SpindleSpeed` are stored and edited but not used in G-code.
7. Mill Engrave and Fill have no Z motion (only Cut plunges).

## Testing

- All stage-0 regression tests must stay green through every stage unchanged.
  Golden files are never regenerated during this refactor.
- Existing tests (`machine_mode_test.dart`) are kept, with imports updated.
- New unit tests per stage where a new unit appears: `LaserSettings`/`MillSettings`
  map round-trips, `MillSettings.effectiveDiameterAt`, `contour_sampler` against
  the goldens, strategy methods for each mode.
- Known pre-existing failure: `test/widget_test.dart` (RightPanel overflow at the
  800×600 test window). Not in scope; reported as-is.
