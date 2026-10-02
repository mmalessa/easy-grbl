import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easy_grbl/machines/machine_settings.dart';
import 'package:easy_grbl/services/settings_service.dart';

const _constructorDefaults = <String, Object>{
  'machineType': 'laser',
  'laserMode': 'constant',
  'sMax': 1000,
  'laserSpotSize': 0.1,
  'maxSpindleSpeed': 1000,
  'maxFeedRate': 10.0,
  'toolDiameter': 2.0,
  'bladeAngle': 30.0,
  'engravePower': 60,
  'engraveSpeed': 3000,
  'cutPower': 100,
  'cutSpeed': 800,
  'fillPower': 80,
  'fillSpeed': 3000,
  'engraveSpindleSpeed': 12000,
  'engraveFeedRate': 20.0,
  'cutSpindleSpeed': 18000,
  'cutFeedRate': 30.0,
  'fillSpindleSpeed': 18000,
  'fillFeedRate': 50.0,
  'safeHeight': 5.0,
  'travelFeedRate': 25.0,
  'defaultBaudRate': 115200,
};

final _firstRunDefaults = <String, Object>{
  ..._constructorDefaults,
  'maxSpindleSpeed': 24000,
  'maxFeedRate': 3000.0,
  'toolDiameter': 3.175,
};

/// Every field differs from both default sets. Values are representable by
/// the Machine Settings dialog's text formatting (see dialog test).
const customSettingsMap = <String, Object>{
  'machineType': 'mill',
  'laserMode': 'variable',
  'sMax': 255,
  'laserSpotSize': 0.15,
  'maxSpindleSpeed': 12000,
  'maxFeedRate': 1500.5,
  'toolDiameter': 6.35,
  'bladeAngle': 90.0,
  'engravePower': 40,
  'engraveSpeed': 2500,
  'cutPower': 95,
  'cutSpeed': 600,
  'fillPower': 70,
  'fillSpeed': 4000,
  'engraveSpindleSpeed': 10000,
  'engraveFeedRate': 15.5,
  'cutSpindleSpeed': 16000,
  'cutFeedRate': 25.5,
  'fillSpindleSpeed': 17000,
  'fillFeedRate': 45.5,
  'safeHeight': 4.5,
  'travelFeedRate': 30.5,
  'defaultBaudRate': 250000,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('constructor defaults', () {
    expect(const MachineSettings().toMap(), _constructorDefaults);
  });

  test('first-run defaults (empty map)', () {
    expect(MachineSettings.fromMap(const {}).toMap(), _firstRunDefaults);
  });

  test('map round trip', () {
    expect(MachineSettings.fromMap(customSettingsMap).toMap(), customSettingsMap);
  });

  test('SettingsService stores machine_<field> keys', () async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.save(MachineSettings.fromMap(customSettingsMap));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(),
        customSettingsMap.keys.map((k) => 'machine_$k').toSet());
    expect((await SettingsService.load()).toMap(), customSettingsMap);
  });

  test('loads preferences saved by the previous version', () async {
    SharedPreferences.setMockInitialValues({
      for (final e in customSettingsMap.entries) 'machine_${e.key}': e.value,
    });
    expect((await SettingsService.load()).toMap(), customSettingsMap);
  });
}
