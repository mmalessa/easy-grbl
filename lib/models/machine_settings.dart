import 'dart:math' as math;

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
  final double safeHeight;
  final double travelFeedRate;
  final int defaultBaudRate;

  const MachineSettings({
    this.machineType = MachineType.laser,
    this.laserMode = LaserMode.constant,
    this.sMax = 1000,
    this.laserSpotSize = 0.1,
    this.maxSpindleSpeed = 1000,
    this.maxFeedRate = 10.0,
    this.toolDiameter = 2.0,
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
    this.safeHeight = 5.0,
    this.travelFeedRate = 25.0,
    this.defaultBaudRate = 115200,
  });

  /// Effective tool/spot diameter (mm) at a given cut depth below the
  /// surface. Laser always uses the full spot size (no taper). Mill tapers
  /// with the V-bit's Included angle — a 180° (straight) bit stays at its
  /// nominal diameter regardless of depth; a narrower angle is a cone, so
  /// the diameter at the tip is smaller than the nominal (widest) diameter.
  double effectiveDiameterAt(double cutDepthMm) {
    if (machineType == MachineType.laser) return laserSpotSize;
    if (bladeAngle >= 179.99) return toolDiameter;
    final halfAngle = bladeAngle / 2 * math.pi / 180;
    final atDepth = 2 * cutDepthMm.abs() * math.tan(halfAngle);
    return atDepth.clamp(0.0, toolDiameter);
  }

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
    double? safeHeight,
    double? travelFeedRate,
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
        safeHeight: safeHeight ?? this.safeHeight,
        travelFeedRate: travelFeedRate ?? this.travelFeedRate,
        defaultBaudRate: defaultBaudRate ?? this.defaultBaudRate,
      );
}
