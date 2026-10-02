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
