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
