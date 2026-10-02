import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/machines/machine_mode.dart';
import 'package:easy_grbl/machines/laser/laser_settings.dart';
import 'package:easy_grbl/machines/machine_settings.dart';
import 'package:easy_grbl/machines/mill/mill_settings.dart';
import 'package:easy_grbl/models/operation_type.dart';
import 'package:easy_grbl/services/grbl_mock_service.dart';
import 'package:easy_grbl/widgets/main_app_bar.dart';
import 'package:easy_grbl/widgets/right_panel.dart';

Widget _appBar({
  required MachineType type,
  ValueChanged<MachineType>? onModeChanged,
}) =>
    MaterialApp(
      home: Scaffold(
        appBar: MainAppBar(
          onOpenFile: () {},
          recentFiles: const [],
          onOpenRecent: (_, _) {},
          onFocusTest: () {},
          onKerfTest: () {},
          onSpotTest: () {},
          isConnected: false,
          isSerialConnected: false,
          onToggleConnect: () {},
          machineType: type,
          onModeChanged: onModeChanged,
          onMachineSettings: () {},
          onAbout: () {},
        ),
      ),
    );

MenuItemButton _modeItem(WidgetTester tester, String label) =>
    tester.widget<MenuItemButton>(
        find.ancestor(of: find.text(label), matching: find.byType(MenuItemButton)));

void main() {
  group('MachineModeProfile', () {
    const s = MachineSettings(
      laser: LaserSettings(engraveSpeed: 3000, cutSpeed: 600, fillSpeed: 1200),
      mill: MillSettings(engraveFeedRate: 21, cutFeedRate: 31, fillFeedRate: 51),
    );

    test('laser profile', () {
      final p = MachineType.laser.profile;
      expect(p.displayName, 'Laser engraver');
      expect(p.supportsTemplates, isTrue);
      expect(p.showsCutDepth, isFalse);
      expect(p.defaultSpeedMmS(OperationType.engrave, s), 50);
      expect(p.defaultSpeedMmS(OperationType.cut, s), 10);
      expect(p.defaultSpeedMmS(OperationType.fill, s), 20);
    });

    test('mill profile', () {
      final p = MachineType.mill.profile;
      expect(p.displayName, 'CNC mill');
      expect(p.supportsTemplates, isFalse);
      expect(p.showsCutDepth, isTrue);
      expect(p.defaultSpeedMmS(OperationType.engrave, s), 21);
      expect(p.defaultSpeedMmS(OperationType.cut, s), 31);
      expect(p.defaultSpeedMmS(OperationType.fill, s), 51);
    });
  });

  group('MainAppBar', () {
    testWidgets('shows the mode badge', (tester) async {
      await tester.pumpWidget(_appBar(type: MachineType.mill));
      expect(find.text('CNC MILL'), findsOneWidget);
      await tester.pumpWidget(_appBar(type: MachineType.laser));
      expect(find.text('LASER ENGRAVER'), findsOneWidget);
    });

    testWidgets('Machine → Mode switches mode', (tester) async {
      MachineType? picked;
      await tester.pumpWidget(
          _appBar(type: MachineType.laser, onModeChanged: (m) => picked = m));
      await tester.tap(find.text('Machine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mode'));
      await tester.pumpAndSettle();
      expect(_modeItem(tester, 'Laser engraver').onPressed, isNotNull);
      await tester.tap(find.text('CNC mill'));
      await tester.pumpAndSettle();
      expect(picked, MachineType.mill);
    });

    testWidgets('Mode items are disabled without a callback', (tester) async {
      await tester.pumpWidget(_appBar(type: MachineType.laser));
      await tester.tap(find.text('Machine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mode'));
      await tester.pumpAndSettle();
      expect(_modeItem(tester, 'Laser engraver').onPressed, isNull);
      expect(_modeItem(tester, 'CNC mill').onPressed, isNull);
    });

    testWidgets('Templates only in laser mode', (tester) async {
      await tester.pumpWidget(_appBar(type: MachineType.laser));
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      expect(find.text('Templates'), findsOneWidget);

      await tester.pumpWidget(_appBar(type: MachineType.mill));
      await tester.pumpAndSettle();
      expect(find.text('Templates'), findsNothing);
    });
  });

  testWidgets('RightPanel header shows the mode', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final grbl = GrblMockService();
    addTearDown(grbl.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RightPanel(
            document: null, service: grbl, machineType: MachineType.mill),
      ),
    ));
    expect(find.text('Machine · CNC mill'), findsOneWidget);
  });
}
