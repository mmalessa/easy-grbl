enum MachineType { laser, mill }

extension MachineTypeDisplay on MachineType {
  String get label => switch (this) {
        MachineType.laser => 'Laser',
        MachineType.mill => 'Mill',
      };
}

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
  final MachineType machineType;
  final LaserMode laserMode;
  final int sMax;
  final double laserSpotSize;
  final int maxSpindleSpeed;
  final double maxFeedRate;
  final double toolDiameter;
  final double bladeAngle;
  final int engravePower;
  final int engraveSpeed;
  final int cutPower;
  final int cutSpeed;
  final int fillPower;
  final int fillSpeed;
  final int engraveSpindleSpeed;
  final double engraveFeedRate;
  final int cutSpindleSpeed;
  final double cutFeedRate;
  final int fillSpindleSpeed;
  final double fillFeedRate;
  final int defaultBaudRate;

  const MachineSettings({
    this.machineType = MachineType.laser,
    this.laserMode = LaserMode.constant,
    this.sMax = 1000,
    this.laserSpotSize = 0.1,
    this.maxSpindleSpeed = 24000,
    this.maxFeedRate = 3000.0,
    this.toolDiameter = 3.175,
    this.bladeAngle = 30.0,
    this.engravePower = 60,
    this.engraveSpeed = 3000,
    this.cutPower = 100,
    this.cutSpeed = 800,
    this.fillPower = 80,
    this.fillSpeed = 3000,
    this.engraveSpindleSpeed = 12000,
    this.engraveFeedRate = 20.0,
    this.cutSpindleSpeed = 18000,
    this.cutFeedRate = 30.0,
    this.fillSpindleSpeed = 18000,
    this.fillFeedRate = 50.0,
    this.defaultBaudRate = 115200,
  });

  MachineSettings copyWith({
    MachineType? machineType,
    LaserMode? laserMode,
    int? sMax,
    double? laserSpotSize,
    int? maxSpindleSpeed,
    double? maxFeedRate,
    double? toolDiameter,
    double? bladeAngle,
    int? engravePower,
    int? engraveSpeed,
    int? cutPower,
    int? cutSpeed,
    int? fillPower,
    int? fillSpeed,
    int? engraveSpindleSpeed,
    double? engraveFeedRate,
    int? cutSpindleSpeed,
    double? cutFeedRate,
    int? fillSpindleSpeed,
    double? fillFeedRate,
    int? defaultBaudRate,
  }) =>
      MachineSettings(
        machineType: machineType ?? this.machineType,
        laserMode: laserMode ?? this.laserMode,
        sMax: sMax ?? this.sMax,
        laserSpotSize: laserSpotSize ?? this.laserSpotSize,
        maxSpindleSpeed: maxSpindleSpeed ?? this.maxSpindleSpeed,
        maxFeedRate: maxFeedRate ?? this.maxFeedRate,
        toolDiameter: toolDiameter ?? this.toolDiameter,
        bladeAngle: bladeAngle ?? this.bladeAngle,
        engravePower: engravePower ?? this.engravePower,
        engraveSpeed: engraveSpeed ?? this.engraveSpeed,
        cutPower: cutPower ?? this.cutPower,
        cutSpeed: cutSpeed ?? this.cutSpeed,
        fillPower: fillPower ?? this.fillPower,
        fillSpeed: fillSpeed ?? this.fillSpeed,
        engraveSpindleSpeed: engraveSpindleSpeed ?? this.engraveSpindleSpeed,
        engraveFeedRate: engraveFeedRate ?? this.engraveFeedRate,
        cutSpindleSpeed: cutSpindleSpeed ?? this.cutSpindleSpeed,
        cutFeedRate: cutFeedRate ?? this.cutFeedRate,
        fillSpindleSpeed: fillSpindleSpeed ?? this.fillSpindleSpeed,
        fillFeedRate: fillFeedRate ?? this.fillFeedRate,
        defaultBaudRate: defaultBaudRate ?? this.defaultBaudRate,
      );
}
