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

class MachineSettings {
  final LaserMode laserMode;
  final int sMax;
  final double laserSpotSize;
  final int engravePower;
  final int engraveSpeed;
  final int cutPower;
  final int cutSpeed;
  final int defaultBaudRate;

  const MachineSettings({
    this.laserMode = LaserMode.constant,
    this.sMax = 1000,
    this.laserSpotSize = 0.1,
    this.engravePower = 60,
    this.engraveSpeed = 3000,
    this.cutPower = 100,
    this.cutSpeed = 800,
    this.defaultBaudRate = 115200,
  });

  MachineSettings copyWith({
    LaserMode? laserMode,
    int? sMax,
    double? laserSpotSize,
    int? engravePower,
    int? engraveSpeed,
    int? cutPower,
    int? cutSpeed,
    int? defaultBaudRate,
  }) =>
      MachineSettings(
        laserMode: laserMode ?? this.laserMode,
        sMax: sMax ?? this.sMax,
        laserSpotSize: laserSpotSize ?? this.laserSpotSize,
        engravePower: engravePower ?? this.engravePower,
        engraveSpeed: engraveSpeed ?? this.engraveSpeed,
        cutPower: cutPower ?? this.cutPower,
        cutSpeed: cutSpeed ?? this.cutSpeed,
        defaultBaudRate: defaultBaudRate ?? this.defaultBaudRate,
      );
}
