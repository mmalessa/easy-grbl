import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/machines/common_settings.dart';
import 'package:easy_grbl/machines/laser/laser_settings.dart';
import 'package:easy_grbl/machines/machine_mode.dart';
import 'package:easy_grbl/machines/machine_settings.dart';
import 'package:easy_grbl/machines/mill/mill_settings.dart';

void main() {
  test('each part owns only its keys', () {
    expect(const LaserSettings().toMap().keys.toSet(), {
      'laserMode', 'sMax', 'laserSpotSize', 'engravePower', 'engraveSpeed',
      'cutPower', 'cutSpeed', 'fillPower', 'fillSpeed',
    });
    expect(const MillSettings().toMap().keys.toSet(), {
      'maxSpindleSpeed', 'maxFeedRate', 'toolDiameter', 'bladeAngle',
      'safeHeight', 'travelFeedRate', 'engraveSpindleSpeed', 'engraveFeedRate',
      'cutSpindleSpeed', 'cutFeedRate', 'fillSpindleSpeed', 'fillFeedRate',
    });
    expect(const CommonSettings().toMap().keys.toSet(), {'defaultBaudRate'});
  });

  test('copyWith replaces only the given part', () {
    const s = MachineSettings();
    final m = s.copyWith(
        machineType: MachineType.mill, mill: const MillSettings(safeHeight: 9));
    expect(m.machineType, MachineType.mill);
    expect(m.mill.safeHeight, 9);
    expect(m.laser.toMap(), s.laser.toMap());
    expect(m.common.toMap(), s.common.toMap());
  });

  group('MillSettings.effectiveDiameterAt', () {
    test('straight bit keeps nominal diameter', () {
      const m = MillSettings(toolDiameter: 6, bladeAngle: 180);
      expect(m.effectiveDiameterAt(5), 6);
    });

    test('90° V-bit is 2×depth wide, clamped to nominal', () {
      const m = MillSettings(toolDiameter: 6, bladeAngle: 90);
      expect(m.effectiveDiameterAt(1), closeTo(2, 1e-9));
      expect(m.effectiveDiameterAt(10), 6);
    });
  });

  test('laser mode labels and codes', () {
    expect(LaserMode.constant.gcode, 'M3');
    expect(LaserMode.variable.gcode, 'M4');
  });
}
