# Machine Mode UI — Design

Date: 2026-10-02
Status: approved in conversation, awaiting written-spec review

## Goal

Make the application's working mode — **Laser engraver** or **CNC mill** — an
explicit, first-class concept of the UI:

- switched from one easy-to-find place in the menu bar,
- always clearly visible on the main screen,
- driving which UI elements are shown, from a single source of truth instead of
  scattered `machineType == MachineType.mill` checks.

## Constraints (from the user)

- The mode is switched **only** via the menu bar: `Machine → Mode → Laser engraver / CNC mill`.
- **No colour-scheme changes.** The mode indicator must not rely on theme/accent colours.
- The mode must be clearly visible: **(A)** a badge on the right side of the menu bar
  **and (B)** in the right panel's *Machine* section header.
- G-code output for both modes must stay **byte-for-byte identical** to the current
  output for the same inputs (this is a UI refactor, not a G-code change).
- Any behaviour change beyond what is listed here needs explicit user sign-off
  before being applied.
- Work is delivered stage by stage; each stage is reported and committed only on
  the user's explicit request.

## Current state

- `MachineType { laser, mill }` already exists on `MachineSettings`
  (`lib/models/machine_settings.dart`) and is persisted by `SettingsService`.
- It is edited only through the *MACHINE TYPE* selector inside the Machine Settings
  dialog (`lib/widgets/machine_settings_dialog.dart`), which also queries the
  connected device's `$32` flag and offers to sync it.
- The dialog already shows only the active mode's section (LASER or MILL).
- Mode-dependent checks are scattered: `layer_settings_panel.dart` (default speeds,
  Cut depth field), `machine_settings_dialog.dart`, `gcode_generator.dart`.
- `File → Templates` (Focus / Kerf / Spot Size Test) are laser-only but always shown.
- Nothing on the main screen shows which mode is active.

## Design

### 1. `MachineModeProfile` — the single source of mode-dependent UI facts

New file `lib/models/machine_mode_profile.dart`. A small sealed/abstract class with
one implementation per `MachineType`, obtained via an extension
`MachineType.profile` (or `MachineSettings.modeProfile`).

Responsibilities (UI-facing only):

| Member | Laser | Mill |
|---|---|---|
| `displayName` | `Laser engraver` | `CNC mill` |
| `badgeLabel` | `LASER ENGRAVER` | `CNC MILL` |
| `icon` | laser-ish Material icon (e.g. `Icons.flare`) | mill-ish icon (e.g. `Icons.precision_manufacturing`) |
| `supportsTemplates` | `true` | `false` |
| `showsCutDepth` | `false` | `true` |
| `defaultSpeedMmS(op, settings)` | `<op>Speed / 60` | `<op>FeedRate` |

Rules:
- `MachineType` remains the persisted value; the profile is derived, never stored.
- The profile does **not** cover G-code generation. `gcode_generator.dart` keeps its
  existing `machineType` checks, so G-code is provably untouched.
- Widgets query the profile instead of comparing `machineType` directly.

### 2. Menu: `Machine → Mode`

In `lib/widgets/main_app_bar.dart`, the *Machine* menu becomes:

```
Machine
├ Connect… / Disconnect
├ Mode ▸ ◉ Laser engraver
│        ○ CNC mill
├ ─────────
└ Settings…
```

- Radio-style items (checked icon on the active mode), labels from `profile.displayName`.
- New `MainAppBar` inputs: `machineType` (current), `onModeChanged(MachineType)?`.
  When the callback is `null` (a job is running or paused), both items are disabled.
- Selecting the already-active mode does nothing.

Handling in `HomeScreen` (`_onModeChanged`):
1. If `_grbl.isJobRunning || _grbl.isJobPaused`, ignore (also guarded by disabled items).
2. If a document is loaded, show a confirmation dialog:
   *"Switch to CNC mill? Layer settings will be interpreted for the new mode."*
   Cancel → no change.
3. `_machineSettings = _machineSettings.copyWith(machineType: newType)`,
   propagate to `_grbl.machineSettings`, `SettingsService.save(...)`.
4. Recompute `_toolpath` if a document is loaded.
5. If a test session (Focus/Kerf/Spot) is open and the new mode does not support
   templates, close it (`NoTestSession`).

Machine Settings dialog: the *MACHINE TYPE* selector section is removed. The dialog
reads the mode from the settings it was given and returns it unchanged. The
LASER/MILL section switching stays as is. The `$32` device check moves out of the
dialog (see 5).

### 3. Mode indicator

**A — menu bar badge.** In `MainAppBar`, after the `MenuBar`, a non-interactive
badge aligned to the right: `[icon] LASER ENGRAVER` / `[icon] CNC MILL`. Styling uses
existing neutral theme colours (`onSurface`, `outlineVariant` border, small caps,
semi-bold); no new colours. It has a tooltip "Change in Machine → Mode" and no
click action.

**B — right panel header.** The *Machine* `PanelSectionHeader` in
`lib/widgets/right_panel.dart` shows the title `Machine · Laser engraver` /
`Machine · CNC mill`, with the mode icon. `RightPanel` gets a new `machineType`
input.

### 4. Mode-dependent UI

- `File → Templates` is shown only when `profile.supportsTemplates`.
- `LayerSettingsPanel`: Cut depth visibility uses `profile.showsCutDepth`; default
  speed on operation change uses `profile.defaultSpeedMmS`. Visible behaviour is
  unchanged; only the source of the decision moves.
- Machine Settings dialog: sections already follow the mode; only the selector is
  removed (stage 2).

### 5. `$32` device check on connect

After a successful connect (serial or mock) in `HomeScreen._openConnectDialog`,
call `_grbl.queryMachineType()`. If it returns a type different from the app's
mode, show a SnackBar:
*"Device is configured as Laser engraver (\$32=1), app is in CNC mill mode."*
with an action **Sync device** that calls `_grbl.setDeviceLaserMode(...)` to match
the app's mode and reports success/failure in a follow-up SnackBar.
`null` (unknown) shows nothing. The app's mode is never changed automatically.
The dialog's live device-status row (Connected/Disconnected, device type) may stay
as read-only information, minus the sync prompt that the selector change triggered.

## Out of scope (deferred, to be decided with the user at stage 4 or later)

- Showing spindle speed in RPM instead of "Power %" in CNC mode.
- Renaming operations in CNC mode (e.g. Cut → Profile, Fill → Pocket).
- CNC-specific controls in the right panel (Set Z0, spindle ON/OFF).
- Machine profiles (multiple named machines).
- Any theme/colour changes.

## Implementation stages

Each stage: implement → `flutter analyze` + `flutter test` → report → wait for an
explicit "commit".

1. **Mode profile (pure refactor).** Add `MachineModeProfile`; route the existing
   widget checks through it. Add a test that G-code for a representative document
   is identical in both modes before/after (golden strings captured from current
   `master`).
2. **Machine → Mode menu.** Submenu, `HomeScreen._onModeChanged` with the guards
   above, removal of the dialog's selector.
3. **Indicators A + B.**
4. **Mode-dependent UI.** Templates hidden in CNC mode, open test closed on switch.
5. **`$32` check on connect** with the Sync SnackBar; drop the dialog's sync prompt.

## Testing

- Unit: `MachineModeProfile` values per mode; `defaultSpeedMmS` matches the current
  formulas.
- G-code regression: generated output for Laser and Mill equals captured golden
  strings (stage 1, kept for all later stages).
- Widget: `MainAppBar` renders the Mode submenu with the correct checked item,
  disabled items when `onModeChanged == null`, the badge text per mode, Templates
  hidden in CNC mode; `RightPanel` header text per mode.
- Manual (mock connection): switch modes with and without a loaded file, during a
  running job (items disabled), with an open Focus test in CNC mode, and the `$32`
  mismatch SnackBar after connecting.
