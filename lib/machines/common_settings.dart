import '../models/speed_unit.dart';

/// Settings shared by every working mode.
class CommonSettings {
  final int defaultBaudRate;
  final SpeedUnit speedUnit;

  const CommonSettings({
    this.defaultBaudRate = 115200,
    this.speedUnit = SpeedUnit.mmPerSec,
  });

  CommonSettings copyWith({int? defaultBaudRate, SpeedUnit? speedUnit}) =>
      CommonSettings(
        defaultBaudRate: defaultBaudRate ?? this.defaultBaudRate,
        speedUnit: speedUnit ?? this.speedUnit,
      );

  Map<String, Object> toMap() => {
        'defaultBaudRate': defaultBaudRate,
        'speedUnit': speedUnit.name,
      };

  factory CommonSettings.fromMap(Map<String, Object?> map) => CommonSettings(
        defaultBaudRate: map['defaultBaudRate'] as int? ?? 115200,
        speedUnit: SpeedUnit.values.firstWhere(
          (u) => u.name == map['speedUnit'],
          orElse: () => SpeedUnit.mmPerSec,
        ),
      );
}
