import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/models/speed_unit.dart';

void main() {
  test('conversion and formatting', () {
    expect(SpeedUnit.mmPerMin.fromMmS(50), 3000);
    expect(SpeedUnit.mmPerMin.toMmS(3000), 50);
    expect(SpeedUnit.mmPerSec.format(41.666), '41.7');
    expect(SpeedUnit.mmPerMin.format(740.4), '740');
  });

  group('SpeedTextController', () {
    test('unedited text returns the exact original value', () {
      final c = SpeedTextController(2500 / 60.0, SpeedUnit.mmPerSec);
      expect(c.text, '41.7');
      expect(c.mmS, 2500 / 60.0);
    });

    test('edited text is parsed in the display unit', () {
      final c = SpeedTextController(10, SpeedUnit.mmPerMin);
      c.text = '1200';
      expect(c.mmS, 20);
      c.text = '0';
      expect(c.mmS, isNull);
    });

    test('unit switch converts without losing the original', () {
      final c = SpeedTextController(12.34, SpeedUnit.mmPerSec);
      c.unit = SpeedUnit.mmPerMin;
      expect(c.text, '740');
      expect(c.mmS, 12.34);
      c.unit = SpeedUnit.mmPerSec;
      expect(c.text, '12.3');
    });

    test('nudge steps in the display unit and clamps', () {
      final c = SpeedTextController(50, SpeedUnit.mmPerMin);
      c.nudge(100, 0.1, 500);
      expect(c.text, '3100');
      c.nudge(100000, 0.1, 500);
      expect(c.text, '30000');
    });
  });
}
