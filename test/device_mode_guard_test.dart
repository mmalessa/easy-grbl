import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/machines/machine_mode.dart';
import 'package:easy_grbl/services/grbl_mock_service.dart';

// `$$` / `$32=` sent mid-job would steal the streaming loop's acks, so the
// device-mode commands must refuse to run while a job is active.
void main() {
  testWidgets('device mode commands are refused while a job runs',
      (tester) async {
    final grbl = GrblMockService()..connect();
    addTearDown(grbl.dispose);
    await tester.pumpWidget(const SizedBox()); // connect completes after a frame
    expect(grbl.connected, isTrue);
    expect(await grbl.queryMachineType(), MachineType.laser);

    grbl.startLines(['G0 X1']);
    expect(grbl.isJobRunning, isTrue);

    expect(await grbl.setDeviceLaserMode(false), isFalse);
    expect(await grbl.queryMachineType(), isNull);

    await tester.pump(const Duration(milliseconds: 400)); // job finishes
    expect(grbl.isJobRunning, isFalse);
    expect(await grbl.queryMachineType(), MachineType.laser); // unchanged
  });
}
