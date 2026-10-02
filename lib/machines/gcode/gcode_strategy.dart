import 'dart:ui';
import '../../models/layer_settings.dart';
import '../../models/operation_type.dart';
import '../laser/laser_gcode_strategy.dart';
import '../machine_mode.dart';
import '../machine_settings.dart';
import '../mill/mill_gcode_strategy.dart';

/// Everything about G-code that differs between working modes. The shared
/// skeleton lives in GcodeGenerator; the toolpath preview, the mock job
/// animation and Layer Settings use the same strategy so they always agree
/// with the generated G-code.
abstract class GcodeStrategy {
  const GcodeStrategy();

  factory GcodeStrategy.of(MachineSettings s) => switch (s.machineType) {
        MachineType.laser => LaserGcodeStrategy(s.laser),
        MachineType.mill => MillGcodeStrategy(
            s.mill,
            laserMode: s.laser.laserMode,
            laserSpotSize: s.laser.laserSpotSize,
          ),
      };

  /// Ceiling for `S<value>`: a layer's Power % maps to 0..[sMax].
  int get sMax;

  /// `M3`/`M4` — switches the laser or spindle on.
  String get spindleOnCode;

  /// Tool/spot diameter (mm) at [cutDepthMm] below the surface.
  double effectiveDiameterAt(double cutDepthMm);

  /// Signed XY offset (mm) for a Cut layer's toolpath: outer grows, inner
  /// shrinks, by half the effective diameter at the layer's cut depth.
  double cutOffsetDelta(LayerSettings s) {
    final d = effectiveDiameterAt(s.cutDepthMm);
    return switch (s.cutSide) {
      CutSide.line => 0.0,
      CutSide.outer => d / 2,
      CutSide.inner => -d / 2,
    };
  }

  /// How far fill lines stay away from the outline when an outline pass is
  /// also burned.
  double fillInset(LayerSettings s);

  /// Depth (mm, positive) to plunge to for [op], or null for no Z motion.
  double? plungeDepth(OperationType op, LayerSettings s);

  /// Written after a contour's leading `M5 S0`: move to [start] with the tool
  /// off and switch it on at [sPower], plunging to [plungeDepth] if given.
  void writeContourStart(
      StringBuffer buf, Offset start, int sPower, double? plungeDepth);

  /// Written after a contour's trailing `M5 S0`.
  void writeContourEnd(StringBuffer buf, double? plungeDepth);

  /// End-of-program moves back to the origin (before `M5`/`M2`).
  void writeFooterMoves(StringBuffer buf);
}
