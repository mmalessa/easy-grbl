import 'dart:ui';
import '../../models/layer_settings.dart';
import '../../models/operation_type.dart';
import '../../services/gcode_format.dart';
import '../gcode/gcode_strategy.dart';
import 'laser_settings.dart';

class LaserGcodeStrategy extends GcodeStrategy {
  final LaserSettings settings;

  const LaserGcodeStrategy(this.settings);

  @override
  int get sMax => settings.sMax;

  @override
  String get spindleOnCode => settings.laserMode.gcode;

  // A laser beam doesn't taper with depth.
  @override
  double effectiveDiameterAt(double cutDepthMm) => settings.laserSpotSize;

  @override
  double get fillSpotDiameter => settings.laserSpotSize;

  @override
  double? plungeDepth(OperationType op, LayerSettings s) => null;

  @override
  void writeContourStart(
      StringBuffer buf, Offset start, int sPower, double? plungeDepth) {
    buf.writeln('G0 X${formatGcodeNumber(start.dx)} Y${formatGcodeNumber(start.dy)}');
    buf.writeln('$spindleOnCode S$sPower');
  }

  @override
  void writeContourEnd(StringBuffer buf, double? plungeDepth) {}

  @override
  void writeFooterMoves(StringBuffer buf) => buf.writeln('G0 X0 Y0 Z0 ; HOME');
}
