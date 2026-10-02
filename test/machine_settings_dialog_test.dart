import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/machines/machine_settings.dart';
import 'package:easy_grbl/services/grbl_mock_service.dart';
import 'package:easy_grbl/widgets/machine_settings_dialog.dart';

import 'settings_regression_test.dart' show customSettingsMap;

Future<MachineSettings?> _openAndSave(
    WidgetTester tester, MachineSettings current) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final grbl = GrblMockService();
  addTearDown(grbl.dispose);
  // The test font (Ahem) is wider than real fonts, so the fixed-width dialog
  // overflows here; layout is not what this test checks.
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    defaultOnError?.call(details);
  };
  MachineSettings? result;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showMachineSettingsDialog(context, current, grbl);
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
  FlutterError.onError = defaultOnError;
  return result;
}

void main() {
  testWidgets('Save without edits keeps every value (mill)', (tester) async {
    final current = MachineSettings.fromMap(customSettingsMap);
    final result = await _openAndSave(tester, current);
    expect(find.text('MILL'), findsNothing); // dialog closed
    expect(result!.toMap(), customSettingsMap);
  });

  testWidgets('Save without edits keeps every value (laser)', (tester) async {
    final map = {...customSettingsMap, 'machineType': 'laser'};
    final result = await _openAndSave(tester, MachineSettings.fromMap(map));
    expect(result!.toMap(), map);
  });
}
