import 'dart:ui';
import '../../models/layer_settings.dart';
import '../../models/operation_type.dart';
import '../../services/gcode_format.dart';
import '../gcode/gcode_strategy.dart';
import '../laser/laser_settings.dart';
import 'mill_settings.dart';

class MillGcodeStrategy extends GcodeStrategy {
  final MillSettings settings;

  // Borrowed from the laser settings to keep today's output: the spindle is
  // started with the laser's M3/M4 choice (spec Follow-up 1).
  final LaserMode laserMode;

  const MillGcodeStrategy(this.settings, {required this.laserMode});

  int get _travelF => (settings.travelFeedRate * 60).round(); // mm/s -> mm/min

  @override
  int get sMax => settings.maxSpindleSpeed;

  @override
  String get spindleOnCode => laserMode.gcode;

  @override
  double effectiveDiameterAt(double cutDepthMm) =>
      settings.effectiveDiameterAt(cutDepthMm);

  @override
  double get fillSpotDiameter => settings.toolDiameter;

  // Only Cut has real Z motion; Engrave and Fill stay at Z0 (Follow-up 7).
  @override
  double? plungeDepth(OperationType op, LayerSettings s) =>
      op == OperationType.cut ? s.cutDepthMm : null;

  @override
  void writeContourStart(
      StringBuffer buf, Offset start, int sPower, double? plungeDepth) {
    if (plungeDepth == null) {
      buf.writeln('G0 X${formatGcodeNumber(start.dx)} Y${formatGcodeNumber(start.dy)}');
      buf.writeln('$spindleOnCode S$sPower');
      return;
    }
    // Rise to safe height before any horizontal travel, move to the next cut
    // position at that height, then plunge to depth.
    buf.writeln('G1 Z${formatGcodeNumber(settings.safeHeight)} F$_travelF');
    buf.writeln('G1 X${formatGcodeNumber(start.dx)} Y${formatGcodeNumber(start.dy)} F$_travelF');
    buf.writeln('$spindleOnCode S$sPower');
    buf.writeln('G1 Z${formatGcodeNumber(-plungeDepth)} F$_travelF');
  }

  @override
  void writeContourEnd(StringBuffer buf, double? plungeDepth) {
    if (plungeDepth != null) {
      buf.writeln('G1 Z${formatGcodeNumber(settings.safeHeight)} F$_travelF');
    }
  }

  @override
  void writeFooterMoves(StringBuffer buf) {
    buf
      ..writeln('G1 Z${formatGcodeNumber(settings.safeHeight)} F$_travelF ; retract to safe height')
      ..writeln('G0 X0 Y0 ; XY HOME')
      ..writeln('G1 Z0 F$_travelF ; Z HOME');
  }
}
