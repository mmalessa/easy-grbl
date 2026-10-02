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
