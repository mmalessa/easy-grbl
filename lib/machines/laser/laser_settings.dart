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
