import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/machines/gcode/gcode_strategy.dart';
import 'package:easy_grbl/machines/laser/laser_gcode_strategy.dart';
import 'package:easy_grbl/machines/laser/laser_settings.dart';
import 'package:easy_grbl/machines/machine_mode.dart';
import 'package:easy_grbl/machines/machine_settings.dart';
import 'package:easy_grbl/machines/mill/mill_gcode_strategy.dart';
import 'package:easy_grbl/machines/mill/mill_settings.dart';
import 'package:easy_grbl/models/layer_settings.dart';
import 'package:easy_grbl/models/operation_type.dart';

String _write(void Function(StringBuffer) f) {
  final b = StringBuffer();
  f(b);
  return b.toString();
}

void main() {
  test('GcodeStrategy.of picks the mode and passes borrowed laser values', () {
    const s = MachineSettings(
      machineType: MachineType.mill,
      laser: LaserSettings(laserMode: LaserMode.variable, laserSpotSize: 0.3),
    );
    final strategy = GcodeStrategy.of(s) as MillGcodeStrategy;
    expect(strategy.laserMode, LaserMode.variable);
    expect(GcodeStrategy.of(const MachineSettings()), isA<LaserGcodeStrategy>());
  });

  group('laser', () {
    const strategy = LaserGcodeStrategy(
        LaserSettings(sMax: 255, laserSpotSize: 0.2, laserMode: LaserMode.variable));

    test('scaling, offsets, no plunge', () {
      expect(strategy.sMax, 255);
      expect(strategy.spindleOnCode, 'M4');
      expect(strategy.cutOffsetDelta(LayerSettings(cutSide: CutSide.outer)), 0.1);
      expect(strategy.cutOffsetDelta(LayerSettings(cutSide: CutSide.inner)), -0.1);
      expect(strategy.fillSpotDiameter, 0.2);
      expect(strategy.plungeDepth(OperationType.cut, LayerSettings()), isNull);
    });

    test('contour start and footer', () {
      expect(
          _write((b) => strategy.writeContourStart(b, const Offset(1, 2), 128, null)),
          'G0 X1.000 Y2.000\nM4 S128\n');
      expect(_write((b) => strategy.writeContourEnd(b, null)), '');
      expect(_write(strategy.writeFooterMoves), 'G0 X0 Y0 Z0 ; HOME\n');
    });
  });

  group('mill', () {
    const strategy = MillGcodeStrategy(
      MillSettings(
          maxSpindleSpeed: 24000, toolDiameter: 6, bladeAngle: 90,
          safeHeight: 3, travelFeedRate: 10),
      laserMode: LaserMode.constant,
    );

    test('scaling, V-bit offset, plunge only for cut', () {
      expect(strategy.sMax, 24000);
      expect(strategy.effectiveDiameterAt(1), closeTo(2, 1e-9));
      expect(
          strategy.cutOffsetDelta(
              LayerSettings(cutSide: CutSide.outer, cutDepthMm: 1)),
          closeTo(1, 1e-9));
      expect(strategy.fillSpotDiameter, 6);
      expect(strategy.plungeDepth(OperationType.cut, LayerSettings(cutDepthMm: 2)), 2);
      expect(strategy.plungeDepth(OperationType.engrave, LayerSettings()), isNull);
    });

    test('plunging contour start/end and footer', () {
      expect(
          _write((b) => strategy.writeContourStart(b, const Offset(1, 2), 500, 1.5)),
          'G1 Z3.000 F600\nG1 X1.000 Y2.000 F600\nM3 S500\nG1 Z-1.500 F600\n');
      expect(_write((b) => strategy.writeContourEnd(b, 1.5)), 'G1 Z3.000 F600\n');
      expect(
          _write((b) => strategy.writeContourStart(b, const Offset(1, 2), 500, null)),
          'G0 X1.000 Y2.000\nM3 S500\n');
      expect(
          _write(strategy.writeFooterMoves),
          'G1 Z3.000 F600 ; retract to safe height\n'
          'G0 X0 Y0 ; XY HOME\n'
          'G1 Z0 F600 ; Z HOME\n');
    });
  });
}
