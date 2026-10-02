import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/machines/laser/templates/focus_test.dart';
import 'package:easy_grbl/machines/laser/templates/kerf_test.dart';
import 'package:easy_grbl/machines/laser/laser_settings.dart';
import 'package:easy_grbl/machines/machine_mode.dart';
import 'package:easy_grbl/machines/machine_settings.dart';
import 'package:easy_grbl/machines/mill/mill_settings.dart';
import 'package:easy_grbl/machines/laser/templates/spot_test.dart';
import 'package:easy_grbl/machines/gcode/gcode_generator.dart';
import 'package:easy_grbl/machines/laser/templates/laser_gcode_templates.dart';

import 'support/sample_document.dart';

// Guards G-code output against unintended changes. Regenerate the golden files
// only for a deliberate output change:
//   flutter test test/gcode_regression_test.dart --dart-define=UPDATE_GOLDENS=true
const _updateGoldens = bool.fromEnvironment('UPDATE_GOLDENS');

void _expectGolden(String name, String actual) {
  final file = File('test/goldens/$name');
  if (_updateGoldens) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(actual);
    return;
  }
  expect(actual, file.readAsStringSync());
}

String _generate(MachineSettings s) =>
    GcodeGenerator.generate(sampleDocument(), 'sample.svg', s);

void main() {
  group('document G-code', () {
    test('laser M3', () {
      _expectGolden('laser.gcode', _generate(const MachineSettings()));
    });

    test('laser M4', () {
      _expectGolden(
          'laser_m4.gcode',
          _generate(const MachineSettings(
              laser: LaserSettings(
                  laserMode: LaserMode.variable, sMax: 255, laserSpotSize: 0.2))));
    });

    test('mill V-bit', () {
      _expectGolden(
          'mill.gcode',
          _generate(const MachineSettings(
              machineType: MachineType.mill, mill: MillSettings(bladeAngle: 60))));
    });

    test('mill flat bit, laser set to M4', () {
      _expectGolden(
          'mill_flat.gcode',
          _generate(const MachineSettings(
            machineType: MachineType.mill,
            laser: LaserSettings(laserMode: LaserMode.variable),
            mill: MillSettings(
              maxSpindleSpeed: 24000,
              toolDiameter: 6.0,
              bladeAngle: 180.0,
              safeHeight: 3.0,
              travelFeedRate: 40.0,
            ),
          )));
    });
  });

  group('laser templates', () {
    test('focus', () {
      _expectGolden('focus_test.gcode',
          LaserGcodeTemplates.focusTest(const FocusTestConfig(), const LaserSettings()));
    });

    test('focus M4', () {
      _expectGolden(
          'focus_test_m4.gcode',
          LaserGcodeTemplates.focusTest(
              const FocusTestConfig(),
              const LaserSettings(laserMode: LaserMode.variable, sMax: 255)));
    });

    test('kerf', () {
      _expectGolden('kerf_test.gcode',
          LaserGcodeTemplates.kerfTest(const KerfTestConfig(), const LaserSettings()));
    });

    test('spot', () {
      _expectGolden('spot_test.gcode',
          LaserGcodeTemplates.spotTest(const SpotTestConfig(), const LaserSettings()));
    });
  });
}
